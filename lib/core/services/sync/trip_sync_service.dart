import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/expenses/models/expense.dart';
import '../../../features/trip_planning/models/trip.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/firebase_service.dart';
import '../storage_service.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

class TripSyncState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final Set<String> pendingChanges;
  final Set<String> tripsWithRemoteChanges;

  const TripSyncState({
    this.status = SyncStatus.idle,
    this.lastSyncTime,
    this.errorMessage,
    this.pendingChanges = const {},
    this.tripsWithRemoteChanges = const {},
  });

  TripSyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? errorMessage,
    Set<String>? pendingChanges,
    Set<String>? tripsWithRemoteChanges,
  }) {
    return TripSyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      tripsWithRemoteChanges: tripsWithRemoteChanges ?? this.tripsWithRemoteChanges,
    );
  }

  bool get hasRemoteChanges => tripsWithRemoteChanges.isNotEmpty;
}

class TripSyncService extends StateNotifier<TripSyncState> {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final Map<String, StreamSubscription> _tripSubscriptions = {};
  final Map<String, StreamSubscription> _expenseSubscriptions = {};
  final _tripUpdateController = StreamController<Trip>.broadcast();
  final _expenseUpdateController = StreamController<(String, List<Expense>)>.broadcast();

  /// Stream that emits updated trips when remote changes are applied
  Stream<Trip> get tripUpdates => _tripUpdateController.stream;

  /// Stream that emits (tripId, expenses) when remote expense changes are applied
  Stream<(String, List<Expense>)> get expenseUpdates => _expenseUpdateController.stream;

  TripSyncService({
    required FirestoreService firestoreService,
    required AuthService authService,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        super(const TripSyncState());

  /// Check if sync is available
  bool get isSyncAvailable =>
      FirebaseService.isAvailable && _authService.isSignedIn;

  /// Initialize sync - sign in anonymously if needed
  Future<void> initialize() async {
    if (!FirebaseService.isAvailable) {
      state = state.copyWith(status: SyncStatus.offline);
      return;
    }

    // Ensure user is signed in
    await _authService.ensureSignedIn();

    if (_authService.isSignedIn) {
      state = state.copyWith(status: SyncStatus.idle);
      // Start listening to shared trips
      _startListeningToSharedTrips();
    } else {
      state = state.copyWith(status: SyncStatus.offline);
    }
  }

  /// Sync a trip to cloud
  Future<bool> syncTrip(Trip trip) async {
    if (!isSyncAvailable) return false;

    final userId = _authService.currentUserId;
    if (userId == null) return false;

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      // Update owner if not set
      final tripToSync = trip.ownerId == null
          ? trip.copyWith(ownerId: userId, lastModifiedBy: userId)
          : trip.copyWith(lastModifiedBy: userId);

      // Save to Firestore
      final success = await _firestoreService.saveTrip(tripToSync, userId);

      if (success) {
        // Update local trip with sync time
        final syncedTrip = tripToSync.copyWith(lastSyncedAt: DateTime.now());
        await StorageService.saveTrip(syncedTrip);

        // Start listening for changes to this trip
        _subscribeToTrip(trip.id);

        state = state.copyWith(
          status: SyncStatus.synced,
          lastSyncTime: DateTime.now(),
          pendingChanges: Set.from(state.pendingChanges)..remove(trip.id),
        );
        debugPrint('Trip synced successfully: ${trip.id}');
        return true;
      }

      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Failed to save trip',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      debugPrint('Sync error: $e');
      return false;
    }
  }

  /// Mark trip as having local changes pending sync
  void markPendingChanges(String tripId) {
    state = state.copyWith(
      pendingChanges: Set.from(state.pendingChanges)..add(tripId),
    );
  }

  /// Sync a trip to cloud if it's shared (call after local edits)
  Future<void> syncIfShared(Trip trip) async {
    if (!isSyncAvailable) return;
    // Read fresh from storage — screen's trip object may be stale
    final currentTrip = StorageService.getTrip(trip.id) ?? trip;
    if (!currentTrip.isShared) return;
    await syncTrip(currentTrip);
  }

  /// Share a trip and get share code
  Future<String?> shareTrip(String tripId) async {
    if (!isSyncAvailable) return null;

    final trip = StorageService.getTrip(tripId);
    if (trip == null) return null;

    // Only sync if trip hasn't been synced recently or has pending changes
    final needsSync = trip.lastSyncedAt == null ||
        state.pendingChanges.contains(tripId);

    if (needsSync) {
      await syncTrip(trip);
    }

    // Generate share code
    final shareCode = await _firestoreService.generateShareCode(tripId);

    if (shareCode != null) {
      // Update local trip with share code - get fresh copy after sync
      final currentTrip = StorageService.getTrip(tripId) ?? trip;
      final updatedTrip = currentTrip.copyWith(
        shareCode: shareCode,
        isShared: true,
      );
      await StorageService.saveTrip(updatedTrip);
    }

    return shareCode;
  }

  /// Join a trip using share code
  Future<Trip?> joinTripByShareCode(String shareCode) async {
    if (!isSyncAvailable) return null;

    final userId = _authService.currentUserId;
    if (userId == null) return null;

    try {
      // Find trip by share code
      final trip = await _firestoreService.findTripByShareCode(shareCode);
      if (trip == null) {
        debugPrint('No trip found with share code: $shareCode');
        return null;
      }

      // Add current user as participant
      await _firestoreService.addParticipant(trip.id, userId);

      // Save trip locally
      final joinedTrip = trip.copyWith(
        participantIds: [...trip.participantIds, userId],
        lastSyncedAt: DateTime.now(),
      );
      await StorageService.saveTrip(joinedTrip);

      // Pull remote expenses for this trip
      await _pullRemoteExpenses(trip.id);
      _expenseInitialSyncDone.add(trip.id);

      // Subscribe to changes
      _subscribeToTrip(trip.id);

      debugPrint('Joined trip: ${trip.id}');
      return joinedTrip;
    } catch (e) {
      debugPrint('Failed to join trip: $e');
      return null;
    }
  }

  /// Add participants to a trip (with full contact info)
  Future<Trip?> addParticipants(String tripId, List<TripParticipant> newParticipants) async {
    if (!isSyncAvailable) return null;

    final trip = StorageService.getTrip(tripId);
    if (trip == null) return null;

    // Ensure trip is synced to Firestore first
    if (trip.lastSyncedAt == null) {
      await syncTrip(trip);
    }

    try {
      // Merge with existing participants (avoid duplicates by phone)
      final existingPhones = trip.participants
          .where((p) => p.phone != null)
          .map((p) => p.phone!)
          .toSet();

      final filteredNew = newParticipants
          .where((p) => p.phone == null || !existingPhones.contains(p.phone))
          .toList();

      if (filteredNew.isEmpty) return trip;

      final allParticipants = [...trip.participants, ...filteredNew];

      // Update Firestore
      final success = await _firestoreService.updateTripParticipants(
        tripId,
        allParticipants,
      );

      if (success) {
        final updatedTrip = trip.copyWith(
          participants: allParticipants,
          isShared: true,
          lastSyncedAt: DateTime.now(),
        );
        await StorageService.saveTrip(updatedTrip);

        // Push existing expenses to Firestore so participants can see them
        await _pushLocalExpensesToCloud(tripId);

        debugPrint('Added ${filteredNew.length} participants to trip: $tripId');
        return updatedTrip;
      }
    } catch (e) {
      debugPrint('Failed to add participants: $e');
    }
    return null;
  }

  // ============ EXPENSE SYNC ============

  /// Sync an expense to Firestore if its trip is shared
  Future<void> syncExpense(Expense expense) async {
    if (!isSyncAvailable) return;

    final trip = StorageService.getTrip(expense.tripId);
    if (trip == null || !trip.isShared) return;

    await _firestoreService.saveExpense(expense);
    _subscribeToTripExpenses(expense.tripId);
  }

  /// Delete an expense from Firestore if its trip is shared
  Future<void> deleteExpenseFromCloud(String expenseId, String tripId) async {
    if (!isSyncAvailable) return;

    final trip = StorageService.getTrip(tripId);
    if (trip == null || !trip.isShared) return;

    await _firestoreService.deleteExpenseFromCloud(expenseId);
  }

  // Track which trips have completed initial expense sync
  final Set<String> _expenseInitialSyncDone = {};

  void _subscribeToTripExpenses(String tripId) {
    // Don't re-subscribe if already listening
    if (_expenseSubscriptions.containsKey(tripId)) return;

    // Push local expenses to Firestore before subscribing
    // This ensures local-only expenses aren't deleted by the first remote snapshot
    _pushLocalExpensesToCloud(tripId);

    _expenseSubscriptions[tripId] = _firestoreService
        .tripExpensesStream(tripId)
        .listen(
      (remoteExpenses) {
        _handleRemoteExpenseChanges(tripId, remoteExpenses);
      },
      onError: (e) => debugPrint('Expense subscription error: $e'),
    );
  }

  /// Push all local expenses for a trip to Firestore (initial sync)
  Future<void> _pushLocalExpensesToCloud(String tripId) async {
    if (_expenseInitialSyncDone.contains(tripId)) return;
    _expenseInitialSyncDone.add(tripId);

    final localExpenses = StorageService.getTripExpenses(tripId);
    for (final expense in localExpenses) {
      await _firestoreService.saveExpense(expense);
    }
    if (localExpenses.isNotEmpty) {
      debugPrint('Pushed ${localExpenses.length} local expenses to Firestore for trip: $tripId');
    }
  }

  /// Pull all remote expenses for a trip to local storage
  Future<void> _pullRemoteExpenses(String tripId) async {
    final remoteExpenses = await _firestoreService.getTripExpenses(tripId);
    for (final expense in remoteExpenses) {
      await StorageService.saveExpense(expense);
    }
    if (remoteExpenses.isNotEmpty) {
      debugPrint('Pulled ${remoteExpenses.length} remote expenses for trip: $tripId');
    }
  }

  void _handleRemoteExpenseChanges(String tripId, List<Expense> remoteExpenses) async {
    // Get local expenses for comparison
    final localExpenses = StorageService.getTripExpenses(tripId);
    final localIds = localExpenses.map((e) => e.id).toSet();
    final remoteIds = remoteExpenses.map((e) => e.id).toSet();

    bool changed = false;

    // Add/update remote expenses locally
    for (final remote in remoteExpenses) {
      final local = localExpenses.where((e) => e.id == remote.id).firstOrNull;
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await StorageService.saveExpense(remote);
        changed = true;
      }
    }

    // Remove local expenses that were deleted remotely
    // Only safe after initial sync has pushed local expenses to cloud
    if (_expenseInitialSyncDone.contains(tripId)) {
      for (final localId in localIds) {
        if (!remoteIds.contains(localId)) {
          await StorageService.deleteExpense(localId);
          changed = true;
        }
      }
    }

    if (changed) {
      // Re-read the updated list and notify screens with tripId
      final updatedExpenses = StorageService.getTripExpenses(tripId);
      _expenseUpdateController.add((tripId, updatedExpenses));
      debugPrint('Remote expense changes applied for trip: $tripId');
    }
  }

  /// Refresh trip from cloud
  Future<Trip?> refreshTrip(String tripId) async {
    if (!isSyncAvailable) return null;

    try {
      final remoteTrip = await _firestoreService.getTrip(tripId);
      if (remoteTrip != null) {
        // Update local copy
        final syncedTrip = remoteTrip.copyWith(lastSyncedAt: DateTime.now());
        await StorageService.saveTrip(syncedTrip);

        // Clear remote changes flag for this trip
        state = state.copyWith(
          tripsWithRemoteChanges: Set.from(state.tripsWithRemoteChanges)
            ..remove(tripId),
        );

        return syncedTrip;
      }
    } catch (e) {
      debugPrint('Failed to refresh trip: $e');
    }
    return null;
  }

  /// Clear remote changes notification for a trip
  void clearRemoteChanges(String tripId) {
    state = state.copyWith(
      tripsWithRemoteChanges: Set.from(state.tripsWithRemoteChanges)
        ..remove(tripId),
    );
  }

  void _startListeningToSharedTrips() {
    // Get all local trips and subscribe to shared ones
    final localTrips = StorageService.getAllTrips();
    for (var trip in localTrips) {
      if (trip.isShared) {
        _subscribeToTrip(trip.id);
      }
    }
  }

  void _subscribeToTrip(String tripId) {
    // Cancel existing subscription
    _tripSubscriptions[tripId]?.cancel();

    // Start new subscription
    _tripSubscriptions[tripId] = _firestoreService.tripStream(tripId).listen(
      (remoteTrip) {
        if (remoteTrip != null) {
          _handleRemoteTripChange(tripId, remoteTrip);
        }
      },
      onError: (e) => debugPrint('Trip subscription error: $e'),
    );

    // Also subscribe to expenses for this trip
    _subscribeToTripExpenses(tripId);
  }

  void _handleRemoteTripChange(String tripId, Trip remoteTrip) async {
    final localTrip = StorageService.getTrip(tripId);
    if (localTrip == null) return;

    // Check if remote is newer
    final remoteUpdated = remoteTrip.updatedAt;
    final localUpdated = localTrip.lastSyncedAt ?? localTrip.updatedAt;

    if (remoteUpdated.isAfter(localUpdated)) {
      // Only auto-apply changes from other participants
      if (remoteTrip.lastModifiedBy != _authService.currentUserId) {
        // Auto-apply: save remote trip to local storage
        final syncedTrip = remoteTrip.copyWith(lastSyncedAt: DateTime.now());
        await StorageService.saveTrip(syncedTrip);

        // Notify listening screens
        _tripUpdateController.add(syncedTrip);

        debugPrint('Remote changes auto-applied for trip: $tripId');
      }
    }
  }

  /// Sync all pending local changes
  Future<void> syncAllPending() async {
    if (!isSyncAvailable || state.pendingChanges.isEmpty) return;

    for (var tripId in state.pendingChanges.toList()) {
      final trip = StorageService.getTrip(tripId);
      if (trip != null) {
        await syncTrip(trip);
      }
    }
  }

  /// Clean up subscriptions
  @override
  void dispose() {
    for (var subscription in _tripSubscriptions.values) {
      subscription.cancel();
    }
    _tripSubscriptions.clear();
    for (var subscription in _expenseSubscriptions.values) {
      subscription.cancel();
    }
    _expenseSubscriptions.clear();
    _tripUpdateController.close();
    _expenseUpdateController.close();
    super.dispose();
  }
}

// Providers
final tripSyncServiceProvider =
    StateNotifierProvider<TripSyncService, TripSyncState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final authService = ref.watch(authServiceProvider);

  final service = TripSyncService(
    firestoreService: firestoreService,
    authService: authService,
  );

  // Initialize sync on creation
  service.initialize();

  return service;
});

// Convenience provider for checking if specific trip has remote changes
final tripHasRemoteChangesProvider =
    Provider.family<bool, String>((ref, tripId) {
  final syncState = ref.watch(tripSyncServiceProvider);
  return syncState.tripsWithRemoteChanges.contains(tripId);
});

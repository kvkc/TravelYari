import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Share a trip and get share code
  Future<String?> shareTrip(String tripId) async {
    if (!isSyncAvailable) return null;

    // First sync the trip
    final trip = StorageService.getTrip(tripId);
    if (trip == null) return null;

    await syncTrip(trip);

    // Generate share code
    final shareCode = await _firestoreService.generateShareCode(tripId);

    if (shareCode != null) {
      // Update local trip with share code
      final updatedTrip = trip.copyWith(
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

      // Subscribe to changes
      _subscribeToTrip(trip.id);

      debugPrint('Joined trip: ${trip.id}');
      return joinedTrip;
    } catch (e) {
      debugPrint('Failed to join trip: $e');
      return null;
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
  }

  void _handleRemoteTripChange(String tripId, Trip remoteTrip) {
    final localTrip = StorageService.getTrip(tripId);
    if (localTrip == null) return;

    // Check if remote is newer
    final remoteUpdated = remoteTrip.updatedAt;
    final localUpdated = localTrip.lastSyncedAt ?? localTrip.updatedAt;

    if (remoteUpdated.isAfter(localUpdated)) {
      // Remote has changes - notify user
      if (remoteTrip.lastModifiedBy != _authService.currentUserId) {
        state = state.copyWith(
          tripsWithRemoteChanges: Set.from(state.tripsWithRemoteChanges)
            ..add(tripId),
        );
        debugPrint('Remote changes detected for trip: $tripId');
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

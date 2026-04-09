import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/expenses/models/expense.dart';
import '../../../features/trip_planning/models/trip.dart';
import 'firebase_service.dart';

class FirestoreService {
  final FirebaseFirestore? _firestore;

  FirestoreService()
      : _firestore = FirebaseService.isAvailable ? FirebaseFirestore.instance : null;

  /// Check if Firestore is available
  bool get isAvailable => _firestore != null;

  // Collection references
  CollectionReference<Map<String, dynamic>>? get _tripsCollection =>
      _firestore?.collection('trips');

  CollectionReference<Map<String, dynamic>>? get _usersCollection =>
      _firestore?.collection('users');

  // ============ TRIP OPERATIONS ============

  /// Save/update a trip to Firestore
  /// Protects participants from being overwritten by empty arrays
  Future<bool> saveTrip(Trip trip, String userId) async {
    if (_tripsCollection == null) return false;

    try {
      final tripData = trip.toJson();
      tripData['ownerId'] = userId;
      tripData['lastModifiedBy'] = userId;
      tripData['lastModifiedAt'] = FieldValue.serverTimestamp();

      // Don't overwrite remote participants/participantIds with empty arrays
      // merge:true preserves fields not present in the data
      if ((tripData['participants'] as List).isEmpty) {
        tripData.remove('participants');
      }
      if ((tripData['participantIds'] as List).isEmpty) {
        tripData.remove('participantIds');
      }

      await _tripsCollection!.doc(trip.id).set(tripData, SetOptions(merge: true));
      debugPrint('Trip saved to Firestore: ${trip.id}');
      return true;
    } catch (e) {
      debugPrint('Failed to save trip: $e');
      return false;
    }
  }

  /// Get a trip by ID
  Future<Trip?> getTrip(String tripId) async {
    if (_tripsCollection == null) return null;

    try {
      final doc = await _tripsCollection!.doc(tripId).get();
      if (doc.exists && doc.data() != null) {
        return Trip.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('Failed to get trip: $e');
    }
    return null;
  }

  /// Get all trips for a user
  Future<List<Trip>> getUserTrips(String userId) async {
    if (_tripsCollection == null) return [];

    try {
      // Get trips where user is owner
      final ownedQuery = await _tripsCollection!
          .where('ownerId', isEqualTo: userId)
          .get();

      // Get trips where user is a participant
      final participantQuery = await _tripsCollection!
          .where('participantIds', arrayContains: userId)
          .get();

      final tripIds = <String>{};
      final trips = <Trip>[];

      for (var doc in [...ownedQuery.docs, ...participantQuery.docs]) {
        if (!tripIds.contains(doc.id) && doc.data() != null) {
          tripIds.add(doc.id);
          trips.add(Trip.fromJson(doc.data()));
        }
      }

      return trips;
    } catch (e) {
      debugPrint('Failed to get user trips: $e');
      return [];
    }
  }

  /// Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    if (_tripsCollection == null) return false;

    try {
      await _tripsCollection!.doc(tripId).delete();
      debugPrint('Trip deleted from Firestore: $tripId');
      return true;
    } catch (e) {
      debugPrint('Failed to delete trip: $e');
      return false;
    }
  }

  /// Listen to trip changes
  Stream<Trip?> tripStream(String tripId) {
    if (_tripsCollection == null) return Stream.value(null);

    return _tripsCollection!
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? Trip.fromJson(doc.data()!)
            : null);
  }

  /// Listen to changes in trips for a user
  Stream<List<Trip>> userTripsStream(String userId) {
    if (_tripsCollection == null) return Stream.value([]);

    return _tripsCollection!
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data() != null)
            .map((doc) => Trip.fromJson(doc.data()))
            .toList());
  }

  // ============ SHARING OPERATIONS ============

  /// Generate a unique share code for a trip
  Future<String?> generateShareCode(String tripId) async {
    if (_tripsCollection == null) return null;

    try {
      // Generate a 6-character alphanumeric code
      final code = _generateCode(6);

      await _tripsCollection!.doc(tripId).update({
        'shareCode': code,
        'isShared': true,
      });

      debugPrint('Share code generated: $code');
      return code;
    } catch (e) {
      debugPrint('Failed to generate share code: $e');
      return null;
    }
  }

  /// Find trip by share code
  Future<Trip?> findTripByShareCode(String shareCode) async {
    if (_tripsCollection == null) return null;

    try {
      final query = await _tripsCollection!
          .where('shareCode', isEqualTo: shareCode.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && query.docs.first.data() != null) {
        return Trip.fromJson(query.docs.first.data());
      }
    } catch (e) {
      debugPrint('Failed to find trip by share code: $e');
    }
    return null;
  }

  /// Add a participant to a trip
  Future<bool> addParticipant(String tripId, String participantUserId) async {
    if (_tripsCollection == null) return false;

    try {
      await _tripsCollection!.doc(tripId).update({
        'participantIds': FieldValue.arrayUnion([participantUserId]),
      });
      debugPrint('Participant added: $participantUserId to $tripId');
      return true;
    } catch (e) {
      debugPrint('Failed to add participant: $e');
      return false;
    }
  }

  /// Remove a participant from a trip
  Future<bool> removeParticipant(String tripId, String participantUserId) async {
    if (_tripsCollection == null) return false;

    try {
      await _tripsCollection!.doc(tripId).update({
        'participantIds': FieldValue.arrayRemove([participantUserId]),
      });
      debugPrint('Participant removed: $participantUserId from $tripId');
      return true;
    } catch (e) {
      debugPrint('Failed to remove participant: $e');
      return false;
    }
  }

  // ============ USER OPERATIONS ============

  /// Save/update user profile
  Future<bool> saveUserProfile({
    required String userId,
    String? displayName,
    String? phoneNumber,
  }) async {
    if (_usersCollection == null) return false;

    try {
      await _usersCollection!.doc(userId).set({
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Failed to save user profile: $e');
      return false;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (_usersCollection == null) return null;

    try {
      final doc = await _usersCollection!.doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Failed to get user profile: $e');
      return null;
    }
  }

  // ============ EXPENSE OPERATIONS ============

  CollectionReference<Map<String, dynamic>>? get _expensesCollection =>
      _firestore?.collection('expenses');

  /// Save/update an expense to Firestore
  Future<bool> saveExpense(Expense expense) async {
    if (_expensesCollection == null) return false;

    try {
      await _expensesCollection!.doc(expense.id).set(
        expense.toJson(),
        SetOptions(merge: true),
      );
      debugPrint('Expense saved to Firestore: ${expense.id}');
      return true;
    } catch (e) {
      debugPrint('Failed to save expense: $e');
      return false;
    }
  }

  /// Delete an expense from Firestore
  Future<bool> deleteExpenseFromCloud(String expenseId) async {
    if (_expensesCollection == null) return false;

    try {
      await _expensesCollection!.doc(expenseId).delete();
      debugPrint('Expense deleted from Firestore: $expenseId');
      return true;
    } catch (e) {
      debugPrint('Failed to delete expense: $e');
      return false;
    }
  }

  /// Get all expenses for a trip
  Future<List<Expense>> getTripExpenses(String tripId) async {
    if (_expensesCollection == null) return [];

    try {
      final query = await _expensesCollection!
          .where('tripId', isEqualTo: tripId)
          .get();

      return query.docs
          .where((doc) => doc.data() != null)
          .map((doc) => Expense.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Failed to get trip expenses: $e');
      return [];
    }
  }

  /// Listen to expense changes for a trip
  Stream<List<Expense>> tripExpensesStream(String tripId) {
    if (_expensesCollection == null) return Stream.value([]);

    return _expensesCollection!
        .where('tripId', isEqualTo: tripId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data() != null)
            .map((doc) => Expense.fromJson(doc.data()))
            .toList());
  }

  // ============ HELPERS ============

  String _generateCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (index) {
      final charIndex = (random ~/ (index + 1)) % chars.length;
      return chars[charIndex];
    }).join();
  }
}

// Provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

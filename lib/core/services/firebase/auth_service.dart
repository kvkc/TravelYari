import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth? _auth;

  AuthService() : _auth = FirebaseService.isAvailable ? FirebaseAuth.instance : null;

  /// Get current user ID (null if not authenticated or Firebase unavailable)
  String? get currentUserId => _auth?.currentUser?.uid;

  /// Get current user
  User? get currentUser => _auth?.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Check if Firebase auth is available
  bool get isAvailable => _auth != null;

  /// Sign in anonymously
  /// Returns user ID on success, null on failure
  Future<String?> signInAnonymously() async {
    if (_auth == null) return null;

    try {
      final result = await _auth.signInAnonymously();
      debugPrint('Signed in anonymously: ${result.user?.uid}');
      return result.user?.uid;
    } catch (e) {
      debugPrint('Anonymous sign in failed: $e');
      return null;
    }
  }

  /// Ensure user is signed in (sign in anonymously if not)
  Future<String?> ensureSignedIn() async {
    if (_auth == null) return null;

    if (isSignedIn) {
      return currentUserId;
    }

    return signInAnonymously();
  }

  /// Link anonymous account with phone number
  Future<bool> linkWithPhoneNumber(String verificationId, String smsCode) async {
    if (_auth == null || currentUser == null) return false;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await currentUser!.linkWithCredential(credential);
      debugPrint('Phone number linked successfully');
      return true;
    } catch (e) {
      debugPrint('Phone linking failed: $e');
      return false;
    }
  }

  /// Start phone verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    if (_auth == null) {
      onError('Firebase not available');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) => onAutoVerified(credential),
        verificationFailed: (e) => onError(e.message ?? 'Verification failed'),
        codeSent: (verificationId, resendToken) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError('Failed to verify phone: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_auth == null) return;

    try {
      await _auth.signOut();
      debugPrint('Signed out successfully');
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  /// Stream of auth state changes
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream.value(null);

  /// Update user display name
  Future<bool> updateDisplayName(String name) async {
    if (_auth == null || currentUser == null) return false;

    try {
      await currentUser!.updateDisplayName(name);
      return true;
    } catch (e) {
      debugPrint('Update display name failed: $e');
      return false;
    }
  }
}

// Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUserId;
});

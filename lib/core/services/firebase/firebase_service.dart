import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Initialize Firebase
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      // Don't throw - allow app to work offline without Firebase
    }
  }

  /// Check if Firebase is available
  static bool get isAvailable => _initialized;
}

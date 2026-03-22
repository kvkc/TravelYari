import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Securely stores user-provided API keys
/// The app works without any keys using free OpenStreetMap
class ApiKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Key names
  static const _googleMapsKey = 'user_google_maps_api_key';

  // Google Maps (optional - app works without it)
  static Future<String?> getGoogleMapsKey() => _storage.read(key: _googleMapsKey);
  static Future<void> setGoogleMapsKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _googleMapsKey);
    } else {
      await _storage.write(key: _googleMapsKey, value: key);
    }
  }

  // Get all keys status (without revealing actual values)
  static Future<Map<String, bool>> getKeysStatus() async {
    return {
      'googleMaps': (await getGoogleMapsKey())?.isNotEmpty ?? false,
    };
  }

  // Clear all keys
  static Future<void> clearAllKeys() async {
    await _storage.deleteAll();
  }
}

/// Provider for API key status
final apiKeyStatusProvider = FutureProvider<Map<String, bool>>((ref) {
  return ApiKeyStorage.getKeysStatus();
});

/// Google Maps key provider
final googleMapsKeyProvider = FutureProvider<String?>((ref) {
  return ApiKeyStorage.getGoogleMapsKey();
});

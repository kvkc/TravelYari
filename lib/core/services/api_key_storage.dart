import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Securely stores user-provided API keys
class ApiKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Key names
  static const _googleMapsKey = 'user_google_maps_api_key';
  static const _mapplsKey = 'user_mappls_api_key';
  static const _mapplsClientId = 'user_mappls_client_id';
  static const _mapplsClientSecret = 'user_mappls_client_secret';
  static const _openRouteServiceKey = 'user_openrouteservice_api_key';
  static const _foursquareKey = 'user_foursquare_api_key';

  // Google Maps
  static Future<String?> getGoogleMapsKey() => _storage.read(key: _googleMapsKey);
  static Future<void> setGoogleMapsKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _googleMapsKey);
    } else {
      await _storage.write(key: _googleMapsKey, value: key);
    }
  }

  // Mappls
  static Future<String?> getMapplsKey() => _storage.read(key: _mapplsKey);
  static Future<void> setMapplsKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _mapplsKey);
    } else {
      await _storage.write(key: _mapplsKey, value: key);
    }
  }

  static Future<String?> getMapplsClientId() => _storage.read(key: _mapplsClientId);
  static Future<void> setMapplsClientId(String? id) async {
    if (id == null || id.isEmpty) {
      await _storage.delete(key: _mapplsClientId);
    } else {
      await _storage.write(key: _mapplsClientId, value: id);
    }
  }

  static Future<String?> getMapplsClientSecret() => _storage.read(key: _mapplsClientSecret);
  static Future<void> setMapplsClientSecret(String? secret) async {
    if (secret == null || secret.isEmpty) {
      await _storage.delete(key: _mapplsClientSecret);
    } else {
      await _storage.write(key: _mapplsClientSecret, value: secret);
    }
  }

  // OpenRouteService (optional, for higher rate limits)
  static Future<String?> getOpenRouteServiceKey() => _storage.read(key: _openRouteServiceKey);
  static Future<void> setOpenRouteServiceKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _openRouteServiceKey);
    } else {
      await _storage.write(key: _openRouteServiceKey, value: key);
    }
  }

  // Foursquare (for restaurant data)
  static Future<String?> getFoursquareKey() => _storage.read(key: _foursquareKey);
  static Future<void> setFoursquareKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _storage.delete(key: _foursquareKey);
    } else {
      await _storage.write(key: _foursquareKey, value: key);
    }
  }

  // Get all keys status (without revealing actual values)
  static Future<Map<String, bool>> getKeysStatus() async {
    return {
      'googleMaps': (await getGoogleMapsKey())?.isNotEmpty ?? false,
      'mappls': (await getMapplsKey())?.isNotEmpty ?? false,
      'mapplsClientId': (await getMapplsClientId())?.isNotEmpty ?? false,
      'mapplsClientSecret': (await getMapplsClientSecret())?.isNotEmpty ?? false,
      'openRouteService': (await getOpenRouteServiceKey())?.isNotEmpty ?? false,
      'foursquare': (await getFoursquareKey())?.isNotEmpty ?? false,
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

/// Individual key providers
final googleMapsKeyProvider = FutureProvider<String?>((ref) {
  return ApiKeyStorage.getGoogleMapsKey();
});

final mapplsKeyProvider = FutureProvider<String?>((ref) {
  return ApiKeyStorage.getMapplsKey();
});

final openRouteServiceKeyProvider = FutureProvider<String?>((ref) {
  return ApiKeyStorage.getOpenRouteServiceKey();
});

final foursquareKeyProvider = FutureProvider<String?>((ref) {
  return ApiKeyStorage.getFoursquareKey();
});

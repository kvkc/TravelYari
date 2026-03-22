import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/map/unified_map_service.dart';
import '../trip_planning/models/location.dart';

/// Parses locations from various URL formats and text
class LocationParser {
  // Regex patterns for various location formats
  static final RegExp _googleMapsUrlPattern = RegExp(
    r'https?://(?:www\.)?google\.[a-z]+/maps[^\s]*',
    caseSensitive: false,
  );

  static final RegExp _googleMapsPlacePattern = RegExp(
    r'place/([^/@]+)',
  );

  static final RegExp _googleMapsCoordPattern = RegExp(
    r'@(-?\d+\.?\d*),(-?\d+\.?\d*)',
  );

  static final RegExp _googleMapsSearchPattern = RegExp(
    r'search/([^/@]+)',
  );

  static final RegExp _mapsShortLinkPattern = RegExp(
    r'https?://(?:goo\.gl|maps\.app\.goo\.gl)/[a-zA-Z0-9]+',
    caseSensitive: false,
  );

  static final RegExp _whatThreeWordsPattern = RegExp(
    r'///([a-z]+\.[a-z]+\.[a-z]+)',
    caseSensitive: false,
  );

  static final RegExp _coordinatePattern = RegExp(
    r'(-?\d{1,3}\.?\d*)[,\s]+(-?\d{1,3}\.?\d*)',
  );

  static final RegExp _whatsappLocationPattern = RegExp(
    r'Location:\s*https?://[^\s]+|📍[^\n]+',
    caseSensitive: false,
  );

  /// Parse shared text that might contain a location
  static Future<TripLocation?> parseSharedText(String text, WidgetRef ref) async {
    // Check for Google Maps URL
    final googleMatch = _googleMapsUrlPattern.firstMatch(text);
    if (googleMatch != null) {
      return parseUrl(googleMatch.group(0)!, ref);
    }

    // Check for short link
    final shortMatch = _mapsShortLinkPattern.firstMatch(text);
    if (shortMatch != null) {
      return parseUrl(shortMatch.group(0)!, ref);
    }

    // Check for WhatsApp location format
    final whatsappMatch = _whatsappLocationPattern.firstMatch(text);
    if (whatsappMatch != null) {
      final locationText = whatsappMatch.group(0)!;
      // Extract URL from WhatsApp location
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(locationText);
      if (urlMatch != null) {
        return parseUrl(urlMatch.group(0)!, ref);
      }
    }

    // Check for raw coordinates
    final coordMatch = _coordinatePattern.firstMatch(text);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        return _reverseGeocode(lat, lng, ref);
      }
    }

    // Check for what3words
    final w3wMatch = _whatThreeWordsPattern.firstMatch(text);
    if (w3wMatch != null) {
      // what3words integration would go here
      // For now, we don't support it directly
    }

    // Try searching for the text as a place name
    final mapService = ref.read(unifiedMapServiceProvider);
    final results = await mapService.searchPlaces(text);
    if (results.isNotEmpty) {
      return results.first;
    }

    return null;
  }

  /// Parse a URL and extract location information
  static Future<TripLocation?> parseUrl(String url, WidgetRef ref) async {
    final mapService = ref.read(unifiedMapServiceProvider);

    // Google Maps URL
    if (url.contains('google.') || url.contains('goo.gl') || url.contains('maps.app')) {
      return _parseGoogleMapsUrl(url, mapService);
    }

    return null;
  }

  static Future<TripLocation?> _parseGoogleMapsUrl(
    String url,
    UnifiedMapService mapService,
  ) async {
    // Try to extract coordinates directly
    final coordMatch = _googleMapsCoordPattern.firstMatch(url);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null) {
        final location = await mapService.reverseGeocode(lat, lng);
        if (location != null) return location;
      }
    }

    // Try to extract place name
    final placeMatch = _googleMapsPlacePattern.firstMatch(url);
    if (placeMatch != null) {
      final placeName = Uri.decodeComponent(placeMatch.group(1)!);
      final results = await mapService.searchPlaces(placeName);
      if (results.isNotEmpty) return results.first;
    }

    // Try search query
    final searchMatch = _googleMapsSearchPattern.firstMatch(url);
    if (searchMatch != null) {
      final query = Uri.decodeComponent(searchMatch.group(1)!);
      final results = await mapService.searchPlaces(query);
      if (results.isNotEmpty) return results.first;
    }

    // Extract place_id if present
    final placeIdMatch = RegExp(r'place_id[=:]([^&/]+)').firstMatch(url);
    if (placeIdMatch != null) {
      final placeId = placeIdMatch.group(1)!;
      return mapService.getPlaceDetails(placeId, LocationSource.googleMaps);
    }

    // Try extracting any coordinates from the URL
    final allCoords = RegExp(r'(-?\d+\.\d+),(-?\d+\.\d+)').allMatches(url);
    for (var match in allCoords) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
        return mapService.reverseGeocode(lat, lng);
      }
    }

    return null;
  }

  static Future<TripLocation?> _reverseGeocode(
    double lat,
    double lng,
    WidgetRef ref,
  ) async {
    final mapService = ref.read(unifiedMapServiceProvider);
    return mapService.reverseGeocode(lat, lng);
  }

  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Extract location name from a URL
  static String? extractPlaceName(String url) {
    final placeMatch = _googleMapsPlacePattern.firstMatch(url);
    if (placeMatch != null) {
      return Uri.decodeComponent(placeMatch.group(1)!).replaceAll('+', ' ');
    }

    final searchMatch = _googleMapsSearchPattern.firstMatch(url);
    if (searchMatch != null) {
      return Uri.decodeComponent(searchMatch.group(1)!).replaceAll('+', ' ');
    }

    return null;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../api_keys.dart';
import 'map_service_interface.dart';
import 'google_maps_service.dart';
import 'osm_service.dart';

enum MapProvider {
  google,
  openStreetMap, // Free fallback, no API key needed
}

/// Unified map service using HYBRID approach for cost optimization:
/// - Map display: Google Maps (if key) or OSM (free fallback)
/// - Place search: Google Places (if key) or Photon/Nominatim (free fallback)
/// - Routing/Directions: Always OSRM (FREE - saves the most money!)
/// - Distance Matrix: Always OSRM (FREE)
/// - Reverse Geocoding: Always OSM Nominatim/Photon (FREE)
class UnifiedMapService {
  /// Timeout for individual service calls
  static const Duration _serviceTimeout = Duration(seconds: 5);

  /// Helper to wrap service calls with timeout
  Future<T?> _withTimeout<T>(Future<T?> Function() fn) async {
    try {
      return await fn().timeout(_serviceTimeout, onTimeout: () => null);
    } catch (e) {
      return null;
    }
  }

  final GoogleMapsService _googleService;
  final OsmService _osmService;

  MapProvider _primaryProvider;

  /// Check if an API key is actually configured (not placeholder)
  static bool _isKeyConfigured(String key) {
    return key.isNotEmpty &&
           !key.startsWith('YOUR_') &&
           key != 'YOUR_GOOGLE_MAPS_API_KEY';
  }

  /// Check if Google Maps has valid API key
  static bool get hasGoogleKey => _isKeyConfigured(ApiKeys.googleMaps);

  UnifiedMapService({
    required GoogleMapsService googleService,
    required OsmService osmService,
    MapProvider primaryProvider = MapProvider.openStreetMap,
  })  : _googleService = googleService,
        _osmService = osmService,
        _primaryProvider = primaryProvider;

  MapProvider get primaryProvider => _primaryProvider;

  void setPrimaryProvider(MapProvider provider) {
    _primaryProvider = provider;
  }

  /// Get list of services that have valid API keys configured
  /// OSM is always first (free, always works)
  List<MapServiceInterface> get _availableServices {
    final services = <MapServiceInterface>[_osmService];
    if (hasGoogleKey) services.add(_googleService);
    return services;
  }

  /// Search places - HYBRID: Google Places if key (better UX), else OSM (free)
  Future<List<TripLocation>> searchPlaces(
    String query, {
    LatLng? nearLocation,
    MapProvider? provider,
  }) async {
    // Prefer Google for search if key available (better results, autocomplete)
    final services = provider != null
        ? [_getService(provider)]
        : hasGoogleKey
            ? [_googleService, _osmService]  // Google first if available
            : [_osmService];                  // OSM only if no key

    for (var service in services) {
      try {
        final results = await service.searchPlaces(query, nearLocation: nearLocation)
            .timeout(_serviceTimeout, onTimeout: () => <TripLocation>[]);
        if (results.isNotEmpty) return results;
      } catch (e) {
        print('${service.providerName} search failed: $e');
        continue;
      }
    }

    return [];
  }

  /// Search places across all available providers and merge results
  Future<List<TripLocation>> searchPlacesAllProviders(
    String query, {
    LatLng? nearLocation,
  }) async {
    final futures = _availableServices.map((service) =>
      service.searchPlaces(query, nearLocation: nearLocation)
          .timeout(_serviceTimeout, onTimeout: () => <TripLocation>[])
    );

    final results = await Future.wait(futures);

    // Merge and deduplicate results
    final allResults = <TripLocation>[];
    final seen = <String>{};

    for (var providerResults in results) {
      for (var location in providerResults) {
        final key = '${(location.latitude * 1000).round()}_${(location.longitude * 1000).round()}';
        if (!seen.contains(key)) {
          seen.add(key);
          allResults.add(location);
        }
      }
    }

    return allResults;
  }

  Future<TripLocation?> getPlaceDetails(String placeId, LocationSource source) async {
    final service = _getServiceBySource(source);
    return service.getPlaceDetails(placeId);
  }

  /// Reverse geocode - ALWAYS use OSM (FREE, no cost)
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    // Always use OSM for reverse geocoding - it's free!
    try {
      final result = await _osmService.reverseGeocode(latitude, longitude)
          .timeout(_serviceTimeout, onTimeout: () => null);
      if (result != null) return result;
    } catch (e) {
      print('OSM reverse geocode failed: $e');
    }
    return null;
  }

  /// Get directions - ALWAYS use OSRM (FREE - biggest cost saver!)
  /// Google Directions API costs $5/1000 requests - OSRM is free
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
    MapProvider? provider,  // Ignored - always uses OSRM for cost savings
  }) async {
    // Always use OSRM for directions - saves $5 per 1000 requests!
    try {
      final result = await _osmService.getDirections(
        origin,
        destination,
        waypoints: waypoints,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (result != null) return result;
    } catch (e) {
      print('OSRM directions failed: $e');
    }

    return null;
  }

  /// Get distance matrix - ALWAYS use OSRM (FREE - huge cost saver!)
  /// Google Distance Matrix costs $5/1000 elements - a 10-stop trip = 100 elements!
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations, {
    MapProvider? provider,  // Ignored - always uses OSRM for cost savings
  }) async {
    // Always use OSRM for distance matrix - saves $5 per 1000 elements!
    // A trip with 10 stops = 100 elements = $0.50 per trip on Google!
    try {
      final result = await _osmService.getDistanceMatrix(origins, destinations)
          .timeout(const Duration(seconds: 10), onTimeout: () => <List<double>>[]);
      if (result.isNotEmpty) return result;
    } catch (e) {
      print('OSRM distance matrix failed: $e');
    }

    // Fallback to straight-line distances
    return origins.map((origin) {
      return destinations.map((dest) {
        return origin.distanceTo(dest);
      }).toList();
    }).toList();
  }

  /// Search nearby places (hotels, fuel stations, etc.) - ALWAYS use OSM (FREE)
  /// Google Places Nearby costs $32/1000 requests - OSM is free!
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
    MapProvider? provider,  // Ignored - always uses OSM for cost savings
  }) async {
    // Always use OSM for nearby search - saves $32 per 1000 requests!
    try {
      final results = await _osmService.searchNearby(
        latitude,
        longitude,
        type: type,
        radiusMeters: radiusMeters,
      ).timeout(const Duration(seconds: 8), onTimeout: () => <TripLocation>[]);
      if (results.isNotEmpty) return results;
    } catch (e) {
      print('OSM nearby search failed: $e');
    }

    return [];
  }

  /// Autocomplete - HYBRID: Google Places if key (better UX), else OSM (free)
  /// Google Places Autocomplete costs $2.83/1000 - worth it for UX
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    MapProvider? provider,
  }) async {
    // Prefer Google for autocomplete if key available (much better UX)
    final services = provider != null
        ? [_getService(provider)]
        : hasGoogleKey
            ? [_googleService, _osmService]  // Google first if available
            : [_osmService];                  // OSM only if no key

    for (var service in services) {
      try {
        final results = await service.autocomplete(input, location: location)
            .timeout(_serviceTimeout, onTimeout: () => <PlacePrediction>[]);
        if (results.isNotEmpty) return results;
      } catch (e) {
        print('${service.providerName} autocomplete failed: $e');
        continue;
      }
    }

    return [];
  }

  MapServiceInterface _getService(MapProvider provider) {
    switch (provider) {
      case MapProvider.google:
        return _googleService;
      case MapProvider.openStreetMap:
        return _osmService;
    }
  }

  MapServiceInterface _getServiceBySource(LocationSource source) {
    switch (source) {
      case LocationSource.googleMaps:
        return hasGoogleKey ? _googleService : _osmService;
      case LocationSource.openStreetMap:
        return _osmService;
      default:
        return _osmService;
    }
  }
}

// Riverpod providers

/// OSM Service - always available, no API key needed
final osmServiceProvider = Provider<OsmService>((ref) {
  return OsmService();
});

/// Google Maps Service - only useful if API key configured
final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  return GoogleMapsService(apiKey: ApiKeys.googleMaps);
});

/// Unified Map Service - uses OSM by default (free, always works)
final unifiedMapServiceProvider = Provider<UnifiedMapService>((ref) {
  final googleService = ref.watch(googleMapsServiceProvider);
  final osmService = ref.watch(osmServiceProvider);

  return UnifiedMapService(
    googleService: googleService,
    osmService: osmService,
    primaryProvider: MapProvider.openStreetMap,
  );
});

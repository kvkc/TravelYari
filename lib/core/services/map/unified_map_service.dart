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

/// Unified map service that uses OSM (free) by default
/// and optionally Google Maps if API key is configured.
class UnifiedMapService {
  /// Timeout for individual service calls (3 seconds)
  static const Duration _serviceTimeout = Duration(seconds: 3);

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

  /// Search places - uses OSM by default, Google if configured
  Future<List<TripLocation>> searchPlaces(
    String query, {
    LatLng? nearLocation,
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _availableServices;

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

  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    for (var service in _availableServices) {
      try {
        final result = await service.reverseGeocode(latitude, longitude)
            .timeout(_serviceTimeout, onTimeout: () => null);
        if (result != null) return result;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _availableServices;

    for (var service in services) {
      final result = await _withTimeout(() => service.getDirections(
        origin,
        destination,
        waypoints: waypoints,
      ));
      if (result != null) return result;
    }

    return null;
  }

  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations, {
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _availableServices;

    for (var service in services) {
      try {
        final result = await service.getDistanceMatrix(origins, destinations)
            .timeout(_serviceTimeout, onTimeout: () => <List<double>>[]);
        if (result.isNotEmpty) return result;
      } catch (e) {
        continue;
      }
    }

    // Fallback to straight-line distances
    return origins.map((origin) {
      return destinations.map((dest) {
        return origin.distanceTo(dest);
      }).toList();
    }).toList();
  }

  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _availableServices;

    for (var service in services) {
      try {
        final results = await service.searchNearby(
          latitude,
          longitude,
          type: type,
          radiusMeters: radiusMeters,
        ).timeout(_serviceTimeout, onTimeout: () => <TripLocation>[]);
        if (results.isNotEmpty) return results;
      } catch (e) {
        print('${service.providerName} nearby search failed: $e');
        continue;
      }
    }

    return [];
  }

  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _availableServices;

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

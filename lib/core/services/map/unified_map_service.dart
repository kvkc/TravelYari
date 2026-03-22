import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../api_keys.dart';
import '../api_key_storage.dart';
import 'map_service_interface.dart';
import 'google_maps_service.dart';
import 'mappls_service.dart';
import 'bhuvan_service.dart';
import 'osm_service.dart';

enum MapProvider {
  google,
  mappls,
  bhuvan,
  openStreetMap, // Free fallback, no API key needed
}

/// Unified map service that can switch between providers
/// and fallback to other providers if one fails.
/// OpenStreetMap is always available as the final fallback (no API key needed).
class UnifiedMapService {
  final GoogleMapsService _googleService;
  final MapplsService _mapplsService;
  final BhuvanService _bhuvanService;
  final OsmService _osmService;

  MapProvider _primaryProvider;

  UnifiedMapService({
    required GoogleMapsService googleService,
    required MapplsService mapplsService,
    required BhuvanService bhuvanService,
    required OsmService osmService,
    MapProvider primaryProvider = MapProvider.google,
  })  : _googleService = googleService,
        _mapplsService = mapplsService,
        _bhuvanService = bhuvanService,
        _osmService = osmService,
        _primaryProvider = primaryProvider;

  MapProvider get primaryProvider => _primaryProvider;

  void setPrimaryProvider(MapProvider provider) {
    _primaryProvider = provider;
  }

  MapServiceInterface get _primary {
    switch (_primaryProvider) {
      case MapProvider.google:
        return _googleService;
      case MapProvider.mappls:
        return _mapplsService;
      case MapProvider.bhuvan:
        return _bhuvanService;
      case MapProvider.openStreetMap:
        return _osmService;
    }
  }

  List<MapServiceInterface> get _fallbackOrder {
    // Return services in fallback order based on primary
    // OSM is always the last fallback since it's free and always available
    switch (_primaryProvider) {
      case MapProvider.google:
        return [_googleService, _mapplsService, _bhuvanService, _osmService];
      case MapProvider.mappls:
        return [_mapplsService, _googleService, _bhuvanService, _osmService];
      case MapProvider.bhuvan:
        return [_bhuvanService, _googleService, _mapplsService, _osmService];
      case MapProvider.openStreetMap:
        return [_osmService, _googleService, _mapplsService, _bhuvanService];
    }
  }

  /// Search places across all providers and merge results
  Future<List<TripLocation>> searchPlacesAllProviders(
    String query, {
    LatLng? nearLocation,
  }) async {
    final results = await Future.wait([
      _googleService.searchPlaces(query, nearLocation: nearLocation),
      _mapplsService.searchPlaces(query, nearLocation: nearLocation),
      _bhuvanService.searchPlaces(query, nearLocation: nearLocation),
      _osmService.searchPlaces(query, nearLocation: nearLocation),
    ]);

    // Merge and deduplicate results
    final allResults = <TripLocation>[];
    final seen = <String>{};

    for (var providerResults in results) {
      for (var location in providerResults) {
        // Create a key based on approximate coordinates
        final key = '${(location.latitude * 1000).round()}_${(location.longitude * 1000).round()}';
        if (!seen.contains(key)) {
          seen.add(key);
          allResults.add(location);
        }
      }
    }

    return allResults;
  }

  /// Search with primary provider and fallback
  Future<List<TripLocation>> searchPlaces(
    String query, {
    LatLng? nearLocation,
    MapProvider? provider,
  }) async {
    final services = provider != null
        ? [_getService(provider)]
        : _fallbackOrder;

    for (var service in services) {
      try {
        final results = await service.searchPlaces(query, nearLocation: nearLocation);
        if (results.isNotEmpty) return results;
      } catch (e) {
        print('${service.providerName} search failed: $e');
        continue;
      }
    }

    return [];
  }

  Future<TripLocation?> getPlaceDetails(String placeId, LocationSource source) async {
    final service = _getServiceBySource(source);
    return service.getPlaceDetails(placeId);
  }

  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    for (var service in _fallbackOrder) {
      try {
        final result = await service.reverseGeocode(latitude, longitude);
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
    // Bhuvan doesn't support routing, so exclude it for directions
    // OSM (OSRM) is included as free fallback
    final services = provider != null
        ? [_getService(provider)]
        : [_googleService, _mapplsService, _osmService];

    for (var service in services) {
      try {
        final result = await service.getDirections(
          origin,
          destination,
          waypoints: waypoints,
        );
        if (result != null) return result;
      } catch (e) {
        print('${service.providerName} directions failed: $e');
        continue;
      }
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
        : [_googleService, _mapplsService, _osmService];

    for (var service in services) {
      try {
        final result = await service.getDistanceMatrix(origins, destinations);
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
        : _fallbackOrder;

    for (var service in services) {
      try {
        final results = await service.searchNearby(
          latitude,
          longitude,
          type: type,
          radiusMeters: radiusMeters,
        );
        if (results.isNotEmpty) return results;
      } catch (e) {
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
        : _fallbackOrder;

    for (var service in services) {
      try {
        final results = await service.autocomplete(input, location: location);
        if (results.isNotEmpty) return results;
      } catch (e) {
        continue;
      }
    }

    return [];
  }

  MapServiceInterface _getService(MapProvider provider) {
    switch (provider) {
      case MapProvider.google:
        return _googleService;
      case MapProvider.mappls:
        return _mapplsService;
      case MapProvider.bhuvan:
        return _bhuvanService;
      case MapProvider.openStreetMap:
        return _osmService;
    }
  }

  MapServiceInterface _getServiceBySource(LocationSource source) {
    switch (source) {
      case LocationSource.googleMaps:
        return _googleService;
      case LocationSource.mappls:
        return _mapplsService;
      case LocationSource.bhuvan:
        return _bhuvanService;
      case LocationSource.openStreetMap:
        return _osmService;
      default:
        return _primary;
    }
  }
}

// Riverpod providers

/// OSM Service - always available, no API key needed
final osmServiceProvider = Provider<OsmService>((ref) {
  return OsmService();
});

/// Google Maps Service - uses user key if available, falls back to default
final googleMapsServiceProvider = FutureProvider<GoogleMapsService>((ref) async {
  final userKey = await ApiKeyStorage.getGoogleMapsKey();
  final apiKey = userKey?.isNotEmpty == true ? userKey! : ApiKeys.googleMaps;
  return GoogleMapsService(apiKey: apiKey);
});

/// Mappls Service - uses user keys if available
final mapplsServiceProvider = FutureProvider<MapplsService>((ref) async {
  final userKey = await ApiKeyStorage.getMapplsKey();
  final userClientId = await ApiKeyStorage.getMapplsClientId();
  final userClientSecret = await ApiKeyStorage.getMapplsClientSecret();

  return MapplsService(
    apiKey: userKey?.isNotEmpty == true ? userKey! : ApiKeys.mappls,
    clientId: userClientId?.isNotEmpty == true ? userClientId! : ApiKeys.mapplsClientId,
    clientSecret: userClientSecret?.isNotEmpty == true ? userClientSecret! : ApiKeys.mapplsClientSecret,
  );
});

/// Bhuvan Service
final bhuvanServiceProvider = Provider<BhuvanService>((ref) {
  return BhuvanService(apiKey: ApiKeys.bhuvan);
});

/// Unified Map Service - combines all providers with OSM as free fallback
final unifiedMapServiceProvider = FutureProvider<UnifiedMapService>((ref) async {
  final googleService = await ref.watch(googleMapsServiceProvider.future);
  final mapplsService = await ref.watch(mapplsServiceProvider.future);
  final bhuvanService = ref.watch(bhuvanServiceProvider);
  final osmService = ref.watch(osmServiceProvider);

  return UnifiedMapService(
    googleService: googleService,
    mapplsService: mapplsService,
    bhuvanService: bhuvanService,
    osmService: osmService,
  );
});

/// Sync version for places where we can't await
/// Uses OSM as the primary since it's always available
final unifiedMapServiceSyncProvider = Provider<UnifiedMapService>((ref) {
  // Create services with default/placeholder keys
  // OSM is the reliable fallback
  final googleService = GoogleMapsService(apiKey: ApiKeys.googleMaps);
  final mapplsService = MapplsService(
    apiKey: ApiKeys.mappls,
    clientId: ApiKeys.mapplsClientId,
    clientSecret: ApiKeys.mapplsClientSecret,
  );
  final bhuvanService = BhuvanService(apiKey: ApiKeys.bhuvan);
  final osmService = OsmService();

  return UnifiedMapService(
    googleService: googleService,
    mapplsService: mapplsService,
    bhuvanService: bhuvanService,
    osmService: osmService,
    // Default to OSM since it's free and always works
    primaryProvider: MapProvider.openStreetMap,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../api_keys.dart';
import 'map_service_interface.dart';
import 'google_maps_service.dart';
import 'mappls_service.dart';
import 'bhuvan_service.dart';

enum MapProvider {
  google,
  mappls,
  bhuvan,
}

/// Unified map service that can switch between providers
/// and fallback to other providers if one fails
class UnifiedMapService {
  final GoogleMapsService _googleService;
  final MapplsService _mapplsService;
  final BhuvanService _bhuvanService;

  MapProvider _primaryProvider;

  UnifiedMapService({
    required GoogleMapsService googleService,
    required MapplsService mapplsService,
    required BhuvanService bhuvanService,
    MapProvider primaryProvider = MapProvider.google,
  })  : _googleService = googleService,
        _mapplsService = mapplsService,
        _bhuvanService = bhuvanService,
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
    }
  }

  List<MapServiceInterface> get _fallbackOrder {
    // Return services in fallback order based on primary
    switch (_primaryProvider) {
      case MapProvider.google:
        return [_googleService, _mapplsService, _bhuvanService];
      case MapProvider.mappls:
        return [_mapplsService, _googleService, _bhuvanService];
      case MapProvider.bhuvan:
        return [_bhuvanService, _googleService, _mapplsService];
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
    final services = provider != null
        ? [_getService(provider)]
        : [_googleService, _mapplsService];

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
        : [_googleService, _mapplsService];

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
      default:
        return _primary;
    }
  }
}

// Riverpod providers
final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  return GoogleMapsService(apiKey: ApiKeys.googleMaps);
});

final mapplsServiceProvider = Provider<MapplsService>((ref) {
  return MapplsService(
    apiKey: ApiKeys.mappls,
    clientId: ApiKeys.mapplsClientId,
    clientSecret: ApiKeys.mapplsClientSecret,
  );
});

final bhuvanServiceProvider = Provider<BhuvanService>((ref) {
  return BhuvanService(apiKey: ApiKeys.bhuvan);
});

final unifiedMapServiceProvider = Provider<UnifiedMapService>((ref) {
  return UnifiedMapService(
    googleService: ref.watch(googleMapsServiceProvider),
    mapplsService: ref.watch(mapplsServiceProvider),
    bhuvanService: ref.watch(bhuvanServiceProvider),
  );
});

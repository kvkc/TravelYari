import 'package:dio/dio.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import 'map_service_interface.dart';

/// ISRO Bhuvan service implementation
/// API Documentation: https://bhuvan.nrsc.gov.in/
/// Note: Bhuvan has limited API compared to Google Maps/Mappls
class BhuvanService implements MapServiceInterface {
  final Dio _dio;
  final String _apiKey;

  static const String _baseUrl = 'https://bhuvan-vec1.nrsc.gov.in/bhuvan';

  BhuvanService({required String apiKey})
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  @override
  String get providerName => 'Bhuvan (ISRO)';

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    try {
      // Bhuvan uses WFS for place search
      final response = await _dio.get(
        '/wfs',
        queryParameters: {
          'service': 'WFS',
          'version': '1.1.0',
          'request': 'GetFeature',
          'typeName': 'india_village',
          'outputFormat': 'application/json',
          'CQL_FILTER': "name LIKE '%$query%'",
          'maxFeatures': 20,
          'apikey': _apiKey,
        },
      );

      if (response.data['features'] != null) {
        final features = response.data['features'] as List;
        return features.map((f) => _parseFeature(f)).toList();
      }

      return [];
    } catch (e) {
      print('Bhuvan search error: $e');
      return [];
    }
  }

  @override
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    // Bhuvan doesn't have a dedicated place details endpoint
    // Return null and let the app fall back to other providers
    return null;
  }

  @override
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    try {
      // Use Bhuvan's reverse geocoding service
      final response = await _dio.get(
        '/wfs',
        queryParameters: {
          'service': 'WFS',
          'version': '1.1.0',
          'request': 'GetFeature',
          'typeName': 'india_village',
          'outputFormat': 'application/json',
          'CQL_FILTER': "DWITHIN(the_geom, POINT($longitude $latitude), 5000, meters)",
          'maxFeatures': 1,
          'apikey': _apiKey,
        },
      );

      if (response.data['features'] != null && response.data['features'].isNotEmpty) {
        return _parseFeature(response.data['features'][0]);
      }

      return null;
    } catch (e) {
      print('Bhuvan reverse geocode error: $e');
      return null;
    }
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    // Bhuvan doesn't have a routing API
    // Return null and let the app use other providers for routing
    return null;
  }

  @override
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  ) async {
    // Bhuvan doesn't have a distance matrix API
    // Calculate straight-line distances as fallback
    return origins.map((origin) {
      return destinations.map((dest) {
        return origin.distanceTo(dest);
      }).toList();
    }).toList();
  }

  @override
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
  }) async {
    try {
      // Map type to Bhuvan layer
      final layerName = _mapToLayer(type);
      if (layerName == null) return [];

      final response = await _dio.get(
        '/wfs',
        queryParameters: {
          'service': 'WFS',
          'version': '1.1.0',
          'request': 'GetFeature',
          'typeName': layerName,
          'outputFormat': 'application/json',
          'CQL_FILTER': "DWITHIN(the_geom, POINT($longitude $latitude), $radiusMeters, meters)",
          'maxFeatures': 50,
          'apikey': _apiKey,
        },
      );

      if (response.data['features'] != null) {
        final features = response.data['features'] as List;
        return features.map((f) => _parseFeature(f)).toList();
      }

      return [];
    } catch (e) {
      print('Bhuvan nearby search error: $e');
      return [];
    }
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  }) async {
    // Bhuvan doesn't have autocomplete, use regular search
    final places = await searchPlaces(input, nearLocation: location);
    return places.map((p) => PlacePrediction(
      placeId: p.id,
      mainText: p.name,
      secondaryText: p.address ?? '',
      fullText: '${p.name}, ${p.address ?? ''}',
      source: LocationSource.bhuvan,
    )).toList();
  }

  String? _mapToLayer(String type) {
    const layerMap = {
      'gas_station': 'petrol_pumps_india',
      'restaurant': null, // Not available in Bhuvan
      'lodging': null,
      'town': 'india_village',
      'city': 'india_town',
    };
    return layerMap[type];
  }

  TripLocation _parseFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] ?? {};
    final geometry = feature['geometry'];

    double lat = 0;
    double lng = 0;

    if (geometry != null && geometry['coordinates'] != null) {
      final coords = geometry['coordinates'];
      if (geometry['type'] == 'Point') {
        lng = (coords[0] ?? 0).toDouble();
        lat = (coords[1] ?? 0).toDouble();
      } else if (geometry['type'] == 'MultiPoint' || geometry['type'] == 'Polygon') {
        // Take first point for polygon centroid approximation
        final firstCoord = coords is List && coords.isNotEmpty
            ? (coords[0] is List ? coords[0][0] : coords[0])
            : coords;
        if (firstCoord is List && firstCoord.length >= 2) {
          lng = (firstCoord[0] ?? 0).toDouble();
          lat = (firstCoord[1] ?? 0).toDouble();
        }
      }
    }

    return TripLocation(
      name: properties['name'] ?? properties['village_name'] ?? properties['town_name'] ?? 'Unknown',
      address: _buildAddress(properties),
      latitude: lat,
      longitude: lng,
      source: LocationSource.bhuvan,
      metadata: properties,
    );
  }

  String _buildAddress(Map<String, dynamic> properties) {
    final parts = <String>[];

    if (properties['village_name'] != null) parts.add(properties['village_name']);
    if (properties['sub_dist'] != null) parts.add(properties['sub_dist']);
    if (properties['district'] != null) parts.add(properties['district']);
    if (properties['state'] != null) parts.add(properties['state']);

    return parts.join(', ');
  }
}

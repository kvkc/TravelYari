import 'package:dio/dio.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import 'map_service_interface.dart';

/// Mappls (MapMyIndia) service implementation
/// API Documentation: https://about.mappls.com/api/
class MapplsService implements MapServiceInterface {
  final Dio _dio;
  final String _apiKey;
  final String _clientId;
  final String _clientSecret;
  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _authUrl = 'https://outpost.mappls.com/api/security/oauth/token';
  static const String _baseUrl = 'https://atlas.mappls.com/api';

  MapplsService({
    required String apiKey,
    required String clientId,
    required String clientSecret,
  })  : _apiKey = apiKey,
        _clientId = clientId,
        _clientSecret = clientSecret,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  @override
  String get providerName => 'Mappls (MapMyIndia)';

  Future<void> _ensureAuthenticated() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    try {
      final response = await _dio.post(
        _authUrl,
        data: {
          'grant_type': 'client_credentials',
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      _accessToken = response.data['access_token'];
      final expiresIn = response.data['expires_in'] ?? 86400;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
    } catch (e) {
      print('Mappls authentication error: $e');
      throw Exception('Failed to authenticate with Mappls');
    }
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_accessToken',
      };

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    await _ensureAuthenticated();

    try {
      final params = <String, dynamic>{
        'query': query,
        'region': 'IND',
      };

      if (nearLocation != null) {
        params['location'] = '${nearLocation.latitude},${nearLocation.longitude}';
      }

      final response = await _dio.get(
        '$_baseUrl/places/search/json',
        queryParameters: params,
        options: Options(headers: _authHeaders),
      );

      if (response.data['suggestedLocations'] != null) {
        final results = response.data['suggestedLocations'] as List;
        return results.map((place) => _parsePlace(place)).toList();
      }

      return [];
    } catch (e) {
      print('Mappls search error: $e');
      return [];
    }
  }

  @override
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    await _ensureAuthenticated();

    try {
      // In Mappls, placeId is the eLoc
      final response = await _dio.get(
        '$_baseUrl/places/geocode',
        queryParameters: {'address': placeId},
        options: Options(headers: _authHeaders),
      );

      if (response.data['copResults'] != null && response.data['copResults'].isNotEmpty) {
        return _parsePlaceDetails(response.data['copResults']);
      }

      return null;
    } catch (e) {
      print('Mappls place details error: $e');
      return null;
    }
  }

  @override
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    await _ensureAuthenticated();

    try {
      final response = await _dio.get(
        '$_baseUrl/places/geocode',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
        },
        options: Options(headers: _authHeaders),
      );

      if (response.data['results'] != null && response.data['results'].isNotEmpty) {
        final result = response.data['results'][0];
        return TripLocation(
          name: result['formatted_address'] ?? 'Unknown Location',
          address: result['formatted_address'],
          latitude: latitude,
          longitude: longitude,
          source: LocationSource.mappls,
          eloc: result['eLoc'],
        );
      }

      return null;
    } catch (e) {
      print('Mappls reverse geocode error: $e');
      return null;
    }
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    await _ensureAuthenticated();

    try {
      String coords = '${origin.longitude},${origin.latitude}';

      if (waypoints != null && waypoints.isNotEmpty) {
        for (var wp in waypoints) {
          coords += ';${wp.longitude},${wp.latitude}';
        }
      }

      coords += ';${destination.longitude},${destination.latitude}';

      final response = await _dio.get(
        '$_baseUrl/directions/route/v1/driving/$coords',
        queryParameters: {
          'geometries': 'polyline',
          'overview': 'full',
          'steps': 'true',
        },
        options: Options(headers: _authHeaders),
      );

      if (response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final route = response.data['routes'][0];

        // Decode polyline
        final polyline = route['geometry'] as String;
        final points = _decodePolyline(polyline);

        return RouteSegment(
          start: origin,
          end: destination,
          distanceKm: route['distance'] / 1000,
          durationMinutes: (route['duration'] / 60).round(),
          polylinePoints: points,
          routeProvider: 'mappls',
        );
      }

      return null;
    } catch (e) {
      print('Mappls directions error: $e');
      return null;
    }
  }

  @override
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  ) async {
    await _ensureAuthenticated();

    try {
      final sources = origins.map((o) => '${o.longitude},${o.latitude}').join(';');
      final dests = destinations.map((d) => '${d.longitude},${d.latitude}').join(';');

      final response = await _dio.get(
        '$_baseUrl/directions/distance_matrix/driving/$sources;$dests',
        queryParameters: {
          'sources': List.generate(origins.length, (i) => i).join(';'),
          'destinations': List.generate(destinations.length, (i) => i + origins.length).join(';'),
        },
        options: Options(headers: _authHeaders),
      );

      if (response.data['distances'] != null) {
        final distances = response.data['distances'] as List;
        return distances.map<List<double>>((row) {
          return (row as List).map<double>((d) => (d ?? double.infinity) / 1000).toList();
        }).toList();
      }

      return [];
    } catch (e) {
      print('Mappls distance matrix error: $e');
      return [];
    }
  }

  @override
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
  }) async {
    await _ensureAuthenticated();

    try {
      // Map common types to Mappls categories
      final mapplsType = _mapToMapplsType(type);

      final response = await _dio.get(
        '$_baseUrl/places/nearby/json',
        queryParameters: {
          'keywords': mapplsType,
          'refLocation': '$latitude,$longitude',
          'radius': radiusMeters,
        },
        options: Options(headers: _authHeaders),
      );

      if (response.data['suggestedLocations'] != null) {
        final results = response.data['suggestedLocations'] as List;
        return results.map((place) => _parsePlace(place)).toList();
      }

      return [];
    } catch (e) {
      print('Mappls nearby search error: $e');
      return [];
    }
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  }) async {
    await _ensureAuthenticated();

    try {
      final params = <String, dynamic>{
        'query': input,
        'region': 'IND',
        'tokenizeAddress': 'true',
      };

      if (location != null) {
        params['location'] = '${location.latitude},${location.longitude}';
        params['radius'] = radiusMeters;
      }

      final response = await _dio.get(
        '$_baseUrl/places/search/json',
        queryParameters: params,
        options: Options(headers: _authHeaders),
      );

      if (response.data['suggestedLocations'] != null) {
        final predictions = response.data['suggestedLocations'] as List;
        return predictions.map((p) => PlacePrediction(
          placeId: p['eLoc'] ?? '',
          mainText: p['placeName'] ?? '',
          secondaryText: p['placeAddress'] ?? '',
          fullText: '${p['placeName'] ?? ''}, ${p['placeAddress'] ?? ''}',
          source: LocationSource.mappls,
        )).toList();
      }

      return [];
    } catch (e) {
      print('Mappls autocomplete error: $e');
      return [];
    }
  }

  String _mapToMapplsType(String googleType) {
    const typeMap = {
      'gas_station': 'PETROL PUMP',
      'electric_vehicle_charging_station': 'EV CHARGING',
      'restaurant': 'RESTAURANT',
      'lodging': 'HOTEL',
      'cafe': 'CAFE',
    };
    return typeMap[googleType] ?? googleType.toUpperCase();
  }

  TripLocation _parsePlace(Map<String, dynamic> place) {
    return TripLocation(
      name: place['placeName'] ?? 'Unknown',
      address: place['placeAddress'],
      latitude: (place['latitude'] ?? 0).toDouble(),
      longitude: (place['longitude'] ?? 0).toDouble(),
      source: LocationSource.mappls,
      eloc: place['eLoc'],
      metadata: {
        'type': place['type'],
        'orderIndex': place['orderIndex'],
      },
    );
  }

  TripLocation _parsePlaceDetails(Map<String, dynamic> place) {
    return TripLocation(
      name: place['formatted_address'] ?? 'Unknown',
      address: place['formatted_address'],
      latitude: (place['latitude'] ?? 0).toDouble(),
      longitude: (place['longitude'] ?? 0).toDouble(),
      source: LocationSource.mappls,
      eloc: place['eLoc'],
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

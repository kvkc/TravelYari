import 'package:dio/dio.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import 'map_service_interface.dart';

class GoogleMapsService implements MapServiceInterface {
  final Dio _dio;
  final String _apiKey;

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  GoogleMapsService({required String apiKey})
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  @override
  String get providerName => 'Google Maps';

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    try {
      final params = {
        'query': query,
        'key': _apiKey,
      };

      if (nearLocation != null) {
        params['location'] = '${nearLocation.latitude},${nearLocation.longitude}';
        params['radius'] = '50000';
      }

      final response = await _dio.get('/place/textsearch/json', queryParameters: params);

      if (response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) => _parsePlace(place)).toList();
      }

      return [];
    } catch (e) {
      print('Google Maps search error: $e');
      return [];
    }
  }

  @override
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get('/place/details/json', queryParameters: {
        'place_id': placeId,
        'fields': 'name,formatted_address,geometry,place_id,types',
        'key': _apiKey,
      });

      if (response.data['status'] == 'OK') {
        return _parsePlaceDetails(response.data['result']);
      }

      return null;
    } catch (e) {
      print('Google Maps place details error: $e');
      return null;
    }
  }

  @override
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await _dio.get('/geocode/json', queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': _apiKey,
      });

      if (response.data['status'] == 'OK' && response.data['results'].isNotEmpty) {
        final result = response.data['results'][0];
        return TripLocation(
          name: result['formatted_address'] ?? 'Unknown Location',
          address: result['formatted_address'],
          latitude: latitude,
          longitude: longitude,
          source: LocationSource.googleMaps,
          placeId: result['place_id'],
        );
      }

      return null;
    } catch (e) {
      print('Google Maps reverse geocode error: $e');
      return null;
    }
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    try {
      final params = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': _apiKey,
      };

      if (waypoints != null && waypoints.isNotEmpty) {
        params['waypoints'] = waypoints
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');
      }

      final response = await _dio.get('/directions/json', queryParameters: params);

      if (response.data['status'] == 'OK' && response.data['routes'].isNotEmpty) {
        final route = response.data['routes'][0];
        final leg = route['legs'][0];

        // Decode polyline
        final polyline = route['overview_polyline']['points'] as String;
        final points = _decodePolyline(polyline);

        return RouteSegment(
          start: origin,
          end: destination,
          distanceKm: leg['distance']['value'] / 1000,
          durationMinutes: (leg['duration']['value'] / 60).round(),
          polylinePoints: points,
          routeProvider: 'google',
        );
      }

      return null;
    } catch (e) {
      print('Google Maps directions error: $e');
      return null;
    }
  }

  @override
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  ) async {
    try {
      final response = await _dio.get('/distancematrix/json', queryParameters: {
        'origins': origins.map((o) => '${o.latitude},${o.longitude}').join('|'),
        'destinations': destinations.map((d) => '${d.latitude},${d.longitude}').join('|'),
        'mode': 'driving',
        'key': _apiKey,
      });

      if (response.data['status'] == 'OK') {
        final rows = response.data['rows'] as List;
        return rows.map<List<double>>((row) {
          final elements = row['elements'] as List;
          return elements.map<double>((elem) {
            if (elem['status'] == 'OK') {
              return elem['distance']['value'] / 1000; // Convert to km
            }
            return double.infinity;
          }).toList();
        }).toList();
      }

      return [];
    } catch (e) {
      print('Google Maps distance matrix error: $e');
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
    try {
      final response = await _dio.get('/place/nearbysearch/json', queryParameters: {
        'location': '$latitude,$longitude',
        'radius': radiusMeters,
        'type': type,
        'key': _apiKey,
      });

      if (response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) => _parsePlace(place)).toList();
      }

      return [];
    } catch (e) {
      print('Google Maps nearby search error: $e');
      return [];
    }
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  }) async {
    try {
      final params = {
        'input': input,
        'key': _apiKey,
        'components': 'country:in', // Restrict to India
      };

      if (location != null) {
        params['location'] = '${location.latitude},${location.longitude}';
        params['radius'] = radiusMeters.toString();
      }

      final response = await _dio.get('/place/autocomplete/json', queryParameters: params);

      if (response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        return predictions.map((p) => PlacePrediction(
          placeId: p['place_id'],
          mainText: p['structured_formatting']['main_text'] ?? '',
          secondaryText: p['structured_formatting']['secondary_text'] ?? '',
          fullText: p['description'] ?? '',
          source: LocationSource.googleMaps,
        )).toList();
      }

      return [];
    } catch (e) {
      print('Google Maps autocomplete error: $e');
      return [];
    }
  }

  TripLocation _parsePlace(Map<String, dynamic> place) {
    final geometry = place['geometry']['location'];
    return TripLocation(
      name: place['name'] ?? 'Unknown',
      address: place['formatted_address'] ?? place['vicinity'],
      latitude: geometry['lat'].toDouble(),
      longitude: geometry['lng'].toDouble(),
      source: LocationSource.googleMaps,
      placeId: place['place_id'],
      metadata: {
        'types': place['types'],
        'rating': place['rating'],
        'user_ratings_total': place['user_ratings_total'],
      },
    );
  }

  TripLocation _parsePlaceDetails(Map<String, dynamic> place) {
    final geometry = place['geometry']['location'];
    return TripLocation(
      name: place['name'] ?? 'Unknown',
      address: place['formatted_address'],
      latitude: geometry['lat'].toDouble(),
      longitude: geometry['lng'].toDouble(),
      source: LocationSource.googleMaps,
      placeId: place['place_id'],
      metadata: {
        'types': place['types'],
      },
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

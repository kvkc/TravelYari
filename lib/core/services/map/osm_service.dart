import 'package:dio/dio.dart';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import 'map_service_interface.dart';

/// OpenStreetMap + OSRM service - completely free, no API key required
class OsmService implements MapServiceInterface {
  final Dio _dio;

  // Free public OSRM server (has rate limits, but works for personal use)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  // Nominatim for geocoding (free, requires User-Agent)
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  // Photon for autocomplete (free, fast)
  static const String _photonBaseUrl = 'https://photon.komoot.io';

  OsmService() : _dio = Dio() {
    _dio.options.headers['User-Agent'] = 'YatraPlanner/1.0';
  }

  @override
  String get providerName => 'OpenStreetMap';

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'format': 'json',
        'limit': 10,
        'addressdetails': 1,
      };

      if (nearLocation != null) {
        params['viewbox'] = '${nearLocation.longitude - 1},${nearLocation.latitude + 1},${nearLocation.longitude + 1},${nearLocation.latitude - 1}';
        params['bounded'] = 0;
      }

      final response = await _dio.get(
        '$_nominatimBaseUrl/search',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data;
        return results.map((place) => _parseNominatimPlace(place)).toList();
      }
    } catch (e) {
      print('OSM search failed: $e');
    }
    return [];
  }

  @override
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    try {
      // placeId format: "osm_type/osm_id" e.g., "N123456" or "W789"
      final response = await _dio.get(
        '$_nominatimBaseUrl/lookup',
        queryParameters: {
          'osm_ids': placeId,
          'format': 'json',
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200 && response.data.isNotEmpty) {
        return _parseNominatimPlace(response.data[0]);
      }
    } catch (e) {
      print('OSM place details failed: $e');
    }
    return null;
  }

  @override
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        '$_nominatimBaseUrl/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'json',
          'addressdetails': 1,
        },
      );

      if (response.statusCode == 200) {
        return _parseNominatimPlace(response.data);
      }
    } catch (e) {
      print('OSM reverse geocode failed: $e');
    }
    return null;
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    try {
      // Build coordinates string: lon,lat;lon,lat;...
      final coords = <String>[
        '${origin.longitude},${origin.latitude}',
        if (waypoints != null)
          ...waypoints.map((w) => '${w.longitude},${w.latitude}'),
        '${destination.longitude},${destination.latitude}',
      ].join(';');

      final response = await _dio.get(
        '$_osrmBaseUrl/route/v1/driving/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'polyline',
          'steps': 'true',
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final route = response.data['routes'][0];
        return RouteSegment(
          startLocation: origin,
          endLocation: destination,
          distanceKm: route['distance'] / 1000,
          durationMinutes: (route['duration'] / 60).round(),
          polylinePoints: route['geometry'],
          source: LocationSource.openStreetMap,
        );
      }
    } catch (e) {
      print('OSRM directions failed: $e');
    }
    return null;
  }

  @override
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  ) async {
    try {
      // OSRM table service for distance matrix
      final allPoints = [...origins, ...destinations];
      final coords = allPoints.map((p) => '${p.longitude},${p.latitude}').join(';');

      // Source indices (origins)
      final sourceIndices = List.generate(origins.length, (i) => i).join(';');
      // Destination indices
      final destIndices = List.generate(
        destinations.length,
        (i) => i + origins.length,
      ).join(';');

      final response = await _dio.get(
        '$_osrmBaseUrl/table/v1/driving/$coords',
        queryParameters: {
          'sources': sourceIndices,
          'destinations': destIndices,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final durations = response.data['durations'] as List;
        // Convert durations (seconds) to distances (km) using avg speed of 50 km/h
        return durations.map<List<double>>((row) {
          return (row as List).map<double>((duration) {
            if (duration == null) return double.infinity;
            // Estimate distance from duration (assuming 50 km/h average)
            return (duration as num) / 3600 * 50;
          }).toList();
        }).toList();
      }
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

  @override
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
  }) async {
    try {
      // Convert type to OSM amenity
      final osmType = _convertToOsmType(type);

      // Use Overpass API for nearby search (free)
      final query = '''
        [out:json][timeout:10];
        (
          node["amenity"="$osmType"](around:$radiusMeters,$latitude,$longitude);
          way["amenity"="$osmType"](around:$radiusMeters,$latitude,$longitude);
        );
        out center 20;
      ''';

      final response = await _dio.post(
        'https://overpass-api.de/api/interpreter',
        data: query,
        options: Options(contentType: 'text/plain'),
      );

      if (response.statusCode == 200) {
        final elements = response.data['elements'] as List;
        return elements.map((e) => _parseOverpassElement(e)).toList();
      }
    } catch (e) {
      print('OSM nearby search failed: $e');
    }
    return [];
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': input,
        'limit': 10,
      };

      if (location != null) {
        params['lat'] = location.latitude;
        params['lon'] = location.longitude;
      }

      final response = await _dio.get(
        '$_photonBaseUrl/api/',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final features = response.data['features'] as List;
        return features.map((f) => _parsePhotonFeature(f)).toList();
      }
    } catch (e) {
      print('Photon autocomplete failed: $e');
    }
    return [];
  }

  TripLocation _parseNominatimPlace(Map<String, dynamic> place) {
    final address = place['address'] as Map<String, dynamic>?;
    String name = place['display_name'] ?? '';

    // Try to get a shorter name
    if (address != null) {
      name = address['name'] ??
          address['amenity'] ??
          address['road'] ??
          address['city'] ??
          place['display_name'] ??
          '';
    }

    final osmType = place['osm_type']?.toString().substring(0, 1).toUpperCase() ?? 'N';
    final osmId = place['osm_id']?.toString() ?? '';

    return TripLocation(
      name: name,
      address: place['display_name'],
      latitude: double.tryParse(place['lat'].toString()) ?? 0,
      longitude: double.tryParse(place['lon'].toString()) ?? 0,
      placeId: '$osmType$osmId',
      source: LocationSource.openStreetMap,
    );
  }

  TripLocation _parseOverpassElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
    final lon = element['lon'] ?? element['center']?['lon'] ?? 0.0;

    return TripLocation(
      name: tags['name'] ?? tags['amenity'] ?? 'Unknown',
      address: tags['addr:full'] ??
               '${tags['addr:street'] ?? ''} ${tags['addr:city'] ?? ''}'.trim(),
      latitude: (lat as num).toDouble(),
      longitude: (lon as num).toDouble(),
      placeId: '${element['type']?.toString().substring(0, 1).toUpperCase()}${element['id']}',
      source: LocationSource.openStreetMap,
    );
  }

  PlacePrediction _parsePhotonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List;

    final name = props['name'] ?? '';
    final city = props['city'] ?? props['county'] ?? '';
    final state = props['state'] ?? '';
    final country = props['country'] ?? '';

    final secondary = [city, state, country].where((s) => s.isNotEmpty).join(', ');

    return PlacePrediction(
      placeId: '${props['osm_type']?.toString().substring(0, 1).toUpperCase() ?? 'N'}${props['osm_id'] ?? ''}',
      mainText: name,
      secondaryText: secondary,
      fullText: '$name, $secondary',
      source: LocationSource.openStreetMap,
    );
  }

  String _convertToOsmType(String type) {
    switch (type.toLowerCase()) {
      case 'gas_station':
      case 'petrol':
      case 'fuel':
        return 'fuel';
      case 'ev_charging':
      case 'charging_station':
        return 'charging_station';
      case 'restaurant':
      case 'food':
        return 'restaurant';
      case 'cafe':
      case 'coffee':
        return 'cafe';
      case 'hotel':
      case 'lodging':
        return 'hotel';
      case 'parking':
        return 'parking';
      case 'atm':
        return 'atm';
      case 'hospital':
        return 'hospital';
      default:
        return type;
    }
  }
}

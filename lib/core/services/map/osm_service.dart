import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import 'map_service_interface.dart';

/// OpenStreetMap + OSRM service - completely free, no API key required
class OsmService implements MapServiceInterface {
  final Dio _dio;

  // Base URLs without proxy - proxy added per-request on web
  static const String _osrmBase = 'https://router.project-osrm.org';
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String _photonBase = 'https://photon.komoot.io';

  // Get URL with CORS proxy for web
  static String _proxyUrl(String url) {
    if (kIsWeb) {
      return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  OsmService() : _dio = Dio() {
    _dio.options.headers['User-Agent'] = 'TravelYaari/1.0 (travel planning app)';
    _dio.options.headers['Accept'] = 'application/json';
    // Add timeout for better UX
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  @override
  String get providerName => 'OpenStreetMap';

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    // Try Photon first
    try {
      var url = '$_photonBase/api/?q=${Uri.encodeComponent(query)}&limit=10';
      if (nearLocation != null) {
        url += '&lat=${nearLocation.latitude}&lon=${nearLocation.longitude}';
      }

      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = response.data is String ?
            (await _dio.get(_proxyUrl(url))).data : response.data;
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          return features.map((f) => _parsePhotonToLocation(f)).toList();
        }
      }
    } catch (e) {
      print('Photon search failed: $e');
    }

    // Fallback to Nominatim
    try {
      var url = '$_nominatimBase/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1';
      if (nearLocation != null) {
        url += '&viewbox=${nearLocation.longitude - 1},${nearLocation.latitude + 1},${nearLocation.longitude + 1},${nearLocation.latitude - 1}&bounded=0';
      }

      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data is List ? response.data : [];
        return results.map((place) => _parseNominatimPlace(place)).toList();
      }
    } catch (e) {
      print('Nominatim search failed: $e');
    }
    return [];
  }

  TripLocation _parsePhotonToLocation(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List;

    final name = props['name'] ?? props['city'] ?? props['county'] ?? 'Unknown';
    final city = props['city'] ?? props['town'] ?? props['village'] ?? '';
    final state = props['state'] ?? '';
    final country = props['country'] ?? '';
    final address = [city, state, country].where((s) => s.isNotEmpty).join(', ');

    final osmType = props['osm_type']?.toString().substring(0, 1).toUpperCase() ?? 'N';
    final osmId = props['osm_id']?.toString() ?? '';

    return TripLocation(
      name: name,
      address: address.isNotEmpty ? address : null,
      latitude: (coords[1] as num).toDouble(),
      longitude: (coords[0] as num).toDouble(),
      placeId: '$osmType$osmId',
      source: LocationSource.openStreetMap,
    );
  }

  @override
  Future<TripLocation?> getPlaceDetails(String placeId) async {
    try {
      // placeId format: "osm_type/osm_id" e.g., "N123456" or "W789"
      final url = '$_nominatimBase/lookup?osm_ids=$placeId&format=json&addressdetails=1';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
        return _parseNominatimPlace(response.data[0]);
      }
    } catch (e) {
      print('OSM place details failed: $e');
    }
    return null;
  }

  @override
  Future<TripLocation?> reverseGeocode(double latitude, double longitude) async {
    // Try Photon first
    try {
      final url = '$_photonBase/reverse?lat=$latitude&lon=$longitude&limit=1';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data != null) {
        final features = response.data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features[0]['properties'] as Map<String, dynamic>;
          final coords = features[0]['geometry']['coordinates'] as List;

          final name = props['name'] ??
              props['city'] ??
              props['town'] ??
              props['village'] ??
              props['county'] ??
              props['state'] ??
              'Unknown location';

          final city = props['city'] ?? props['town'] ?? props['village'] ?? '';
          final state = props['state'] ?? '';
          final country = props['country'] ?? '';
          final address = [city, state, country].where((s) => s.isNotEmpty).join(', ');

          return TripLocation(
            name: name,
            address: address.isNotEmpty ? address : null,
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
            source: LocationSource.openStreetMap,
          );
        }
      }
    } catch (e) {
      print('Photon reverse geocode failed: $e');
    }

    // Fallback to Nominatim
    try {
      final url = '$_nominatimBase/reverse?lat=$latitude&lon=$longitude&format=json&addressdetails=1';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.data != null) {
        return _parseNominatimPlace(response.data);
      }
    } catch (e) {
      print('Nominatim reverse geocode failed: $e');
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

      // Request alternatives and annotations for better route selection
      final url = '$_osrmBase/route/v1/driving/$coords?overview=full&geometries=polyline&steps=true&alternatives=true&annotations=distance,duration';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final route = response.data['routes'][0];
        return RouteSegment(
          start: origin,
          end: destination,
          distanceKm: route['distance'] / 1000,
          durationMinutes: (route['duration'] / 60).round(),
          polylinePoints: _decodePolyline(route['geometry']),
          routeProvider: 'openStreetMap',
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

      final url = '$_osrmBase/table/v1/driving/$coords?sources=$sourceIndices&destinations=$destIndices';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 10));

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
    // Convert type to OSM amenity
    final osmType = _convertToOsmType(type);

    // Try Nominatim first
    try {
      final viewbox = '${longitude - 0.1},${latitude + 0.1},${longitude + 0.1},${latitude - 0.1}';
      final url = '$_nominatimBase/search?q=${Uri.encodeComponent(osmType)}&format=json&limit=10&addressdetails=1&viewbox=$viewbox&bounded=1';
      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final results = response.data as List? ?? [];
        if (results.isNotEmpty) {
          return results.map((place) => _parseNominatimPlace(place)).toList();
        }
      }
    } catch (e) {
      print('Nominatim nearby search failed: $e');
    }

    // Fallback to Overpass API
    try {
      final query = '[out:json][timeout:5];'
          '(node["amenity"="$osmType"](around:$radiusMeters,$latitude,$longitude););'
          'out 10;';

      final overpassUrl = 'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
      final response = await _dio.get(_proxyUrl(overpassUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final elements = response.data['elements'] as List? ?? [];
        return elements.map((e) => _parseOverpassElement(e)).toList();
      }
    } catch (e) {
      print('Overpass nearby search failed: $e');
    }

    return [];
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  }) async {
    // Try Photon first (faster)
    try {
      var url = '$_photonBase/api/?q=${Uri.encodeComponent(input)}&limit=10';
      if (location != null) {
        url += '&lat=${location.latitude}&lon=${location.longitude}';
      }

      final response = await _dio.get(_proxyUrl(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.data != null) {
        final features = response.data['features'] as List? ?? [];
        if (features.isNotEmpty) {
          return features.map((f) => _parsePhotonFeature(f)).toList();
        }
      }
    } catch (e) {
      print('Photon autocomplete failed: $e, trying Nominatim...');
    }

    // Fallback to Nominatim search
    try {
      final searchResults = await searchPlaces(input, nearLocation: location);
      return searchResults.map((loc) => PlacePrediction(
        placeId: loc.placeId ?? loc.id,
        mainText: loc.name,
        secondaryText: loc.address ?? '',
        fullText: loc.address ?? loc.name,
        source: LocationSource.openStreetMap,
      )).toList();
    } catch (e) {
      print('Nominatim fallback also failed: $e');
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

  /// Decode Google-style polyline encoding (used by OSRM)
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/amenity.dart';
import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../api_keys.dart';
import '../map/unified_map_service.dart';

class AmenitiesService {
  final UnifiedMapService _mapService;
  final Dio _dio;

  /// Timeout for individual amenity lookups (2 seconds)
  static const Duration _timeout = Duration(seconds: 2);

  AmenitiesService(this._mapService)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));

  /// Find petrol stations along a route
  Future<List<Amenity>> findPetrolStations({
    required List<LatLng> routePoints,
    double searchRadiusKm = 2.0,
    int maxResults = 20,
  }) async {
    return _findAlongRoute(
      routePoints: routePoints,
      type: 'gas_station',
      amenityType: AmenityType.petrolStation,
      searchRadiusKm: searchRadiusKm,
      maxResults: maxResults,
    );
  }

  /// Find EV charging stations along a route
  Future<List<Amenity>> findEvStations({
    required List<LatLng> routePoints,
    double searchRadiusKm = 5.0,
    int maxResults = 20,
  }) async {
    return _findAlongRoute(
      routePoints: routePoints,
      type: 'electric_vehicle_charging_station',
      amenityType: AmenityType.evStation,
      searchRadiusKm: searchRadiusKm,
      maxResults: maxResults,
    );
  }

  /// Find restaurants along a route with minimum rating
  Future<List<Amenity>> findRestaurants({
    required List<LatLng> routePoints,
    double minRating = 4.0,
    double searchRadiusKm = 2.0,
    int maxResults = 30,
    bool preferGoodWashrooms = true,
  }) async {
    final places = await _findAlongRoute(
      routePoints: routePoints,
      type: 'restaurant',
      amenityType: AmenityType.restaurant,
      searchRadiusKm: searchRadiusKm,
      maxResults: maxResults * 2, // Get more to filter
    );

    // Filter by rating
    var filtered = places.where((p) => (p.rating ?? 0) >= minRating).toList();

    // Sort by rating and washroom quality
    filtered.sort((a, b) {
      // Priority: good washroom with high rating
      if (preferGoodWashrooms) {
        if (a.hasGoodWashroom && !b.hasGoodWashroom) return -1;
        if (!a.hasGoodWashroom && b.hasGoodWashroom) return 1;
      }
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    });

    return filtered.take(maxResults).toList();
  }

  /// Find tea/coffee stalls for short breaks
  Future<List<Amenity>> findTeaStalls({
    required List<LatLng> routePoints,
    double searchRadiusKm = 1.0,
    int maxResults = 20,
  }) async {
    return _findAlongRoute(
      routePoints: routePoints,
      type: 'cafe',
      amenityType: AmenityType.teaStall,
      searchRadiusKm: searchRadiusKm,
      maxResults: maxResults,
    );
  }

  /// Find good meal/dining locations for meal breaks
  /// Searches for restaurants with good ratings and food quality
  Future<List<Amenity>> findMealBreakLocations({
    required LatLng location,
    double minRating = 3.5,
    double searchRadiusKm = 5.0,
    int maxResults = 10,
    bool preferGoodWashrooms = true,
  }) async {
    try {
      // Search for restaurants
      final places = await _mapService.searchNearby(
        location.latitude,
        location.longitude,
        type: 'restaurant',
        radiusMeters: (searchRadiusKm * 1000).round(),
      ).timeout(_timeout * 2, onTimeout: () => <TripLocation>[]);

      if (places.isEmpty) {
        // Fallback to cafes with food if no restaurants found
        final cafes = await _mapService.searchNearby(
          location.latitude,
          location.longitude,
          type: 'cafe',
          radiusMeters: (searchRadiusKm * 1000).round(),
        ).timeout(_timeout, onTimeout: () => <TripLocation>[]);

        return cafes.take(maxResults).map((place) => Amenity(
          name: place.name,
          address: place.address,
          latitude: place.latitude,
          longitude: place.longitude,
          type: AmenityType.restaurant,
          rating: place.metadata?['rating']?.toDouble(),
          reviewCount: place.metadata?['user_ratings_total'],
          source: 'osm',
          placeId: place.placeId,
        )).toList();
      }

      List<Amenity> amenities = places.map((place) => Amenity(
        name: place.name,
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
        type: AmenityType.restaurant,
        rating: place.metadata?['rating']?.toDouble(),
        reviewCount: place.metadata?['user_ratings_total'],
        source: 'osm',
        placeId: place.placeId,
      )).toList();

      // Filter by minimum rating
      var filtered = amenities.where((a) => (a.rating ?? 3.0) >= minRating).toList();

      // If no places meet rating, use unfiltered
      if (filtered.isEmpty) {
        filtered = amenities;
      }

      // Sort by rating and washroom quality
      filtered.sort((a, b) {
        if (preferGoodWashrooms) {
          if (a.hasGoodWashroom && !b.hasGoodWashroom) return -1;
          if (!a.hasGoodWashroom && b.hasGoodWashroom) return 1;
        }
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });

      return filtered.take(maxResults).toList();
    } catch (e) {
      print('Find meal locations failed: $e');
      return [];
    }
  }

  /// Find break stop with intelligent selection based on break type and time
  /// Returns restaurants for meal times, cafes for tea breaks
  Future<Amenity?> findBreakStop({
    required LatLng location,
    required bool isMealTime,
    double minRating = 3.5,
    double searchRadiusKm = 5.0,
    bool preferGoodWashrooms = true,
  }) async {
    try {
      if (isMealTime) {
        final restaurants = await findMealBreakLocations(
          location: location,
          minRating: minRating,
          searchRadiusKm: searchRadiusKm,
          maxResults: 5,
          preferGoodWashrooms: preferGoodWashrooms,
        );
        return restaurants.isNotEmpty ? restaurants.first : null;
      } else {
        final teaStalls = await findTeaStalls(
          routePoints: [location],
          searchRadiusKm: searchRadiusKm,
          maxResults: 5,
        );
        return teaStalls.isNotEmpty ? teaStalls.first : null;
      }
    } catch (e) {
      print('Find break stop failed: $e');
      return null;
    }
  }

  /// Find hotels/stays with minimum rating and proximity to towns
  /// Uses timeout to prevent hanging
  Future<List<Amenity>> findStayOptions({
    required LatLng location,
    double minRating = 3.5,
    double searchRadiusKm = 10.0,
    int maxResults = 10,
    bool preferGoodWashrooms = true,
  }) async {
    try {
      final places = await _mapService.searchNearby(
        location.latitude,
        location.longitude,
        type: 'lodging',
        radiusMeters: (searchRadiusKm * 1000).round(),
      ).timeout(_timeout, onTimeout: () => <TripLocation>[]);

      if (places.isEmpty) return [];

      List<Amenity> amenities = [];
      for (var place in places.take(maxResults * 2)) {
        // Skip enrichment to save time - use basic data
        final amenity = Amenity(
          name: place.name,
          address: place.address,
          latitude: place.latitude,
          longitude: place.longitude,
          type: AmenityType.hotel,
          rating: place.metadata?['rating']?.toDouble(),
          reviewCount: place.metadata?['user_ratings_total'],
          source: 'osm',
          placeId: place.placeId,
        );
        amenities.add(amenity);
      }

      // Filter and sort
      var filtered = amenities.where((a) => (a.rating ?? 0) >= minRating).toList();

      // If no places meet the rating criteria, return what we have
      if (filtered.isEmpty && amenities.isNotEmpty) {
        filtered = amenities;
      }

      filtered.sort((a, b) {
        if (preferGoodWashrooms) {
          if (a.hasGoodWashroom && !b.hasGoodWashroom) return -1;
          if (!a.hasGoodWashroom && b.hasGoodWashroom) return 1;
        }
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });

      return filtered.take(maxResults).toList();
    } catch (e) {
      print('Find stay options failed: $e');
      return [];
    }
  }

  /// Find amenities along a route at regular intervals
  /// Uses short timeouts and limits to prevent hanging
  Future<List<Amenity>> _findAlongRoute({
    required List<LatLng> routePoints,
    required String type,
    required AmenityType amenityType,
    double searchRadiusKm = 2.0,
    int maxResults = 20,
  }) async {
    // Sample fewer points to reduce API calls (every 100km instead of 50km)
    List<LatLng> samplePoints = _sampleRoutePoints(routePoints, intervalKm: 100);

    // Limit to max 3 sample points to prevent too many API calls
    if (samplePoints.length > 3) {
      final interval = samplePoints.length ~/ 3;
      samplePoints = [
        samplePoints.first,
        samplePoints[samplePoints.length ~/ 2],
        samplePoints.last,
      ];
    }

    Set<String> seenPlaceIds = {};
    List<Amenity> allAmenities = [];

    for (var point in samplePoints) {
      try {
        final places = await _mapService.searchNearby(
          point.latitude,
          point.longitude,
          type: type,
          radiusMeters: (searchRadiusKm * 1000).round(),
        ).timeout(_timeout, onTimeout: () => <TripLocation>[]);

        for (var place in places) {
          // Deduplicate
          final key = place.placeId ?? '${place.latitude}_${place.longitude}';
          if (seenPlaceIds.contains(key)) continue;
          seenPlaceIds.add(key);

          // Calculate distance from route (use subset of points for speed)
          double minDistance = double.infinity;
          final step = (routePoints.length / 10).ceil().clamp(1, routePoints.length);
          for (int i = 0; i < routePoints.length; i += step) {
            final routePoint = routePoints[i];
            final dist = _haversineDistance(
              place.latitude,
              place.longitude,
              routePoint.latitude,
              routePoint.longitude,
            );
            if (dist < minDistance) minDistance = dist;
          }

          final amenity = Amenity(
            name: place.name,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            type: amenityType,
            rating: place.metadata?['rating']?.toDouble(),
            reviewCount: place.metadata?['user_ratings_total'],
            source: 'osm',
            placeId: place.placeId,
            distanceFromRoute: minDistance,
          );

          allAmenities.add(amenity);
        }

        // Early exit if we have enough results
        if (allAmenities.length >= maxResults) break;
      } catch (e) {
        print('Amenity search failed for point: $e');
        continue;
      }
    }

    // Sort by distance from route
    allAmenities.sort((a, b) => a.distanceFromRoute.compareTo(b.distanceFromRoute));

    return allAmenities.take(maxResults).toList();
  }

  /// Sample points along a route at regular intervals
  List<LatLng> _sampleRoutePoints(List<LatLng> points, {double intervalKm = 50}) {
    if (points.isEmpty) return [];
    if (points.length == 1) return points;

    List<LatLng> sampled = [points.first];
    double accumulatedDistance = 0;

    for (int i = 1; i < points.length; i++) {
      final dist = _haversineDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );

      accumulatedDistance += dist;

      if (accumulatedDistance >= intervalKm) {
        sampled.add(points[i]);
        accumulatedDistance = 0;
      }
    }

    // Always include last point
    if (sampled.last != points.last) {
      sampled.add(points.last);
    }

    return sampled;
  }

  /// Enrich amenity with washroom info from reviews
  Future<Amenity> _enrichAmenityData(Amenity amenity) async {
    // In a real app, this would fetch detailed reviews and analyze them
    // For now, we simulate washroom scoring based on overall rating
    final hasGoodRating = (amenity.rating ?? 0) >= 4.0;
    final reviewCount = amenity.reviewCount ?? 0;

    final washroomInfo = WashroomInfo(
      overallScore: hasGoodRating ? 4.0 : 2.5,
      cleanlinessScore: hasGoodRating ? 4.0 : 2.5,
      femaleReviewScore: hasGoodRating ? 3.8 : 2.0,
      hasFemaleSection: reviewCount > 50, // Assume larger places have female facilities
      hasWesternToilet: reviewCount > 100,
      hasIndianToilet: true,
      totalReviews: reviewCount,
      femaleReviewCount: (reviewCount * 0.3).round(), // Estimate
    );

    return amenity.copyWith(washroomInfo: washroomInfo);
  }

  /// Analyze reviews for washroom quality (mock implementation)
  Future<WashroomInfo> analyzeWashroomReviews(String placeId) async {
    // In production, this would:
    // 1. Fetch reviews from Google Places API
    // 2. Use NLP to analyze mentions of washrooms, cleanliness, etc.
    // 3. Specifically look for female reviewer feedback
    // 4. Return aggregated scores

    // Mock implementation
    return WashroomInfo(
      overallScore: 3.5,
      cleanlinessScore: 3.5,
      femaleReviewScore: 3.2,
      hasFemaleSection: true,
      hasWesternToilet: true,
      hasIndianToilet: true,
      totalReviews: 50,
      femaleReviewCount: 15,
      recentComments: [
        'Clean restrooms',
        'Decent washroom facilities',
      ],
    );
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sin(dLon / 2) * _sin(dLon / 2);

    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) {
    if (x > 0) return _taylorAtan(y / x);
    if (x < 0 && y >= 0) return _taylorAtan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _taylorAtan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _taylorSin(double x) {
    while (x > 3.141592653589793) x -= 6.283185307179586;
    while (x < -3.141592653589793) x += 6.283185307179586;
    double result = x, term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _newtonSqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 15; i++) guess = (guess + x / guess) / 2;
    return guess;
  }

  double _taylorAtan(double x) {
    if (x.abs() <= 1) {
      double result = x, term = x;
      for (int i = 1; i <= 15; i++) {
        term *= -x * x;
        result += term / (2 * i + 1);
      }
      return result;
    }
    return (x > 0 ? 1.5707963267948966 : -1.5707963267948966) - _taylorAtan(1 / x);
  }
}

// Provider
final amenitiesServiceProvider = Provider<AmenitiesService>((ref) {
  return AmenitiesService(ref.watch(unifiedMapServiceProvider));
});

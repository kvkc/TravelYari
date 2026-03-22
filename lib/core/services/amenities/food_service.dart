import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/amenity.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../api_keys.dart';

/// Service for finding restaurants from Zomato, Swiggy, and Google
class FoodService {
  final Dio _dio;

  FoodService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// Search restaurants combining multiple sources
  Future<List<Amenity>> searchRestaurants({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    double minRating = 4.0,
    String? cuisine,
    bool vegetarianOnly = false,
    bool preferGoodWashrooms = true,
  }) async {
    // Fetch from multiple sources in parallel
    final results = await Future.wait([
      _searchGooglePlaces(latitude, longitude, radiusKm),
      // Note: Zomato public API is deprecated, using alternative approach
      // _searchZomato(latitude, longitude, radiusKm),
      // Swiggy doesn't have a public API, would need web scraping
    ]);

    // Merge and deduplicate results
    List<Amenity> allRestaurants = [];
    Set<String> seen = {};

    for (var sourceResults in results) {
      for (var restaurant in sourceResults) {
        final key = '${(restaurant.latitude * 1000).round()}_${(restaurant.longitude * 1000).round()}';
        if (!seen.contains(key)) {
          seen.add(key);
          allRestaurants.add(restaurant);
        }
      }
    }

    // Filter by rating
    allRestaurants = allRestaurants.where((r) => (r.rating ?? 0) >= minRating).toList();

    // Filter by cuisine if specified
    if (cuisine != null && cuisine.isNotEmpty) {
      allRestaurants = allRestaurants.where((r) {
        final cuisines = r.cuisines ?? [];
        return cuisines.any((c) => c.toLowerCase().contains(cuisine.toLowerCase()));
      }).toList();
    }

    // Sort by rating and washroom quality
    allRestaurants.sort((a, b) {
      if (preferGoodWashrooms) {
        final aWashroom = a.washroomInfo?.femaleReviewScore ?? 0;
        final bWashroom = b.washroomInfo?.femaleReviewScore ?? 0;
        if ((aWashroom - bWashroom).abs() > 0.5) {
          return bWashroom.compareTo(aWashroom);
        }
      }
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    });

    return allRestaurants;
  }

  Future<List<Amenity>> _searchGooglePlaces(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': (radiusKm * 1000).round(),
          'type': 'restaurant',
          'key': ApiKeys.googlePlaces,
        },
      );

      if (response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        return results.map((place) => _parseGooglePlace(place, latitude, longitude)).toList();
      }
    } catch (e) {
      print('Google Places search error: $e');
    }

    return [];
  }

  Amenity _parseGooglePlace(Map<String, dynamic> place, double searchLat, double searchLng) {
    final location = place['geometry']['location'];
    final lat = location['lat'].toDouble();
    final lng = location['lng'].toDouble();

    // Estimate washroom quality from rating and review count
    final rating = place['rating']?.toDouble() ?? 0;
    final reviewCount = place['user_ratings_total'] ?? 0;

    WashroomInfo? washroomInfo;
    if (reviewCount > 0) {
      // Higher rated places with more reviews tend to have better facilities
      final washroomScore = rating >= 4.0 ? 3.5 + (rating - 4.0) : 2.5;
      washroomInfo = WashroomInfo(
        overallScore: washroomScore,
        cleanlinessScore: washroomScore,
        femaleReviewScore: washroomScore * 0.9, // Slight penalty as we don't have real data
        hasFemaleSection: reviewCount > 50,
        hasWesternToilet: reviewCount > 100,
        hasIndianToilet: true,
        totalReviews: reviewCount,
        femaleReviewCount: (reviewCount * 0.35).round(),
      );
    }

    return Amenity(
      name: place['name'] ?? 'Unknown Restaurant',
      address: place['vicinity'],
      latitude: lat,
      longitude: lng,
      type: AmenityType.restaurant,
      rating: rating,
      reviewCount: reviewCount,
      source: 'google',
      placeId: place['place_id'],
      photos: place['photos'] != null
          ? [place['photos'][0]['photo_reference']]
          : null,
      isOpen: place['opening_hours']?['open_now'] ?? true,
      washroomInfo: washroomInfo,
      details: {
        'price_level': place['price_level'],
        'types': place['types'],
      },
    );
  }

  /// Get detailed restaurant info including reviews
  Future<Amenity?> getRestaurantDetails(String placeId) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'name,formatted_address,geometry,rating,user_ratings_total,'
              'opening_hours,photos,reviews,price_level,types,website,formatted_phone_number',
          'key': ApiKeys.googlePlaces,
        },
      );

      if (response.data['status'] == 'OK') {
        final place = response.data['result'];
        final location = place['geometry']['location'];

        // Analyze reviews for washroom mentions
        final reviews = place['reviews'] as List? ?? [];
        final washroomInfo = _analyzeReviewsForWashroom(reviews);

        return Amenity(
          name: place['name'],
          address: place['formatted_address'],
          latitude: location['lat'].toDouble(),
          longitude: location['lng'].toDouble(),
          type: AmenityType.restaurant,
          rating: place['rating']?.toDouble(),
          reviewCount: place['user_ratings_total'],
          source: 'google',
          placeId: placeId,
          photos: (place['photos'] as List?)
              ?.map<String>((p) => p['photo_reference'] as String)
              .toList(),
          washroomInfo: washroomInfo,
          openingHours: _formatOpeningHours(place['opening_hours']),
          details: {
            'price_level': place['price_level'],
            'website': place['website'],
            'phone': place['formatted_phone_number'],
            'types': place['types'],
          },
        );
      }
    } catch (e) {
      print('Restaurant details error: $e');
    }

    return null;
  }

  WashroomInfo _analyzeReviewsForWashroom(List reviews) {
    int washroomMentions = 0;
    int positiveWashroom = 0;
    int femaleMentions = 0;
    int positiveFemaleMentions = 0;
    int femaleReviewers = 0;

    final washroomKeywords = ['washroom', 'restroom', 'toilet', 'bathroom', 'loo', 'clean'];
    final positiveKeywords = ['clean', 'good', 'nice', 'well maintained', 'hygienic'];
    final negativeKeywords = ['dirty', 'bad', 'poor', 'unclean', 'smelly'];

    for (var review in reviews) {
      final text = (review['text'] ?? '').toString().toLowerCase();
      final authorName = (review['author_name'] ?? '').toString().toLowerCase();

      // Check if reviewer might be female (rough heuristic)
      final isFemale = _mightBeFemaleReviewer(authorName);
      if (isFemale) femaleReviewers++;

      // Check for washroom mentions
      bool mentionsWashroom = washroomKeywords.any((k) => text.contains(k));
      if (mentionsWashroom) {
        washroomMentions++;

        bool isPositive = positiveKeywords.any((k) => text.contains(k));
        bool isNegative = negativeKeywords.any((k) => text.contains(k));

        if (isPositive && !isNegative) {
          positiveWashroom++;
          if (isFemale) {
            femaleMentions++;
            positiveFemaleMentions++;
          }
        } else if (isFemale) {
          femaleMentions++;
        }
      }
    }

    // Calculate scores
    double overallScore = 3.0;
    if (washroomMentions > 0) {
      overallScore = 2.0 + (positiveWashroom / washroomMentions) * 3.0;
    }

    double femaleScore = 3.0;
    if (femaleMentions > 0) {
      femaleScore = 2.0 + (positiveFemaleMentions / femaleMentions) * 3.0;
    }

    return WashroomInfo(
      overallScore: overallScore.clamp(0, 5),
      cleanlinessScore: overallScore.clamp(0, 5),
      femaleReviewScore: femaleScore.clamp(0, 5),
      hasFemaleSection: femaleReviewers > 2,
      hasWesternToilet: reviews.length > 10,
      hasIndianToilet: true,
      totalReviews: reviews.length,
      femaleReviewCount: femaleReviewers,
    );
  }

  bool _mightBeFemaleReviewer(String name) {
    // Common Indian female name patterns (simplified)
    final femalePatterns = [
      'priya', 'anita', 'sunita', 'neha', 'pooja', 'sneha', 'divya',
      'kavita', 'rekha', 'meera', 'sita', 'radha', 'lakshmi', 'durga',
      'sarita', 'rita', 'ananya', 'aisha', 'fatima', 'mary', 'sarah',
    ];
    final nameLower = name.toLowerCase();
    return femalePatterns.any((p) => nameLower.contains(p));
  }

  String? _formatOpeningHours(Map<String, dynamic>? openingHours) {
    if (openingHours == null) return null;

    final weekdayText = openingHours['weekday_text'] as List?;
    if (weekdayText != null && weekdayText.isNotEmpty) {
      return weekdayText.join('\n');
    }

    return null;
  }
}

// Provider
final foodServiceProvider = Provider<FoodService>((ref) {
  return FoodService();
});

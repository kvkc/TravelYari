import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/trip_planning/models/trip.dart';
import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../../../features/trip_planning/models/day_plan.dart';
import '../../../features/trip_planning/models/amenity.dart';
import '../route/route_optimizer.dart';
import '../amenities/amenities_service.dart';
import '../map/unified_map_service.dart';

class TripPlannerService {
  final RouteOptimizer _routeOptimizer;
  final AmenitiesService _amenitiesService;
  final UnifiedMapService _mapService;

  TripPlannerService({
    required RouteOptimizer routeOptimizer,
    required AmenitiesService amenitiesService,
    required UnifiedMapService mapService,
  })  : _routeOptimizer = routeOptimizer,
        _amenitiesService = amenitiesService,
        _mapService = mapService;

  /// Generate a complete trip plan with optimized route, daily plans, and stops
  Future<Trip> generateTripPlan({
    required Trip trip,
    DateTime? startDate,
  }) async {
    final prefs = trip.preferences;

    // Step 1: Optimize the route order
    final optimizedRoute = await _routeOptimizer.optimizeRoute(
      trip.locations,
      useRoadDistances: true,
    );

    // Step 2: Get detailed route segments
    final routeSegments = await _routeOptimizer.getRouteSegments(optimizedRoute);

    // Step 3: Calculate total distance and duration
    final stats = _routeOptimizer.calculateTripStatistics(routeSegments);

    // Step 4: Generate day plans with breaks and stops
    final dayPlans = await _generateDayPlans(
      routeSegments: routeSegments,
      preferences: prefs,
      startDate: startDate ?? DateTime.now(),
    );

    // Step 5: Find amenities for each segment
    final segmentsWithAmenities = await _addAmenitiesToSegments(
      routeSegments,
      prefs,
    );

    return trip.copyWith(
      optimizedRoute: optimizedRoute,
      routeSegments: segmentsWithAmenities,
      dayPlans: dayPlans,
      totalDistanceKm: stats.totalDistanceKm,
      estimatedDurationMinutes: stats.totalDurationMinutes,
      status: TripStatus.planned,
      startDate: startDate,
    );
  }

  /// Generate day-by-day plans respecting daily distance limits
  Future<List<DayPlan>> _generateDayPlans({
    required List<RouteSegment> routeSegments,
    required TripPreferences preferences,
    required DateTime startDate,
  }) async {
    List<DayPlan> dayPlans = [];
    double accumulatedDistance = 0;
    double distanceSinceLastBreak = 0;
    int dayNumber = 1;
    DateTime currentDate = startDate;

    List<PlannedStop> currentDayStops = [];
    TripLocation? dayStartLocation;
    TripLocation? lastLocation;

    for (int i = 0; i < routeSegments.length; i++) {
      final segment = routeSegments[i];

      // Initialize day start location
      dayStartLocation ??= segment.start;
      lastLocation = segment.start;

      // Check if we need a break
      distanceSinceLastBreak += segment.distanceKm;
      if (distanceSinceLastBreak >= preferences.breakIntervalKm) {
        // Add a break stop
        final breakStop = await _findBreakStop(
          segment.polylinePoints.isNotEmpty
              ? segment.polylinePoints[segment.polylinePoints.length ~/ 2]
              : LatLng(
                  (segment.start.latitude + segment.end.latitude) / 2,
                  (segment.start.longitude + segment.end.longitude) / 2,
                ),
          StopType.teaBreak,
          preferences,
        );

        if (breakStop != null) {
          currentDayStops.add(breakStop.copyWith(
            distanceFromPreviousKm: distanceSinceLastBreak,
          ));
        }

        distanceSinceLastBreak = 0;
      }

      // Check if adding this segment exceeds daily limit
      if (accumulatedDistance + segment.distanceKm > preferences.maxDailyDistanceKm) {
        // End the current day
        if (currentDayStops.isNotEmpty || dayStartLocation != null) {
          // Find stay option for overnight
          Amenity? stayOption;
          if (preferences.findStayOptions) {
            stayOption = await _findStayOption(
              lastLocation!,
              preferences,
            );
          }

          dayPlans.add(DayPlan(
            dayNumber: dayNumber,
            date: currentDate,
            startLocation: dayStartLocation!,
            endLocation: lastLocation!,
            totalDistanceKm: accumulatedDistance,
            totalDurationMinutes: _estimateDuration(accumulatedDistance),
            stops: currentDayStops,
            stayOption: stayOption,
          ));

          // Start new day
          dayNumber++;
          currentDate = currentDate.add(const Duration(days: 1));
          accumulatedDistance = 0;
          distanceSinceLastBreak = 0;
          currentDayStops = [];
          dayStartLocation = segment.start;
        }
      }

      // Add destination as a stop
      currentDayStops.add(PlannedStop(
        location: segment.end,
        type: StopType.destination,
        plannedDurationMinutes: 30, // Default visit time
        distanceFromPreviousKm: segment.distanceKm,
      ));

      accumulatedDistance += segment.distanceKm;
      lastLocation = segment.end;
    }

    // Add final day
    if (currentDayStops.isNotEmpty && dayStartLocation != null && lastLocation != null) {
      dayPlans.add(DayPlan(
        dayNumber: dayNumber,
        date: currentDate,
        startLocation: dayStartLocation,
        endLocation: lastLocation,
        totalDistanceKm: accumulatedDistance,
        totalDurationMinutes: _estimateDuration(accumulatedDistance),
        stops: currentDayStops,
      ));
    }

    return dayPlans;
  }

  /// Find a suitable break stop (tea/coffee stall)
  Future<PlannedStop?> _findBreakStop(
    LatLng location,
    StopType type,
    TripPreferences preferences,
  ) async {
    try {
      final teaStalls = await _amenitiesService.findTeaStalls(
        routePoints: [location],
        searchRadiusKm: 2.0,
        maxResults: 5,
      );

      if (teaStalls.isNotEmpty) {
        // Prefer places with good washroom facilities
        Amenity? selected;
        if (preferences.preferGoodWashrooms) {
          selected = teaStalls.firstWhere(
            (a) => a.hasGoodWashroom,
            orElse: () => teaStalls.first,
          );
        } else {
          selected = teaStalls.first;
        }

        return PlannedStop(
          location: TripLocation(
            name: selected.name,
            address: selected.address,
            latitude: selected.latitude,
            longitude: selected.longitude,
            source: LocationSource.googleMaps,
          ),
          amenity: selected,
          type: type,
          plannedDurationMinutes: preferences.breakDurationMinutes,
        );
      }
    } catch (e) {
      print('Error finding break stop: $e');
    }

    return null;
  }

  /// Find a suitable stay option
  Future<Amenity?> _findStayOption(
    TripLocation location,
    TripPreferences preferences,
  ) async {
    try {
      final stayOptions = await _amenitiesService.findStayOptions(
        location: LatLng(location.latitude, location.longitude),
        minRating: preferences.minHotelRating,
        searchRadiusKm: 15.0,
        maxResults: 5,
        preferGoodWashrooms: preferences.preferGoodWashrooms,
      );

      if (stayOptions.isNotEmpty) {
        // Return the best option (already sorted by rating and washroom quality)
        return stayOptions.first;
      }
    } catch (e) {
      print('Error finding stay option: $e');
    }

    return null;
  }

  /// Add amenity suggestions to route segments
  Future<List<RouteSegment>> _addAmenitiesToSegments(
    List<RouteSegment> segments,
    TripPreferences preferences,
  ) async {
    List<RouteSegment> enrichedSegments = [];

    for (var segment in segments) {
      List<Amenity> suggestedStops = [];

      if (segment.polylinePoints.isEmpty) {
        enrichedSegments.add(segment);
        continue;
      }

      // Find petrol stations
      if (preferences.findPetrolStations) {
        final petrolStations = await _amenitiesService.findPetrolStations(
          routePoints: segment.polylinePoints,
          maxResults: 3,
        );
        suggestedStops.addAll(petrolStations);
      }

      // Find EV stations
      if (preferences.findEvStations) {
        final evStations = await _amenitiesService.findEvStations(
          routePoints: segment.polylinePoints,
          maxResults: 3,
        );
        suggestedStops.addAll(evStations);
      }

      // Find restaurants
      if (preferences.findRestaurants) {
        final restaurants = await _amenitiesService.findRestaurants(
          routePoints: segment.polylinePoints,
          minRating: preferences.minRestaurantRating,
          preferGoodWashrooms: preferences.preferGoodWashrooms,
          maxResults: 3,
        );
        suggestedStops.addAll(restaurants);
      }

      enrichedSegments.add(segment.copyWith(
        suggestedStops: suggestedStops,
      ));
    }

    return enrichedSegments;
  }

  int _estimateDuration(double distanceKm) {
    // Assume average speed of 50 km/h including breaks
    return (distanceKm / 50 * 60).round();
  }

  /// Suggest meal stops for a day plan
  Future<List<Amenity>> suggestMealStops(
    DayPlan dayPlan,
    TripPreferences preferences,
  ) async {
    List<Amenity> mealStops = [];

    // Find lunch spot (around midday distance)
    if (dayPlan.totalDistanceKm > 100) {
      final midPoint = LatLng(
        (dayPlan.startLocation.latitude + dayPlan.endLocation.latitude) / 2,
        (dayPlan.startLocation.longitude + dayPlan.endLocation.longitude) / 2,
      );

      final restaurants = await _amenitiesService.findRestaurants(
        routePoints: [midPoint],
        minRating: preferences.minRestaurantRating,
        preferGoodWashrooms: preferences.preferGoodWashrooms,
        maxResults: 5,
      );

      mealStops.addAll(restaurants);
    }

    return mealStops;
  }

  /// Re-plan a specific day with updated preferences
  Future<DayPlan> replanDay(
    DayPlan currentPlan,
    TripPreferences preferences,
  ) async {
    // Get fresh amenity suggestions
    final restaurants = await _amenitiesService.findRestaurants(
      routePoints: [
        LatLng(currentPlan.startLocation.latitude, currentPlan.startLocation.longitude),
        LatLng(currentPlan.endLocation.latitude, currentPlan.endLocation.longitude),
      ],
      minRating: preferences.minRestaurantRating,
      preferGoodWashrooms: preferences.preferGoodWashrooms,
    );

    // Find new stay option if needed
    Amenity? stayOption;
    if (preferences.findStayOptions && currentPlan.totalDistanceKm > 300) {
      stayOption = await _findStayOption(
        currentPlan.endLocation,
        preferences,
      );
    }

    // Update stops with meal recommendations
    List<PlannedStop> updatedStops = List.from(currentPlan.stops);

    // Add lunch stop if driving more than 150km
    if (currentPlan.totalDistanceKm > 150 && restaurants.isNotEmpty) {
      final lunchStop = PlannedStop(
        location: TripLocation(
          name: restaurants.first.name,
          address: restaurants.first.address,
          latitude: restaurants.first.latitude,
          longitude: restaurants.first.longitude,
          source: LocationSource.googleMaps,
        ),
        amenity: restaurants.first,
        type: StopType.mealBreak,
        plannedDurationMinutes: 45,
        distanceFromPreviousKm: currentPlan.totalDistanceKm / 2,
      );

      // Insert lunch stop in the middle
      final middleIndex = updatedStops.length ~/ 2;
      updatedStops.insert(middleIndex, lunchStop);
    }

    return currentPlan.copyWith(
      stops: updatedStops,
      stayOption: stayOption,
    );
  }
}

// Provider
final tripPlannerServiceProvider = Provider<TripPlannerService>((ref) {
  return TripPlannerService(
    routeOptimizer: RouteOptimizer(ref.watch(unifiedMapServiceProvider)),
    amenitiesService: ref.watch(amenitiesServiceProvider),
    mapService: ref.watch(unifiedMapServiceProvider),
  );
});

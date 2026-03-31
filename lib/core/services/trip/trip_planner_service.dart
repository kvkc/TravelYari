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

  /// Max time for the entire planning operation
  static const Duration _planningTimeout = Duration(seconds: 60);

  /// Generate a complete trip plan with optimized route, daily plans, and stops
  /// Has a timeout to prevent hanging
  Future<Trip> generateTripPlan({
    required Trip trip,
    DateTime? startDate,
  }) async {
    try {
      return await _doGenerateTripPlan(trip: trip, startDate: startDate)
          .timeout(_planningTimeout, onTimeout: () {
        print('Trip planning timed out, returning basic plan');
        return _generateBasicPlan(trip, startDate);
      });
    } catch (e) {
      print('Trip planning failed: $e');
      return _generateBasicPlan(trip, startDate);
    }
  }

  /// Generate basic plan without amenities when full planning fails/times out
  Trip _generateBasicPlan(Trip trip, DateTime? startDate) {
    // Just return the trip with locations in order
    final segments = <RouteSegment>[];
    for (int i = 0; i < trip.locations.length - 1; i++) {
      segments.add(RouteSegment(
        start: trip.locations[i],
        end: trip.locations[i + 1],
        distanceKm: trip.locations[i].distanceTo(trip.locations[i + 1]),
        durationMinutes: (trip.locations[i].distanceTo(trip.locations[i + 1]) / 50 * 60).round(),
        routeProvider: 'estimated',
      ));
    }

    double totalDistance = segments.fold(0.0, (sum, s) => sum + s.distanceKm);
    int totalDuration = segments.fold(0, (sum, s) => sum + s.durationMinutes);

    return trip.copyWith(
      optimizedRoute: trip.locations,
      routeSegments: segments,
      totalDistanceKm: totalDistance,
      estimatedDurationMinutes: totalDuration,
      status: TripStatus.planned,
      startDate: startDate,
    );
  }

  Future<Trip> _doGenerateTripPlan({
    required Trip trip,
    DateTime? startDate,
  }) async {
    final prefs = trip.preferences;

    // Step 1: Optimize the route order (with timeout)
    final optimizedRoute = await _routeOptimizer.optimizeRoute(
      trip.locations,
      useRoadDistances: true,
    ).timeout(const Duration(seconds: 5), onTimeout: () => List.from(trip.locations));

    // Step 2: Get detailed route segments (with timeout)
    // Use Google Directions if user prefers better routes (and has key configured)
    final routeSegments = await _routeOptimizer.getRouteSegments(
      optimizedRoute,
      preferBetterRoutes: prefs.preferBetterRoutes,
    ).timeout(const Duration(seconds: 10), onTimeout: () => <RouteSegment>[]);

    // If no segments, create basic ones
    final segments = routeSegments.isEmpty
        ? _createBasicSegments(optimizedRoute)
        : routeSegments;

    // Step 3: Calculate total distance and duration
    final stats = _routeOptimizer.calculateTripStatistics(segments);

    // Step 4: Generate day plans (skip amenity-heavy operations if route is short)
    List<DayPlan> dayPlans = [];
    if (trip.locations.length > 1) {
      dayPlans = await _generateDayPlans(
        routeSegments: segments,
        preferences: prefs,
        startDate: startDate ?? DateTime.now(),
      ).timeout(const Duration(seconds: 45), onTimeout: () => <DayPlan>[]);
    }

    // Step 5: Skip amenity search for now (too slow) - just use segments as-is
    // Amenities can be fetched on-demand when viewing the trip

    return trip.copyWith(
      optimizedRoute: optimizedRoute,
      routeSegments: segments,
      dayPlans: dayPlans,
      totalDistanceKm: stats.totalDistanceKm,
      estimatedDurationMinutes: stats.totalDurationMinutes,
      status: TripStatus.planned,
      startDate: startDate,
    );
  }

  List<RouteSegment> _createBasicSegments(List<TripLocation> locations) {
    final segments = <RouteSegment>[];
    for (int i = 0; i < locations.length - 1; i++) {
      segments.add(RouteSegment(
        start: locations[i],
        end: locations[i + 1],
        distanceKm: locations[i].distanceTo(locations[i + 1]),
        durationMinutes: (locations[i].distanceTo(locations[i + 1]) / 50 * 60).round(),
        routeProvider: 'estimated',
      ));
    }
    return segments;
  }

  /// Generate day-by-day plans respecting daily distance limits
  /// Handles long segments by splitting them into multiple days
  Future<List<DayPlan>> _generateDayPlans({
    required List<RouteSegment> routeSegments,
    required TripPreferences preferences,
    required DateTime startDate,
  }) async {
    List<DayPlan> dayPlans = [];
    double accumulatedDistance = 0;
    int dayNumber = 1;
    DateTime currentDate = startDate;

    List<PlannedStop> currentDayStops = [];
    TripLocation? dayStartLocation;
    TripLocation? lastLocation;

    final maxDaily = preferences.maxDailyDistanceKm;

    for (int i = 0; i < routeSegments.length; i++) {
      final segment = routeSegments[i];

      // Initialize day start location
      dayStartLocation ??= segment.start;
      lastLocation ??= segment.start;

      // Check if this single segment exceeds daily limit - need to split it
      if (segment.distanceKm > maxDaily) {
        // First, close out any accumulated distance from previous segments
        if (accumulatedDistance > 0) {
          dayPlans.add(DayPlan(
            dayNumber: dayNumber,
            date: currentDate,
            startLocation: dayStartLocation,
            endLocation: lastLocation,
            totalDistanceKm: accumulatedDistance,
            totalDurationMinutes: _estimateDuration(accumulatedDistance),
            stops: currentDayStops,
          ));
          dayNumber++;
          currentDate = currentDate.add(const Duration(days: 1));
          accumulatedDistance = 0;
          currentDayStops = [];
        }

        // Split this long segment into multiple days
        final daysNeeded = (segment.distanceKm / maxDaily).ceil();
        final distancePerDay = segment.distanceKm / daysNeeded;

        for (int day = 0; day < daysNeeded; day++) {
          final isLastDay = day == daysNeeded - 1;
          final fraction = (day + 1) / daysNeeded;
          final prevFraction = day / daysNeeded;

          // Calculate intermediate point for this day's end
          final dayEndLat = segment.start.latitude +
              (segment.end.latitude - segment.start.latitude) * fraction;
          final dayEndLng = segment.start.longitude +
              (segment.end.longitude - segment.start.longitude) * fraction;

          final dayStartLat = segment.start.latitude +
              (segment.end.latitude - segment.start.latitude) * prevFraction;
          final dayStartLng = segment.start.longitude +
              (segment.end.longitude - segment.start.longitude) * prevFraction;

          // Get actual place names via reverse geocoding
          TripLocation dayStart;
          TripLocation dayEnd;

          if (day == 0) {
            dayStart = segment.start;
          } else {
            // Reverse geocode to get actual city name
            final startLocation = await _mapService.reverseGeocode(dayStartLat, dayStartLng);
            dayStart = startLocation ?? TripLocation(
              name: 'Day $dayNumber Start',
              latitude: dayStartLat,
              longitude: dayStartLng,
              source: LocationSource.openStreetMap,
            );
          }

          if (isLastDay) {
            dayEnd = segment.end;
          } else {
            // Reverse geocode to get actual city/town name for overnight stop
            final endLocation = await _mapService.reverseGeocode(dayEndLat, dayEndLng);
            final kmFromStart = (distancePerDay * (day + 1)).round();
            dayEnd = endLocation ?? TripLocation(
              name: 'Night Halt (~${kmFromStart}km)',
              latitude: dayEndLat,
              longitude: dayEndLng,
              source: LocationSource.openStreetMap,
            );
          }

          final stops = <PlannedStop>[];

          // Add break stops based on distance (every breakIntervalKm)
          final breakInterval = preferences.breakIntervalKm;
          int numBreaks = (distancePerDay / breakInterval).floor();
          if (numBreaks > 0) {
            // Estimate start time for the day (default 8 AM if no specific time)
            final dayStartTime = DateTime(currentDate.year, currentDate.month, currentDate.day, 8, 0);
            final avgSpeed = 50.0; // km/h average

            for (int b = 1; b <= numBreaks && b <= 3; b++) {
              final breakFraction = prevFraction + (fraction - prevFraction) * (b / (numBreaks + 1));
              final breakLat = segment.start.latitude +
                  (segment.end.latitude - segment.start.latitude) * breakFraction;
              final breakLng = segment.start.longitude +
                  (segment.end.longitude - segment.start.longitude) * breakFraction;

              // Calculate distance covered to this break
              final distanceToBreak = distancePerDay * (b / (numBreaks + 1));
              final estimatedArrival = _estimateArrivalTime(dayStartTime, distanceToBreak, avgSpeed);
              final isMealBreak = _isMealTime(estimatedArrival);
              final breakType = _determineBreakType(estimatedArrival, preferences.breakDurationMinutes);
              final breakDuration = isMealBreak ? 45 : preferences.breakDurationMinutes;

              stops.add(PlannedStop(
                location: TripLocation(
                  name: isMealBreak ? 'Meal Break ${b}' : 'Tea/Rest Break ${b}',
                  latitude: breakLat,
                  longitude: breakLng,
                  source: LocationSource.openStreetMap,
                ),
                type: breakType,
                plannedDurationMinutes: breakDuration,
                distanceFromPreviousKm: breakInterval,
                estimatedArrival: estimatedArrival,
              ));
            }
          }

          // Add fuel stop if needed (roughly every 300km)
          if (distancePerDay > 250 && (preferences.findPetrolStations || preferences.findEvStations)) {
            final fuelFraction = prevFraction + (fraction - prevFraction) * 0.6;
            final fuelLat = segment.start.latitude +
                (segment.end.latitude - segment.start.latitude) * fuelFraction;
            final fuelLng = segment.start.longitude +
                (segment.end.longitude - segment.start.longitude) * fuelFraction;

            stops.add(PlannedStop(
              location: TripLocation(
                name: preferences.findEvStations ? 'EV Charging Stop' : 'Fuel Stop',
                latitude: fuelLat,
                longitude: fuelLng,
                source: LocationSource.openStreetMap,
              ),
              type: StopType.fuelStop,
              plannedDurationMinutes: preferences.findEvStations ? 30 : 15,
              distanceFromPreviousKm: distancePerDay * 0.6,
            ));
          }

          // Add destination stop only on last day of this segment
          if (isLastDay) {
            stops.add(PlannedStop(
              location: segment.end,
              type: StopType.destination,
              plannedDurationMinutes: 30,
              distanceFromPreviousKm: distancePerDay,
            ));
          } else {
            // Find hotel/stay option for overnight
            Amenity? stayAmenity;
            if (preferences.findStayOptions) {
              stayAmenity = await _findStayOption(dayEnd, preferences);
            }

            // Add overnight stop with hotel info
            stops.add(PlannedStop(
              location: stayAmenity != null
                  ? TripLocation(
                      name: stayAmenity.name,
                      address: stayAmenity.address,
                      latitude: stayAmenity.latitude,
                      longitude: stayAmenity.longitude,
                      source: LocationSource.openStreetMap,
                    )
                  : dayEnd,
              amenity: stayAmenity,
              type: StopType.overnight,
              plannedDurationMinutes: 480, // 8 hours rest
              distanceFromPreviousKm: distancePerDay,
            ));
          }

          // Get stayOption for the DayPlan
          Amenity? dayStayOption;
          if (!isLastDay && preferences.findStayOptions) {
            dayStayOption = await _findStayOption(dayEnd, preferences);
          }

          dayPlans.add(DayPlan(
            dayNumber: dayNumber,
            date: currentDate,
            startLocation: dayStart,
            endLocation: dayEnd,
            totalDistanceKm: distancePerDay,
            totalDurationMinutes: _estimateDuration(distancePerDay),
            stops: stops,
            stayOption: dayStayOption,
          ));

          dayNumber++;
          currentDate = currentDate.add(const Duration(days: 1));
        }

        // Reset for next segment
        dayStartLocation = segment.end;
        lastLocation = segment.end;
        accumulatedDistance = 0;
        currentDayStops = [];
        continue;
      }

      // Normal case: segment fits within daily limit
      // Check if adding this segment exceeds daily limit
      if (accumulatedDistance + segment.distanceKm > maxDaily && accumulatedDistance > 0) {
        // End the current day before adding this segment
        Amenity? stayOption;
        if (preferences.findStayOptions) {
          stayOption = await _findStayOption(lastLocation!, preferences);
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
        currentDayStops = [];
        dayStartLocation = segment.start;
      }

      // Add break stops based on segment distance
      final breakInterval = preferences.breakIntervalKm;
      if (segment.distanceKm > breakInterval) {
        final numBreaks = (segment.distanceKm / breakInterval).floor();
        // Estimate start time for the day (default 8 AM if no specific time)
        final dayStartTime = DateTime(currentDate.year, currentDate.month, currentDate.day, 8, 0);
        final avgSpeed = 50.0; // km/h average

        for (int b = 1; b <= numBreaks && b <= 2; b++) {
          final breakFraction = b / (numBreaks + 1);
          final breakLat = segment.start.latitude +
              (segment.end.latitude - segment.start.latitude) * breakFraction;
          final breakLng = segment.start.longitude +
              (segment.end.longitude - segment.start.longitude) * breakFraction;

          // Calculate estimated arrival at this break
          final distanceToBreak = accumulatedDistance + (segment.distanceKm * breakFraction);
          final estimatedArrival = _estimateArrivalTime(dayStartTime, distanceToBreak, avgSpeed);
          final isMealBreak = _isMealTime(estimatedArrival);
          final breakType = _determineBreakType(estimatedArrival, preferences.breakDurationMinutes);
          final breakDuration = isMealBreak ? 45 : preferences.breakDurationMinutes;

          currentDayStops.add(PlannedStop(
            location: TripLocation(
              name: isMealBreak ? 'Meal Break' : 'Tea/Rest Break',
              latitude: breakLat,
              longitude: breakLng,
              source: LocationSource.openStreetMap,
            ),
            type: breakType,
            plannedDurationMinutes: breakDuration,
            distanceFromPreviousKm: segment.distanceKm * breakFraction,
            estimatedArrival: estimatedArrival,
          ));
        }
      }

      // Add fuel stop for longer segments
      if (segment.distanceKm > 200 && (preferences.findPetrolStations || preferences.findEvStations)) {
        final fuelLat = segment.start.latitude +
            (segment.end.latitude - segment.start.latitude) * 0.5;
        final fuelLng = segment.start.longitude +
            (segment.end.longitude - segment.start.longitude) * 0.5;

        currentDayStops.add(PlannedStop(
          location: TripLocation(
            name: preferences.findEvStations ? 'EV Charging Stop' : 'Fuel Stop',
            latitude: fuelLat,
            longitude: fuelLng,
            source: LocationSource.openStreetMap,
          ),
          type: StopType.fuelStop,
          plannedDurationMinutes: preferences.findEvStations ? 30 : 15,
          distanceFromPreviousKm: segment.distanceKm * 0.5,
        ));
      }

      // Add destination as a stop
      currentDayStops.add(PlannedStop(
        location: segment.end,
        type: StopType.destination,
        plannedDurationMinutes: 30,
        distanceFromPreviousKm: segment.distanceKm,
      ));

      accumulatedDistance += segment.distanceKm;
      lastLocation = segment.end;
    }

    // Add final day if there's remaining distance
    if (accumulatedDistance > 0 && dayStartLocation != null && lastLocation != null) {
      // Final day - no stayOption needed as we're at destination
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

    // Ensure all non-final days have stayOption (fill in missing ones)
    if (dayPlans.length > 1 && preferences.findStayOptions) {
      for (int i = 0; i < dayPlans.length - 1; i++) {
        if (dayPlans[i].stayOption == null) {
          // Try to find a stay option for this day
          final stayOption = await _findStayOption(dayPlans[i].endLocation, preferences);
          if (stayOption != null) {
            dayPlans[i] = dayPlans[i].copyWith(stayOption: stayOption);
          } else {
            // Create a fallback stay suggestion based on end location
            dayPlans[i] = dayPlans[i].copyWith(
              stayOption: Amenity(
                id: 'suggested_stay_day_${i + 1}',
                name: 'Hotels near ${dayPlans[i].endLocation.name}',
                type: AmenityType.hotel,
                latitude: dayPlans[i].endLocation.latitude,
                longitude: dayPlans[i].endLocation.longitude,
                address: dayPlans[i].endLocation.address ?? 'Search for hotels in this area',
                rating: null,
                source: 'suggestion',
              ),
            );
          }
        }
      }
    }

    return dayPlans;
  }

  /// Find a suitable break stop (tea/coffee stall or restaurant for meals)
  Future<PlannedStop?> _findBreakStop(
    LatLng location,
    StopType type,
    TripPreferences preferences, {
    DateTime? estimatedArrival,
  }) async {
    try {
      final isMealTime = estimatedArrival != null && _isMealTime(estimatedArrival);
      final actualType = isMealTime ? StopType.mealBreak : type;

      final amenity = await _amenitiesService.findBreakStop(
        location: location,
        isMealTime: isMealTime,
        minRating: isMealTime ? preferences.minRestaurantRating : 3.5,
        searchRadiusKm: isMealTime ? 5.0 : 2.0,
        preferGoodWashrooms: preferences.preferGoodWashrooms,
      );

      if (amenity != null) {
        return PlannedStop(
          location: TripLocation(
            name: amenity.name,
            address: amenity.address,
            latitude: amenity.latitude,
            longitude: amenity.longitude,
            source: LocationSource.openStreetMap,
          ),
          amenity: amenity,
          type: actualType,
          plannedDurationMinutes: isMealTime ? 45 : preferences.breakDurationMinutes,
          estimatedArrival: estimatedArrival,
        );
      }

      // Fallback to basic tea stall search
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
            source: LocationSource.openStreetMap,
          ),
          amenity: selected,
          type: actualType,
          plannedDurationMinutes: isMealTime ? 45 : preferences.breakDurationMinutes,
          estimatedArrival: estimatedArrival,
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

  /// Determine if a given time is during typical meal hours
  bool _isMealTime(DateTime time) {
    final hour = time.hour;
    // Lunch: 12:00 PM - 2:00 PM
    // Dinner: 7:00 PM - 9:00 PM
    return (hour >= 12 && hour <= 14) || (hour >= 19 && hour <= 21);
  }

  /// Determine the appropriate break type based on time of day and duration
  StopType _determineBreakType(DateTime estimatedArrival, int durationMinutes) {
    final isMealHours = _isMealTime(estimatedArrival);
    final isLongBreak = durationMinutes >= 30;

    if (isMealHours || isLongBreak) {
      return StopType.mealBreak;
    }
    return StopType.teaBreak;
  }

  /// Calculate estimated arrival time at a stop
  DateTime _estimateArrivalTime(
    DateTime startTime,
    double distanceKm,
    double avgSpeedKmh,
  ) {
    final durationMinutes = (distanceKm / avgSpeedKmh * 60).round();
    return startTime.add(Duration(minutes: durationMinutes));
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

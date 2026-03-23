# Yatra Planner - Complete Build Guide

A comprehensive guide to building a smart road trip planning app with Flutter.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Setup](#project-setup)
4. [Architecture](#architecture)
5. [Core Services](#core-services)
6. [Data Models](#data-models)
7. [Features Implementation](#features-implementation)
8. [API Integration](#api-integration)
9. [Security & API Keys](#security--api-keys)
10. [Build & Release](#build--release)
11. [Cost Optimization](#cost-optimization)

---

## Overview

**Yatra Planner** is a Flutter-based road trip planning app that helps users:
- Plan multi-stop journeys
- Auto-optimize routes using TSP algorithms
- Generate day-by-day itineraries with realistic driving limits
- Find fuel stations, restaurants, and hotels along the route
- Share trips via WhatsApp, Google Maps, etc.

### Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| State Management | Riverpod | Type-safe, testable, compile-time safety |
| Maps | Google + OSM hybrid | Cost optimization |
| Routing | OSRM | Free, no API limits |
| Local Storage | Hive | Fast, no native dependencies |
| Architecture | Feature-first | Scalable, maintainable |

---

## Prerequisites

### Required Software

```bash
# Flutter SDK (3.2.0+)
flutter --version

# Android Studio with:
# - Android SDK
# - Android SDK Command-line Tools
# - Android Emulator

# Java JDK 11+ (for keystore generation)
java -version
```

### Accounts Needed

1. **Google Cloud Console** - For Maps API key
2. **Google Play Console** - For app publishing (optional)
3. **GitHub** - For version control

---

## Project Setup

### 1. Create Flutter Project

```bash
flutter create --org com.yatraplanner yatra_planner
cd yatra_planner
```

### 2. Configure pubspec.yaml

```yaml
name: yatra_planner
description: Smart trip planning app with multi-location support.
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Maps & Location
  google_maps_flutter: ^2.5.3
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  geolocator: ^10.1.0
  geocoding: ^2.1.1
  flutter_polyline_points: ^2.0.0

  # Networking
  dio: ^5.4.0

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.2

  # UI Components
  cupertino_icons: ^1.0.6
  flutter_slidable: ^3.0.1
  shimmer: ^3.0.0

  # Deep Links & Sharing
  share_plus: ^7.2.1
  url_launcher: ^6.2.2

  # Utils
  permission_handler: ^11.1.0
  intl: ^0.19.0
  uuid: ^4.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.8
  riverpod_generator: ^2.3.9
  hive_generator: ^2.0.1

flutter:
  uses-material-design: true
```

### 3. Project Structure

Create the following directory structure:

```
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── router/
│   │   └── app_router.dart
│   ├── services/
│   │   ├── api_keys.dart
│   │   ├── storage_service.dart
│   │   ├── amenities/
│   │   │   └── amenities_service.dart
│   │   ├── map/
│   │   │   ├── map_service_interface.dart
│   │   │   ├── google_maps_service.dart
│   │   │   ├── osm_service.dart
│   │   │   └── unified_map_service.dart
│   │   ├── route/
│   │   │   └── route_optimizer.dart
│   │   ├── share/
│   │   │   └── route_share_service.dart
│   │   └── trip/
│   │       └── trip_planner_service.dart
│   └── theme/
│       └── app_theme.dart
└── features/
    ├── home/
    │   ├── screens/
    │   │   └── home_screen.dart
    │   └── widgets/
    │       ├── trip_card.dart
    │       └── empty_trips_widget.dart
    ├── location_search/
    │   ├── screens/
    │   │   └── location_search_screen.dart
    │   └── widgets/
    │       └── location_result_tile.dart
    ├── trip_planning/
    │   ├── models/
    │   │   ├── trip.dart
    │   │   ├── location.dart
    │   │   ├── day_plan.dart
    │   │   ├── route_segment.dart
    │   │   └── amenity.dart
    │   ├── screens/
    │   │   ├── trip_planning_screen.dart
    │   │   └── route_view_screen.dart
    │   └── widgets/
    │       ├── location_list_item.dart
    │       ├── day_plan_card.dart
    │       ├── route_map_widget.dart
    │       └── trip_preferences_sheet.dart
    └── settings/
        └── screens/
            └── settings_screen.dart
```

---

## Architecture

### Feature-First Architecture

```
feature/
├── models/        # Data classes
├── screens/       # Full-page widgets
├── widgets/       # Reusable UI components
├── providers/     # Riverpod state (optional)
└── services/      # Feature-specific logic (optional)
```

### Dependency Flow

```
UI (Screens/Widgets)
        ↓
   Providers (Riverpod)
        ↓
   Services (Business Logic)
        ↓
   External APIs / Local Storage
```

---

## Core Services

### 1. API Keys Service (Secure Injection)

```dart
// lib/core/services/api_keys.dart

class ApiKeys {
  // Injected at compile time via --dart-define
  static const String googleMaps = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String googlePlaces = googleMaps;

  static bool get hasGoogleMapsKey =>
      googleMaps.isNotEmpty &&
      !googleMaps.startsWith('YOUR_') &&
      googleMaps != 'YOUR_GOOGLE_MAPS_API_KEY';
}
```

### 2. Map Service Interface

```dart
// lib/core/services/map/map_service_interface.dart

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
  final LocationSource source;

  PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
    required this.source,
  });
}

abstract class MapServiceInterface {
  String get providerName;

  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation});
  Future<TripLocation?> getPlaceDetails(String placeId);
  Future<TripLocation?> reverseGeocode(double latitude, double longitude);
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  });
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  );
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
  });
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  });
}
```

### 3. OSM Service (Free)

```dart
// lib/core/services/map/osm_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'map_service_interface.dart';

class OsmService implements MapServiceInterface {
  final Dio _dio;

  static const String _osrmBase = 'https://router.project-osrm.org';
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String _photonBase = 'https://photon.komoot.io';

  // CORS proxy for web (not needed for mobile)
  static String _proxyUrl(String url) {
    if (kIsWeb) {
      return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  OsmService() : _dio = Dio() {
    _dio.options.headers['User-Agent'] = 'YatraPlanner/1.0';
    _dio.options.headers['Accept'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  @override
  String get providerName => 'OpenStreetMap';

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    try {
      var url = '$_photonBase/api/?q=${Uri.encodeComponent(query)}&limit=10';
      if (nearLocation != null) {
        url += '&lat=${nearLocation.latitude}&lon=${nearLocation.longitude}';
      }

      final response = await _dio.get(_proxyUrl(url));
      if (response.statusCode == 200) {
        final features = response.data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          return features.map((f) => _parsePhotonFeature(f)).toList();
        }
      }
    } catch (e) {
      print('Photon search failed: $e');
    }
    return [];
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    try {
      final coords = <String>[
        '${origin.longitude},${origin.latitude}',
        if (waypoints != null)
          ...waypoints.map((w) => '${w.longitude},${w.latitude}'),
        '${destination.longitude},${destination.latitude}',
      ].join(';');

      final url = '$_osrmBase/route/v1/driving/$coords?overview=full&geometries=polyline&steps=true&alternatives=true';
      final response = await _dio.get(_proxyUrl(url));

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

  TripLocation _parsePhotonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final coords = feature['geometry']['coordinates'] as List;

    return TripLocation(
      name: props['name'] ?? props['city'] ?? 'Unknown',
      latitude: (coords[1] as num).toDouble(),
      longitude: (coords[0] as num).toDouble(),
      source: LocationSource.openStreetMap,
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

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

  // ... implement other methods similarly
}
```

### 4. Unified Map Service (Hybrid)

```dart
// lib/core/services/map/unified_map_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_keys.dart';
import 'google_maps_service.dart';
import 'osm_service.dart';

class UnifiedMapService {
  final GoogleMapsService _googleService;
  final OsmService _osmService;

  static bool get hasGoogleKey => ApiKeys.hasGoogleMapsKey;

  UnifiedMapService({
    required GoogleMapsService googleService,
    required OsmService osmService,
  })  : _googleService = googleService,
        _osmService = osmService;

  /// Search - Use Google if key available (better UX), else OSM
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    if (hasGoogleKey) {
      try {
        final results = await _googleService.searchPlaces(query, nearLocation: nearLocation);
        if (results.isNotEmpty) return results;
      } catch (e) {
        print('Google search failed: $e');
      }
    }
    return _osmService.searchPlaces(query, nearLocation: nearLocation);
  }

  /// Directions - ALWAYS use OSRM (FREE!)
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
    bool preferGoogleRouting = false,
  }) async {
    // Use Google only if explicitly requested AND key available
    if (preferGoogleRouting && hasGoogleKey) {
      try {
        final result = await _googleService.getDirections(origin, destination, waypoints: waypoints);
        if (result != null) return result;
      } catch (e) {
        print('Google directions failed: $e');
      }
    }
    return _osmService.getDirections(origin, destination, waypoints: waypoints);
  }

  /// Distance Matrix - ALWAYS use OSRM (FREE!)
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  ) async {
    return _osmService.getDistanceMatrix(origins, destinations);
  }

  /// Reverse Geocode - ALWAYS use OSM (FREE!)
  Future<TripLocation?> reverseGeocode(double lat, double lng) async {
    return _osmService.reverseGeocode(lat, lng);
  }
}

// Riverpod Providers
final osmServiceProvider = Provider<OsmService>((ref) => OsmService());

final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  return GoogleMapsService(apiKey: ApiKeys.googleMaps);
});

final unifiedMapServiceProvider = Provider<UnifiedMapService>((ref) {
  return UnifiedMapService(
    googleService: ref.watch(googleMapsServiceProvider),
    osmService: ref.watch(osmServiceProvider),
  );
});
```

### 5. Route Optimizer (TSP Algorithm)

```dart
// lib/core/services/route/route_optimizer.dart

class RouteOptimizer {
  final UnifiedMapService _mapService;

  RouteOptimizer(this._mapService);

  /// Optimize route using nearest neighbor + 2-opt
  Future<List<TripLocation>> optimizeRoute(
    List<TripLocation> locations, {
    bool useRoadDistances = true,
  }) async {
    if (locations.length <= 2) return List.from(locations);

    // Get distance matrix
    final distanceMatrix = useRoadDistances
        ? await _mapService.getDistanceMatrix(locations, locations)
        : _calculateStraightLineDistances(locations);

    // Nearest neighbor heuristic
    List<int> route = _nearestNeighbor(distanceMatrix, locations.length);

    // 2-opt optimization
    route = _twoOpt(route, distanceMatrix);

    return route.map((i) => locations[i]).toList();
  }

  List<int> _nearestNeighbor(List<List<double>> distances, int n) {
    List<int> route = [0];
    Set<int> visited = {0};

    while (visited.length < n) {
      int current = route.last;
      int? nearest;
      double minDist = double.infinity;

      for (int i = 0; i < n; i++) {
        if (!visited.contains(i) && distances[current][i] < minDist) {
          minDist = distances[current][i];
          nearest = i;
        }
      }

      if (nearest != null) {
        route.add(nearest);
        visited.add(nearest);
      }
    }
    return route;
  }

  List<int> _twoOpt(List<int> route, List<List<double>> distances) {
    bool improved = true;
    List<int> best = List.from(route);

    while (improved) {
      improved = false;
      for (int i = 1; i < best.length - 1; i++) {
        for (int j = i + 1; j < best.length; j++) {
          List<int> newRoute = _twoOptSwap(best, i, j);
          if (_totalDistance(newRoute, distances) < _totalDistance(best, distances)) {
            best = newRoute;
            improved = true;
          }
        }
      }
    }
    return best;
  }

  List<int> _twoOptSwap(List<int> route, int i, int j) {
    return [
      ...route.sublist(0, i),
      ...route.sublist(i, j + 1).reversed,
      ...route.sublist(j + 1),
    ];
  }

  double _totalDistance(List<int> route, List<List<double>> distances) {
    double total = 0;
    for (int i = 0; i < route.length - 1; i++) {
      total += distances[route[i]][route[i + 1]];
    }
    return total;
  }
}
```

### 6. Trip Planner Service (Day Planning)

```dart
// lib/core/services/trip/trip_planner_service.dart

class TripPlannerService {
  final RouteOptimizer _routeOptimizer;
  final AmenitiesService _amenitiesService;
  final UnifiedMapService _mapService;

  Future<Trip> generateTripPlan({
    required Trip trip,
    DateTime? startDate,
  }) async {
    final prefs = trip.preferences;

    // 1. Optimize route order
    final optimizedRoute = await _routeOptimizer.optimizeRoute(trip.locations);

    // 2. Get route segments
    final segments = await _routeOptimizer.getRouteSegments(
      optimizedRoute,
      preferBetterRoutes: prefs.preferBetterRoutes,
    );

    // 3. Generate day plans
    final dayPlans = await _generateDayPlans(
      routeSegments: segments,
      preferences: prefs,
      startDate: startDate ?? DateTime.now(),
    );

    return trip.copyWith(
      optimizedRoute: optimizedRoute,
      routeSegments: segments,
      dayPlans: dayPlans,
      status: TripStatus.planned,
    );
  }

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

    final maxDaily = preferences.maxDailyDistanceKm;

    for (var segment in routeSegments) {
      dayStartLocation ??= segment.start;

      // If single segment exceeds daily limit - split into multiple days
      if (segment.distanceKm > maxDaily) {
        final daysNeeded = (segment.distanceKm / maxDaily).ceil();
        final distancePerDay = segment.distanceKm / daysNeeded;

        for (int day = 0; day < daysNeeded; day++) {
          final isLastDay = day == daysNeeded - 1;
          final fraction = (day + 1) / daysNeeded;

          // Calculate intermediate point
          final dayEndLat = segment.start.latitude +
              (segment.end.latitude - segment.start.latitude) * fraction;
          final dayEndLng = segment.start.longitude +
              (segment.end.longitude - segment.start.longitude) * fraction;

          // Reverse geocode to get place name
          final dayEnd = isLastDay
              ? segment.end
              : await _mapService.reverseGeocode(dayEndLat, dayEndLng) ??
                  TripLocation(name: 'Night Halt', latitude: dayEndLat, longitude: dayEndLng);

          // Add stops (breaks, fuel, overnight)
          final stops = await _generateDayStops(
            distancePerDay,
            segment,
            dayEnd,
            preferences,
            isLastDay: isLastDay,
          );

          // Find hotel for overnight stays
          Amenity? stayOption;
          if (!isLastDay && preferences.findStayOptions) {
            stayOption = await _findStayOption(dayEnd, preferences);
          }

          dayPlans.add(DayPlan(
            dayNumber: dayNumber++,
            date: currentDate,
            startLocation: day == 0 ? segment.start : dayPlans.last.endLocation,
            endLocation: dayEnd,
            totalDistanceKm: distancePerDay,
            stops: stops,
            stayOption: stayOption,
          ));

          currentDate = currentDate.add(const Duration(days: 1));
        }
        continue;
      }

      // Normal case - accumulate distance
      if (accumulatedDistance + segment.distanceKm > maxDaily && accumulatedDistance > 0) {
        // Close current day
        Amenity? stayOption;
        if (preferences.findStayOptions) {
          stayOption = await _findStayOption(currentDayStops.last.location, preferences);
        }

        dayPlans.add(DayPlan(
          dayNumber: dayNumber++,
          date: currentDate,
          startLocation: dayStartLocation!,
          endLocation: currentDayStops.last.location,
          totalDistanceKm: accumulatedDistance,
          stops: currentDayStops,
          stayOption: stayOption,
        ));

        currentDate = currentDate.add(const Duration(days: 1));
        accumulatedDistance = 0;
        currentDayStops = [];
        dayStartLocation = segment.start;
      }

      // Add segment stops
      currentDayStops.add(PlannedStop(
        location: segment.end,
        type: StopType.destination,
        distanceFromPreviousKm: segment.distanceKm,
      ));

      accumulatedDistance += segment.distanceKm;
    }

    // Final day
    if (accumulatedDistance > 0) {
      dayPlans.add(DayPlan(
        dayNumber: dayNumber,
        date: currentDate,
        startLocation: dayStartLocation!,
        endLocation: currentDayStops.last.location,
        totalDistanceKm: accumulatedDistance,
        stops: currentDayStops,
      ));
    }

    return dayPlans;
  }
}
```

---

## Data Models

### Location Model

```dart
// lib/features/trip_planning/models/location.dart

import 'package:uuid/uuid.dart';
import 'dart:math';

enum LocationSource {
  googleMaps,
  openStreetMap,
  manual,
}

class TripLocation {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final LocationSource source;

  TripLocation({
    String? id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.source = LocationSource.manual,
  }) : id = id ?? const Uuid().v4();

  double distanceTo(TripLocation other) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(other.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'placeId': placeId,
    'source': source.name,
  };

  factory TripLocation.fromJson(Map<String, dynamic> json) => TripLocation(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    placeId: json['placeId'],
    source: LocationSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => LocationSource.manual,
    ),
  );
}
```

### Trip Model

```dart
// lib/features/trip_planning/models/trip.dart

enum TripStatus { draft, planned, inProgress, completed }
enum VehicleType { car, bike, ev }

class Trip {
  final String id;
  final String name;
  final List<TripLocation> locations;
  final List<TripLocation> optimizedRoute;
  final List<RouteSegment> routeSegments;
  final List<DayPlan> dayPlans;
  final TripStatus status;
  final VehicleType vehicleType;
  final double totalDistanceKm;
  final int estimatedDurationMinutes;
  final DateTime? startDate;
  final TripPreferences preferences;

  // ... constructor, copyWith, toJson, fromJson
}

class TripPreferences {
  final double maxDailyDistanceKm;
  final double breakIntervalKm;
  final int breakDurationMinutes;
  final bool findPetrolStations;
  final bool findEvStations;
  final bool findRestaurants;
  final bool findStayOptions;
  final double minHotelRating;
  final bool preferGoodWashrooms;
  final bool preferBetterRoutes;

  TripPreferences({
    this.maxDailyDistanceKm = 450,
    this.breakIntervalKm = 125,
    this.breakDurationMinutes = 10,
    this.findPetrolStations = true,
    this.findEvStations = false,
    this.findRestaurants = true,
    this.findStayOptions = true,
    this.minHotelRating = 3.5,
    this.preferGoodWashrooms = true,
    this.preferBetterRoutes = false,
  });
}
```

### Day Plan Model

```dart
// lib/features/trip_planning/models/day_plan.dart

enum StopType {
  destination,
  fuelStop,
  mealBreak,
  teaBreak,
  restStop,
  overnight,
}

class DayPlan {
  final int dayNumber;
  final DateTime date;
  final TripLocation startLocation;
  final TripLocation endLocation;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final List<PlannedStop> stops;
  final Amenity? stayOption;

  // ... constructor, copyWith, toJson, fromJson
}

class PlannedStop {
  final TripLocation location;
  final Amenity? amenity;
  final StopType type;
  final int plannedDurationMinutes;
  final double distanceFromPreviousKm;

  // ... constructor, copyWith, toJson, fromJson
}
```

---

## Features Implementation

### Home Screen

```dart
// lib/features/home/screens/home_screen.dart

class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yatra Planner')),
      body: trips.isEmpty
          ? const EmptyTripsWidget()
          : ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) => TripCard(trip: trips[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewTrip(context),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }
}
```

### Trip Planning Screen

```dart
// lib/features/trip_planning/screens/trip_planning_screen.dart

class TripPlanningScreen extends ConsumerStatefulWidget {
  final Trip trip;

  @override
  ConsumerState<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends ConsumerState<TripPlanningScreen> {
  late Trip _trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showPreferences,
          ),
        ],
      ),
      body: Column(
        children: [
          // Location list with reordering
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _trip.locations.length,
              onReorder: _reorderLocations,
              itemBuilder: (context, index) => LocationListItem(
                key: ValueKey(_trip.locations[index].id),
                location: _trip.locations[index],
                index: index,
                onRemove: () => _removeLocation(index),
              ),
            ),
          ),

          // Add location button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addLocation,
              icon: const Icon(Icons.add_location),
              label: const Text('Add Destination'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _trip.locations.length >= 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _planTrip,
                  child: const Text('Plan Trip'),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _planTrip() async {
    final tripPlanner = ref.read(tripPlannerServiceProvider);
    final plannedTrip = await tripPlanner.generateTripPlan(trip: _trip);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteViewScreen(trip: plannedTrip),
      ),
    );
  }
}
```

---

## API Integration

### Google Maps Service

```dart
// lib/core/services/map/google_maps_service.dart

class GoogleMapsService implements MapServiceInterface {
  final String apiKey;
  final Dio _dio;

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  GoogleMapsService({required this.apiKey}) : _dio = Dio();

  @override
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation}) async {
    final params = {
      'query': query,
      'key': apiKey,
      if (nearLocation != null) 'location': '${nearLocation.latitude},${nearLocation.longitude}',
    };

    final response = await _dio.get('$_baseUrl/place/textsearch/json', queryParameters: params);

    if (response.data['status'] == 'OK') {
      return (response.data['results'] as List)
          .map((p) => TripLocation(
                name: p['name'],
                address: p['formatted_address'],
                latitude: p['geometry']['location']['lat'],
                longitude: p['geometry']['location']['lng'],
                placeId: p['place_id'],
                source: LocationSource.googleMaps,
              ))
          .toList();
    }
    return [];
  }

  @override
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  }) async {
    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': apiKey,
      if (waypoints != null && waypoints.isNotEmpty)
        'waypoints': waypoints.map((w) => '${w.latitude},${w.longitude}').join('|'),
    };

    final response = await _dio.get('$_baseUrl/directions/json', queryParameters: params);

    if (response.data['status'] == 'OK') {
      final route = response.data['routes'][0];
      final leg = route['legs'][0];

      return RouteSegment(
        start: origin,
        end: destination,
        distanceKm: leg['distance']['value'] / 1000,
        durationMinutes: (leg['duration']['value'] / 60).round(),
        polylinePoints: _decodePolyline(route['overview_polyline']['points']),
        routeProvider: 'googleMaps',
      );
    }
    return null;
  }
}
```

---

## Security & API Keys

### 1. Create .env File (gitignored)

```bash
# .env
GOOGLE_MAPS_API_KEY=AIzaSyYOUR_ACTUAL_KEY_HERE
```

### 2. Update .gitignore

```gitignore
# API Keys - NEVER commit!
.env
*.env.local
lib/core/services/api_keys_prod.dart

# Keystores
*.jks
*.keystore
key.properties
```

### 3. Build with Key Injection

```bash
# Debug
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Release
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### 4. Generate Release Keystore

```bash
keytool -genkey -v -keystore yatra-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias yatra
```

### 5. Get SHA-1 Fingerprints (for Google Console)

```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

# Release
keytool -list -v -keystore yatra-release.jks -alias yatra
```

### 6. Configure Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project or select existing
3. Enable APIs:
   - Maps SDK for Android
   - Places API
   - Directions API
   - Geocoding API
4. Create API Key with restrictions:
   - Application: Android apps
   - Package: `com.yatraplanner.app`
   - SHA-1: Your debug and release fingerprints

---

## Build & Release

### Android Configuration

```properties
# android/key.properties
storePassword=your_password
keyPassword=your_password
keyAlias=yatra
storeFile=../yatra-release.jks
```

### Build Commands

```bash
# Debug APK
flutter build apk --debug --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# Release APK
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# App Bundle (Play Store)
flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Build Script (build_release.sh)

```bash
#!/bin/bash
source .env
flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
echo "Build complete: build/app/outputs/bundle/release/app-release.aab"
```

---

## Cost Optimization

### API Cost Comparison

| Service | Google Price | Our Approach | Cost |
|---------|-------------|--------------|------|
| Place Search | $17/1000 | Google (better UX) | $17/1000 |
| Autocomplete | $2.83/1000 | Google (better UX) | $2.83/1000 |
| Directions | $5/1000 | OSRM (free) | $0 |
| Distance Matrix | $5/1000 elements | OSRM (free) | $0 |
| Nearby Search | $32/1000 | OSM (free) | $0 |
| Reverse Geocode | $5/1000 | OSM (free) | $0 |

### Monthly Cost Estimate (100 users/day)

**Without optimization:** ~$500-800/month
**With hybrid approach:** ~$25-50/month

### Key Savings

1. **Routing via OSRM** - Saves $5/1000 requests (biggest saver)
2. **Distance Matrix via OSRM** - A 10-stop trip = 100 elements = $0.50 saved per trip
3. **Nearby Search via OSM** - Saves $32/1000 requests
4. **Reverse Geocoding via OSM** - Saves $5/1000 requests

---

## Testing

### Run on Android Emulator

```bash
flutter run -d android --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Run on Physical Device

```bash
flutter run -d YOUR_DEVICE_ID --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Web (has CORS limitations)

```bash
flutter run -d chrome --web-port=5000 --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Note: Web will show CORS errors for API calls. Use Android for full testing.

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| CORS errors on web | Expected - test on Android instead |
| API key not working | Check Google Console restrictions match your SHA-1 |
| Route deviations | OSRM optimizes for speed, not distance. Enable `preferBetterRoutes` for Google Directions |
| Hotel search returns empty | OSM coverage varies. Fallback suggestions are shown |
| Build fails | Run `flutter clean && flutter pub get` |

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [OSRM API](http://project-osrm.org/docs/v5.24.0/api/)
- [Nominatim API](https://nominatim.org/release-docs/develop/api/Overview/)
- [Google Maps Platform](https://developers.google.com/maps/documentation)

---

## License

This project is for educational purposes. Modify and use as needed.

---

*Generated for Yatra Planner v1.0.0*

import 'dart:math';

import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';
import '../map/unified_map_service.dart';

/// Route optimization service using TSP algorithms
class RouteOptimizer {
  final UnifiedMapService _mapService;

  RouteOptimizer(this._mapService);

  /// Optimize the route for a list of locations
  /// Uses a combination of nearest neighbor and 2-opt optimization
  Future<List<TripLocation>> optimizeRoute(
    List<TripLocation> locations, {
    TripLocation? startLocation,
    TripLocation? endLocation,
    bool useRoadDistances = true,
  }) async {
    if (locations.length <= 2) {
      return List.from(locations);
    }

    // Get distance matrix
    List<List<double>> distanceMatrix;
    if (useRoadDistances) {
      distanceMatrix = await _mapService.getDistanceMatrix(locations, locations);
    } else {
      distanceMatrix = _calculateStraightLineDistances(locations);
    }

    // Create working list of indices
    List<int> indices = List.generate(locations.length, (i) => i);

    // Handle fixed start/end
    int? fixedStart;
    int? fixedEnd;

    if (startLocation != null) {
      fixedStart = locations.indexWhere((l) => l.id == startLocation.id);
    }
    if (endLocation != null) {
      fixedEnd = locations.indexWhere((l) => l.id == endLocation.id);
    }

    // Initial solution using nearest neighbor
    List<int> route = _nearestNeighbor(
      distanceMatrix,
      indices,
      startIndex: fixedStart ?? 0,
    );

    // Optimize using 2-opt
    route = _twoOpt(route, distanceMatrix, fixedStart: fixedStart, fixedEnd: fixedEnd);

    // If we have a fixed end, ensure the route ends there
    if (fixedEnd != null && route.last != fixedEnd) {
      route.remove(fixedEnd);
      route.add(fixedEnd);
    }

    // Convert indices back to locations
    return route.map((i) => locations[i]).toList();
  }

  /// Calculate straight-line distances between all locations
  List<List<double>> _calculateStraightLineDistances(List<TripLocation> locations) {
    return locations.map((origin) {
      return locations.map((dest) => origin.distanceTo(dest)).toList();
    }).toList();
  }

  /// Nearest neighbor heuristic for initial TSP solution
  List<int> _nearestNeighbor(
    List<List<double>> distances,
    List<int> indices, {
    int startIndex = 0,
  }) {
    List<int> route = [startIndex];
    Set<int> visited = {startIndex};

    while (visited.length < indices.length) {
      int current = route.last;
      int? nearest;
      double minDistance = double.infinity;

      for (int i in indices) {
        if (!visited.contains(i)) {
          double dist = distances[current][i];
          if (dist < minDistance) {
            minDistance = dist;
            nearest = i;
          }
        }
      }

      if (nearest != null) {
        route.add(nearest);
        visited.add(nearest);
      }
    }

    return route;
  }

  /// 2-opt optimization to improve the route
  List<int> _twoOpt(
    List<int> route,
    List<List<double>> distances, {
    int? fixedStart,
    int? fixedEnd,
  }) {
    bool improved = true;
    List<int> bestRoute = List.from(route);
    double bestDistance = _calculateTotalDistance(bestRoute, distances);

    while (improved) {
      improved = false;

      for (int i = 1; i < bestRoute.length - 1; i++) {
        // Don't swap fixed positions
        if (fixedStart != null && i == 0) continue;
        if (fixedEnd != null && i == bestRoute.length - 1) continue;

        for (int j = i + 1; j < bestRoute.length; j++) {
          if (fixedEnd != null && j == bestRoute.length - 1) continue;

          // Try reversing the segment between i and j
          List<int> newRoute = _twoOptSwap(bestRoute, i, j);
          double newDistance = _calculateTotalDistance(newRoute, distances);

          if (newDistance < bestDistance) {
            bestRoute = newRoute;
            bestDistance = newDistance;
            improved = true;
          }
        }
      }
    }

    return bestRoute;
  }

  /// Perform a 2-opt swap
  List<int> _twoOptSwap(List<int> route, int i, int j) {
    List<int> newRoute = [];

    // Take route[0] to route[i-1] and add them in order
    for (int k = 0; k < i; k++) {
      newRoute.add(route[k]);
    }

    // Take route[i] to route[j] and add them in reverse order
    for (int k = j; k >= i; k--) {
      newRoute.add(route[k]);
    }

    // Take route[j+1] to end and add them in order
    for (int k = j + 1; k < route.length; k++) {
      newRoute.add(route[k]);
    }

    return newRoute;
  }

  /// Calculate total distance of a route
  double _calculateTotalDistance(List<int> route, List<List<double>> distances) {
    double total = 0;
    for (int i = 0; i < route.length - 1; i++) {
      total += distances[route[i]][route[i + 1]];
    }
    return total;
  }

  /// Get detailed route segments with directions
  /// Set preferBetterRoutes=true to use Google Directions for better routes (costs money)
  Future<List<RouteSegment>> getRouteSegments(
    List<TripLocation> optimizedRoute, {
    bool preferBetterRoutes = false,
  }) async {
    List<RouteSegment> segments = [];

    for (int i = 0; i < optimizedRoute.length - 1; i++) {
      final segment = await _mapService.getDirections(
        optimizedRoute[i],
        optimizedRoute[i + 1],
        preferGoogleRouting: preferBetterRoutes,
      );

      if (segment != null) {
        segments.add(segment);
      } else {
        // Fallback to straight-line segment
        segments.add(RouteSegment(
          start: optimizedRoute[i],
          end: optimizedRoute[i + 1],
          distanceKm: optimizedRoute[i].distanceTo(optimizedRoute[i + 1]),
          durationMinutes: (optimizedRoute[i].distanceTo(optimizedRoute[i + 1]) / 60 * 60).round(),
          routeProvider: 'estimated',
        ));
      }
    }

    return segments;
  }

  /// Calculate total trip statistics
  TripStatistics calculateTripStatistics(List<RouteSegment> segments) {
    double totalDistance = 0;
    int totalDuration = 0;

    for (var segment in segments) {
      totalDistance += segment.distanceKm;
      totalDuration += segment.durationMinutes;
    }

    // Estimate days based on max daily driving
    const maxDailyKm = 450.0;
    int estimatedDays = (totalDistance / maxDailyKm).ceil();
    if (estimatedDays == 0) estimatedDays = 1;

    // Estimate number of breaks needed
    const breakIntervalKm = 125.0;
    int estimatedBreaks = (totalDistance / breakIntervalKm).floor();

    return TripStatistics(
      totalDistanceKm: totalDistance,
      totalDurationMinutes: totalDuration,
      estimatedDays: estimatedDays,
      estimatedBreaks: estimatedBreaks,
      numberOfSegments: segments.length,
    );
  }
}

class TripStatistics {
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final int estimatedDays;
  final int estimatedBreaks;
  final int numberOfSegments;

  TripStatistics({
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.estimatedDays,
    required this.estimatedBreaks,
    required this.numberOfSegments,
  });

  String get formattedDistance {
    if (totalDistanceKm >= 1000) {
      return '${(totalDistanceKm / 1000).toStringAsFixed(1)}k km';
    }
    return '${totalDistanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final hours = totalDurationMinutes ~/ 60;
    final minutes = totalDurationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedDays {
    if (estimatedDays == 1) return '1 day';
    return '$estimatedDays days';
  }
}

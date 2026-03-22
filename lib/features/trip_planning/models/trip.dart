import 'package:uuid/uuid.dart';
import 'location.dart';
import 'route_segment.dart';
import 'day_plan.dart';

enum TripStatus {
  draft,
  planned,
  inProgress,
  completed,
}

enum VehicleType {
  car,
  bike,
  ev,
}

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
  final DateTime createdAt;
  final DateTime updatedAt;
  final TripPreferences preferences;

  Trip({
    String? id,
    required this.name,
    List<TripLocation>? locations,
    List<TripLocation>? optimizedRoute,
    List<RouteSegment>? routeSegments,
    List<DayPlan>? dayPlans,
    this.status = TripStatus.draft,
    this.vehicleType = VehicleType.car,
    this.totalDistanceKm = 0,
    this.estimatedDurationMinutes = 0,
    this.startDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    TripPreferences? preferences,
  })  : id = id ?? const Uuid().v4(),
        locations = locations ?? [],
        optimizedRoute = optimizedRoute ?? [],
        routeSegments = routeSegments ?? [],
        dayPlans = dayPlans ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        preferences = preferences ?? TripPreferences();

  Trip copyWith({
    String? name,
    List<TripLocation>? locations,
    List<TripLocation>? optimizedRoute,
    List<RouteSegment>? routeSegments,
    List<DayPlan>? dayPlans,
    TripStatus? status,
    VehicleType? vehicleType,
    double? totalDistanceKm,
    int? estimatedDurationMinutes,
    DateTime? startDate,
    TripPreferences? preferences,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      locations: locations ?? this.locations,
      optimizedRoute: optimizedRoute ?? this.optimizedRoute,
      routeSegments: routeSegments ?? this.routeSegments,
      dayPlans: dayPlans ?? this.dayPlans,
      status: status ?? this.status,
      vehicleType: vehicleType ?? this.vehicleType,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'locations': locations.map((l) => l.toJson()).toList(),
      'optimizedRoute': optimizedRoute.map((l) => l.toJson()).toList(),
      'routeSegments': routeSegments.map((r) => r.toJson()).toList(),
      'dayPlans': dayPlans.map((d) => d.toJson()).toList(),
      'status': status.name,
      'vehicleType': vehicleType.name,
      'totalDistanceKm': totalDistanceKm,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'startDate': startDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': preferences.toJson(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      name: json['name'],
      locations: (json['locations'] as List?)
              ?.map((l) => TripLocation.fromJson(Map<String, dynamic>.from(l)))
              .toList() ??
          [],
      optimizedRoute: (json['optimizedRoute'] as List?)
              ?.map((l) => TripLocation.fromJson(Map<String, dynamic>.from(l)))
              .toList() ??
          [],
      routeSegments: (json['routeSegments'] as List?)
              ?.map((r) => RouteSegment.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          [],
      dayPlans: (json['dayPlans'] as List?)
              ?.map((d) => DayPlan.fromJson(Map<String, dynamic>.from(d)))
              .toList() ??
          [],
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.draft,
      ),
      vehicleType: VehicleType.values.firstWhere(
        (e) => e.name == json['vehicleType'],
        orElse: () => VehicleType.car,
      ),
      totalDistanceKm: (json['totalDistanceKm'] ?? 0).toDouble(),
      estimatedDurationMinutes: json['estimatedDurationMinutes'] ?? 0,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      preferences: json['preferences'] != null
          ? TripPreferences.fromJson(Map<String, dynamic>.from(json['preferences']))
          : TripPreferences(),
    );
  }
}

class TripPreferences {
  final double maxDailyDistanceKm;
  final double breakIntervalKm;
  final int breakDurationMinutes;
  final bool findPetrolStations;
  final bool findEvStations;
  final bool findRestaurants;
  final double minRestaurantRating;
  final bool preferGoodWashrooms;
  final bool findStayOptions;
  final double minHotelRating;

  TripPreferences({
    this.maxDailyDistanceKm = 450,
    this.breakIntervalKm = 125,
    this.breakDurationMinutes = 10,
    this.findPetrolStations = true,
    this.findEvStations = false,
    this.findRestaurants = true,
    this.minRestaurantRating = 4.0,
    this.preferGoodWashrooms = true,
    this.findStayOptions = true,
    this.minHotelRating = 3.5,
  });

  TripPreferences copyWith({
    double? maxDailyDistanceKm,
    double? breakIntervalKm,
    int? breakDurationMinutes,
    bool? findPetrolStations,
    bool? findEvStations,
    bool? findRestaurants,
    double? minRestaurantRating,
    bool? preferGoodWashrooms,
    bool? findStayOptions,
    double? minHotelRating,
  }) {
    return TripPreferences(
      maxDailyDistanceKm: maxDailyDistanceKm ?? this.maxDailyDistanceKm,
      breakIntervalKm: breakIntervalKm ?? this.breakIntervalKm,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      findPetrolStations: findPetrolStations ?? this.findPetrolStations,
      findEvStations: findEvStations ?? this.findEvStations,
      findRestaurants: findRestaurants ?? this.findRestaurants,
      minRestaurantRating: minRestaurantRating ?? this.minRestaurantRating,
      preferGoodWashrooms: preferGoodWashrooms ?? this.preferGoodWashrooms,
      findStayOptions: findStayOptions ?? this.findStayOptions,
      minHotelRating: minHotelRating ?? this.minHotelRating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxDailyDistanceKm': maxDailyDistanceKm,
      'breakIntervalKm': breakIntervalKm,
      'breakDurationMinutes': breakDurationMinutes,
      'findPetrolStations': findPetrolStations,
      'findEvStations': findEvStations,
      'findRestaurants': findRestaurants,
      'minRestaurantRating': minRestaurantRating,
      'preferGoodWashrooms': preferGoodWashrooms,
      'findStayOptions': findStayOptions,
      'minHotelRating': minHotelRating,
    };
  }

  factory TripPreferences.fromJson(Map<String, dynamic> json) {
    return TripPreferences(
      maxDailyDistanceKm: (json['maxDailyDistanceKm'] ?? 450).toDouble(),
      breakIntervalKm: (json['breakIntervalKm'] ?? 125).toDouble(),
      breakDurationMinutes: json['breakDurationMinutes'] ?? 10,
      findPetrolStations: json['findPetrolStations'] ?? true,
      findEvStations: json['findEvStations'] ?? false,
      findRestaurants: json['findRestaurants'] ?? true,
      minRestaurantRating: (json['minRestaurantRating'] ?? 4.0).toDouble(),
      preferGoodWashrooms: json['preferGoodWashrooms'] ?? true,
      findStayOptions: json['findStayOptions'] ?? true,
      minHotelRating: (json['minHotelRating'] ?? 3.5).toDouble(),
    );
  }
}

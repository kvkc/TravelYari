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

enum ParticipantRole {
  owner,
  editor,
  viewer,
}

class TripParticipant {
  final String id;
  final String? userId;
  final String? name;
  final String? phone;
  final String? email;
  final ParticipantRole role;
  final DateTime joinedAt;

  TripParticipant({
    required this.id,
    this.userId,
    this.name,
    this.phone,
    this.email,
    this.role = ParticipantRole.editor,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  TripParticipant copyWith({
    String? userId,
    String? name,
    String? phone,
    String? email,
    ParticipantRole? role,
  }) {
    return TripParticipant(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAt: joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory TripParticipant.fromJson(Map<String, dynamic> json) {
    return TripParticipant(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      role: ParticipantRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => ParticipantRole.editor,
      ),
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }
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
  // Collaboration fields
  final String? ownerId;
  final List<TripParticipant> participants;
  final List<String> participantIds;
  final String? shareCode;
  final bool isShared;
  final DateTime? lastSyncedAt;
  final String? lastModifiedBy;

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
    this.ownerId,
    List<TripParticipant>? participants,
    List<String>? participantIds,
    this.shareCode,
    this.isShared = false,
    this.lastSyncedAt,
    this.lastModifiedBy,
  })  : id = id ?? const Uuid().v4(),
        locations = locations ?? [],
        optimizedRoute = optimizedRoute ?? [],
        routeSegments = routeSegments ?? [],
        dayPlans = dayPlans ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        preferences = preferences ?? TripPreferences(),
        participants = participants ?? [],
        participantIds = participantIds ?? [];

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
    String? ownerId,
    List<TripParticipant>? participants,
    List<String>? participantIds,
    String? shareCode,
    bool? isShared,
    DateTime? lastSyncedAt,
    String? lastModifiedBy,
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
      ownerId: ownerId ?? this.ownerId,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      shareCode: shareCode ?? this.shareCode,
      isShared: isShared ?? this.isShared,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
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
      'ownerId': ownerId,
      'participants': participants.map((p) => p.toJson()).toList(),
      'participantIds': participantIds,
      'shareCode': shareCode,
      'isShared': isShared,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastModifiedBy': lastModifiedBy,
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
      ownerId: json['ownerId'],
      participants: (json['participants'] as List?)
              ?.map((p) => TripParticipant.fromJson(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      participantIds: (json['participantIds'] as List?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
      shareCode: json['shareCode'],
      isShared: json['isShared'] ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'])
          : null,
      lastModifiedBy: json['lastModifiedBy'],
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
  final bool autoOptimize; // Auto-optimize route when locations change
  final bool preferBetterRoutes; // Use Google Directions for better routes (costs API usage)

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
    this.autoOptimize = true,
    this.preferBetterRoutes = false, // Off by default to save costs
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
    bool? autoOptimize,
    bool? preferBetterRoutes,
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
      autoOptimize: autoOptimize ?? this.autoOptimize,
      preferBetterRoutes: preferBetterRoutes ?? this.preferBetterRoutes,
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
      'autoOptimize': autoOptimize,
      'preferBetterRoutes': preferBetterRoutes,
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
      autoOptimize: json['autoOptimize'] ?? true,
      preferBetterRoutes: json['preferBetterRoutes'] ?? false,
    );
  }
}

import 'location.dart';
import 'amenity.dart';

class DayPlan {
  final int dayNumber;
  final DateTime date;
  final TripLocation startLocation;
  final TripLocation endLocation;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final List<PlannedStop> stops;
  final Amenity? stayOption;

  DayPlan({
    required this.dayNumber,
    required this.date,
    required this.startLocation,
    required this.endLocation,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    this.stops = const [],
    this.stayOption,
  });

  DayPlan copyWith({
    int? dayNumber,
    DateTime? date,
    TripLocation? startLocation,
    TripLocation? endLocation,
    double? totalDistanceKm,
    int? totalDurationMinutes,
    List<PlannedStop>? stops,
    Amenity? stayOption,
    bool clearStayOption = false,
  }) {
    return DayPlan(
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      stops: stops ?? this.stops,
      stayOption: clearStayOption ? null : (stayOption ?? this.stayOption),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayNumber': dayNumber,
      'date': date.toIso8601String(),
      'startLocation': startLocation.toJson(),
      'endLocation': endLocation.toJson(),
      'totalDistanceKm': totalDistanceKm,
      'totalDurationMinutes': totalDurationMinutes,
      'stops': stops.map((s) => s.toJson()).toList(),
      'stayOption': stayOption?.toJson(),
    };
  }

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      dayNumber: json['dayNumber'],
      date: DateTime.parse(json['date']),
      startLocation: TripLocation.fromJson(
        Map<String, dynamic>.from(json['startLocation']),
      ),
      endLocation: TripLocation.fromJson(
        Map<String, dynamic>.from(json['endLocation']),
      ),
      totalDistanceKm: (json['totalDistanceKm'] ?? 0).toDouble(),
      totalDurationMinutes: json['totalDurationMinutes'] ?? 0,
      stops: (json['stops'] as List?)
              ?.map((s) => PlannedStop.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
      stayOption: json['stayOption'] != null
          ? Amenity.fromJson(Map<String, dynamic>.from(json['stayOption']))
          : null,
    );
  }

  String get formattedDuration {
    final hours = totalDurationMinutes ~/ 60;
    final minutes = totalDurationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedDistance {
    if (totalDistanceKm >= 1) {
      return '${totalDistanceKm.toStringAsFixed(1)} km';
    }
    return '${(totalDistanceKm * 1000).toInt()} m';
  }
}

enum StopType {
  destination, // Main trip destination
  fuelStop,
  mealBreak,
  teaBreak,
  restStop,
  overnight,
}

class PlannedStop {
  final TripLocation location;
  final Amenity? amenity;
  final StopType type;
  final int plannedDurationMinutes;
  final double distanceFromPreviousKm;
  final DateTime? estimatedArrival;
  final String? notes;

  PlannedStop({
    required this.location,
    this.amenity,
    required this.type,
    this.plannedDurationMinutes = 15,
    this.distanceFromPreviousKm = 0,
    this.estimatedArrival,
    this.notes,
  });

  PlannedStop copyWith({
    TripLocation? location,
    Amenity? amenity,
    StopType? type,
    int? plannedDurationMinutes,
    double? distanceFromPreviousKm,
    DateTime? estimatedArrival,
    String? notes,
  }) {
    return PlannedStop(
      location: location ?? this.location,
      amenity: amenity ?? this.amenity,
      type: type ?? this.type,
      plannedDurationMinutes: plannedDurationMinutes ?? this.plannedDurationMinutes,
      distanceFromPreviousKm: distanceFromPreviousKm ?? this.distanceFromPreviousKm,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location.toJson(),
      'amenity': amenity?.toJson(),
      'type': type.name,
      'plannedDurationMinutes': plannedDurationMinutes,
      'distanceFromPreviousKm': distanceFromPreviousKm,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'notes': notes,
    };
  }

  factory PlannedStop.fromJson(Map<String, dynamic> json) {
    return PlannedStop(
      location: TripLocation.fromJson(
        Map<String, dynamic>.from(json['location']),
      ),
      amenity: json['amenity'] != null
          ? Amenity.fromJson(Map<String, dynamic>.from(json['amenity']))
          : null,
      type: StopType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StopType.restStop,
      ),
      plannedDurationMinutes: json['plannedDurationMinutes'] ?? 15,
      distanceFromPreviousKm: (json['distanceFromPreviousKm'] ?? 0).toDouble(),
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'])
          : null,
      notes: json['notes'],
    );
  }

  String get typeLabel {
    switch (type) {
      case StopType.destination:
        return 'Destination';
      case StopType.fuelStop:
        return 'Fuel Stop';
      case StopType.mealBreak:
        return 'Meal Break';
      case StopType.teaBreak:
        return 'Tea/Coffee Break';
      case StopType.restStop:
        return 'Rest Stop';
      case StopType.overnight:
        return 'Overnight Stay';
    }
  }

  String get formattedDuration {
    if (plannedDurationMinutes >= 60) {
      final hours = plannedDurationMinutes ~/ 60;
      final minutes = plannedDurationMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${plannedDurationMinutes}m';
  }
}

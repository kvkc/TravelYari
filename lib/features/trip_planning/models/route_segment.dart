import 'location.dart';
import 'amenity.dart';

class RouteSegment {
  final TripLocation start;
  final TripLocation end;
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final List<Amenity> suggestedStops;
  final String? routeProvider; // google, openStreetMap, estimated

  RouteSegment({
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.durationMinutes,
    this.polylinePoints = const [],
    this.suggestedStops = const [],
    this.routeProvider,
  });

  RouteSegment copyWith({
    TripLocation? start,
    TripLocation? end,
    double? distanceKm,
    int? durationMinutes,
    List<LatLng>? polylinePoints,
    List<Amenity>? suggestedStops,
    String? routeProvider,
  }) {
    return RouteSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      suggestedStops: suggestedStops ?? this.suggestedStops,
      routeProvider: routeProvider ?? this.routeProvider,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toJson(),
      'end': end.toJson(),
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'polylinePoints': polylinePoints.map((p) => p.toJson()).toList(),
      'suggestedStops': suggestedStops.map((s) => s.toJson()).toList(),
      'routeProvider': routeProvider,
    };
  }

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      start: TripLocation.fromJson(Map<String, dynamic>.from(json['start'])),
      end: TripLocation.fromJson(Map<String, dynamic>.from(json['end'])),
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      durationMinutes: json['durationMinutes'] ?? 0,
      polylinePoints: (json['polylinePoints'] as List?)
              ?.map((p) => LatLng.fromJson(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      suggestedStops: (json['suggestedStops'] as List?)
              ?.map((s) => Amenity.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
      routeProvider: json['routeProvider'],
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      (json['latitude'] ?? 0).toDouble(),
      (json['longitude'] ?? 0).toDouble(),
    );
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

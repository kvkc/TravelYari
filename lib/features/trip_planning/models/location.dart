import 'package:uuid/uuid.dart';

enum LocationSource {
  googleMaps,
  mappls,
  bhuvan,
  shared, // From WhatsApp/other apps
  manual,
}

class TripLocation {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final LocationSource source;
  final String? placeId; // For Google Maps
  final String? eloc; // For Mappls (eLoc code)
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  TripLocation({
    String? id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.placeId,
    this.eloc,
    this.metadata,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TripLocation copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    LocationSource? source,
    String? placeId,
    String? eloc,
    Map<String, dynamic>? metadata,
  }) {
    return TripLocation(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      placeId: placeId ?? this.placeId,
      eloc: eloc ?? this.eloc,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'source': source.name,
      'placeId': placeId,
      'eloc': eloc,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      source: LocationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => LocationSource.manual,
      ),
      placeId: json['placeId'],
      eloc: json['eloc'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  double distanceTo(TripLocation other) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(other.latitude - latitude);
    final double dLon = _toRadians(other.longitude - longitude);
    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(latitude)) *
            _cos(_toRadians(other.latitude)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  static double _sin(double x) => _sinApprox(x);
  static double _cos(double x) => _sinApprox(x + 1.5707963267948966);
  static double _sqrt(double x) => x > 0 ? _sqrtApprox(x) : 0;
  static double _atan2(double y, double x) => _atan2Approx(y, x);

  static double _sinApprox(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.141592653589793) x -= 6.283185307179586;
    while (x < -3.141592653589793) x += 6.283185307179586;
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _sqrtApprox(double x) {
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2Approx(double y, double x) {
    if (x > 0) return _atanApprox(y / x);
    if (x < 0 && y >= 0) return _atanApprox(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atanApprox(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  static double _atanApprox(double x) {
    // For |x| <= 1, use Taylor series
    if (x.abs() <= 1) {
      double result = x;
      double term = x;
      for (int i = 1; i <= 15; i++) {
        term *= -x * x;
        result += term / (2 * i + 1);
      }
      return result;
    }
    // For |x| > 1, use identity: atan(x) = pi/2 - atan(1/x)
    return (x > 0 ? 1.5707963267948966 : -1.5707963267948966) - _atanApprox(1 / x);
  }

  @override
  String toString() => 'TripLocation($name, $latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripLocation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

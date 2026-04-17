import 'package:uuid/uuid.dart';

enum FuelType {
  petrol,
  diesel,
  electric,
  hybrid,
  cng,
}

class Vehicle {
  final String id;
  final String name;
  final FuelType fuelType;
  final double tankCapacityLiters; // For petrol/diesel/CNG (liters), for EV this is battery kWh
  final double mileage; // km per liter for petrol/diesel, km per kWh for EV
  final String? participantId; // Owner of this vehicle (null = trip owner's vehicle)

  Vehicle({
    String? id,
    required this.name,
    required this.fuelType,
    required this.tankCapacityLiters,
    required this.mileage,
    this.participantId,
  }) : id = id ?? const Uuid().v4();

  /// Calculate the range (km) this vehicle can travel on a full tank/charge
  double get range => tankCapacityLiters * mileage;

  /// Calculate range with safety buffers:
  /// - 15% reserve (for variation in mileage due to terrain, AC, traffic)
  /// - Additional 35km buffer (for inaccurate mileage estimates)
  double get safeRange {
    final rangeWith15Percent = range * 0.85;
    return (rangeWith15Percent - 35).clamp(50, rangeWith15Percent); // Min 50km to avoid negative
  }

  /// Check if this is an electric vehicle
  bool get isElectric => fuelType == FuelType.electric;

  /// Check if this is a hybrid vehicle
  bool get isHybrid => fuelType == FuelType.hybrid;

  /// Get fuel unit label
  String get fuelUnitLabel {
    switch (fuelType) {
      case FuelType.electric:
        return 'kWh';
      case FuelType.cng:
        return 'kg';
      default:
        return 'L';
    }
  }

  /// Get mileage unit label
  String get mileageUnitLabel {
    switch (fuelType) {
      case FuelType.electric:
        return 'km/kWh';
      case FuelType.cng:
        return 'km/kg';
      default:
        return 'km/L';
    }
  }

  Vehicle copyWith({
    String? name,
    FuelType? fuelType,
    double? tankCapacityLiters,
    double? mileage,
    String? participantId,
  }) {
    return Vehicle(
      id: id,
      name: name ?? this.name,
      fuelType: fuelType ?? this.fuelType,
      tankCapacityLiters: tankCapacityLiters ?? this.tankCapacityLiters,
      mileage: mileage ?? this.mileage,
      participantId: participantId ?? this.participantId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fuelType': fuelType.name,
      'tankCapacityLiters': tankCapacityLiters,
      'mileage': mileage,
      'participantId': participantId,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      name: json['name'],
      fuelType: FuelType.values.firstWhere(
        (e) => e.name == json['fuelType'],
        orElse: () => FuelType.petrol,
      ),
      tankCapacityLiters: (json['tankCapacityLiters'] as num).toDouble(),
      mileage: (json['mileage'] as num).toDouble(),
      participantId: json['participantId'],
    );
  }

  /// Create a default car
  factory Vehicle.defaultCar() {
    return Vehicle(
      name: 'My Car',
      fuelType: FuelType.petrol,
      tankCapacityLiters: 45, // Average car tank
      mileage: 15, // Average mileage km/l
    );
  }

  /// Create a default bike
  factory Vehicle.defaultBike() {
    return Vehicle(
      name: 'My Bike',
      fuelType: FuelType.petrol,
      tankCapacityLiters: 15, // Average bike tank
      mileage: 40, // Average bike mileage km/l
    );
  }

  /// Create a default EV
  factory Vehicle.defaultEV() {
    return Vehicle(
      name: 'My EV',
      fuelType: FuelType.electric,
      tankCapacityLiters: 50, // kWh battery capacity
      mileage: 6, // km per kWh
    );
  }

  @override
  String toString() => '$name (${range.toStringAsFixed(0)} km range)';
}

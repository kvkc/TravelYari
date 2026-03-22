import 'package:uuid/uuid.dart';

enum AmenityType {
  petrolStation,
  evStation,
  restaurant,
  hotel,
  teaStall,
  restArea,
}

enum FuelType {
  petrol,
  diesel,
  cng,
  ev,
}

class Amenity {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final AmenityType type;
  final double? rating;
  final int? reviewCount;
  final String? source; // google, zomato, swiggy
  final String? placeId;
  final List<String>? photos;
  final Map<String, dynamic>? details;
  final WashroomInfo? washroomInfo;
  final bool isOpen;
  final String? openingHours;
  final double distanceFromRoute; // in km

  Amenity({
    String? id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.rating,
    this.reviewCount,
    this.source,
    this.placeId,
    this.photos,
    this.details,
    this.washroomInfo,
    this.isOpen = true,
    this.openingHours,
    this.distanceFromRoute = 0,
  }) : id = id ?? const Uuid().v4();

  // Type-specific getters
  bool get isPetrolStation => type == AmenityType.petrolStation;
  bool get isEvStation => type == AmenityType.evStation;
  bool get isRestaurant => type == AmenityType.restaurant;
  bool get isHotel => type == AmenityType.hotel;
  bool get isTeaStall => type == AmenityType.teaStall;

  List<FuelType>? get availableFuels {
    if (!isPetrolStation && !isEvStation) return null;
    return details?['fuelTypes']?.cast<String>()?.map((f) {
      return FuelType.values.firstWhere(
        (e) => e.name == f,
        orElse: () => FuelType.petrol,
      );
    }).toList();
  }

  double? get priceRange => details?['priceRange']?.toDouble();

  List<String>? get cuisines => details?['cuisines']?.cast<String>();

  bool get hasGoodWashroom =>
      washroomInfo != null && washroomInfo!.overallScore >= 3.5;

  bool get hasFemaleWashroom =>
      washroomInfo != null && washroomInfo!.hasFemaleSection;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'rating': rating,
      'reviewCount': reviewCount,
      'source': source,
      'placeId': placeId,
      'photos': photos,
      'details': details,
      'washroomInfo': washroomInfo?.toJson(),
      'isOpen': isOpen,
      'openingHours': openingHours,
      'distanceFromRoute': distanceFromRoute,
    };
  }

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      type: AmenityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AmenityType.restArea,
      ),
      rating: json['rating']?.toDouble(),
      reviewCount: json['reviewCount'],
      source: json['source'],
      placeId: json['placeId'],
      photos: json['photos']?.cast<String>(),
      details: json['details'] != null
          ? Map<String, dynamic>.from(json['details'])
          : null,
      washroomInfo: json['washroomInfo'] != null
          ? WashroomInfo.fromJson(Map<String, dynamic>.from(json['washroomInfo']))
          : null,
      isOpen: json['isOpen'] ?? true,
      openingHours: json['openingHours'],
      distanceFromRoute: (json['distanceFromRoute'] ?? 0).toDouble(),
    );
  }

  Amenity copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    AmenityType? type,
    double? rating,
    int? reviewCount,
    String? source,
    String? placeId,
    List<String>? photos,
    Map<String, dynamic>? details,
    WashroomInfo? washroomInfo,
    bool? isOpen,
    String? openingHours,
    double? distanceFromRoute,
  }) {
    return Amenity(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      source: source ?? this.source,
      placeId: placeId ?? this.placeId,
      photos: photos ?? this.photos,
      details: details ?? this.details,
      washroomInfo: washroomInfo ?? this.washroomInfo,
      isOpen: isOpen ?? this.isOpen,
      openingHours: openingHours ?? this.openingHours,
      distanceFromRoute: distanceFromRoute ?? this.distanceFromRoute,
    );
  }
}

class WashroomInfo {
  final double overallScore; // 0-5
  final double cleanlinessScore;
  final double femaleReviewScore;
  final bool hasFemaleSection;
  final bool hasWesternToilet;
  final bool hasIndianToilet;
  final int totalReviews;
  final int femaleReviewCount;
  final List<String>? recentComments;

  WashroomInfo({
    required this.overallScore,
    this.cleanlinessScore = 0,
    this.femaleReviewScore = 0,
    this.hasFemaleSection = false,
    this.hasWesternToilet = false,
    this.hasIndianToilet = true,
    this.totalReviews = 0,
    this.femaleReviewCount = 0,
    this.recentComments,
  });

  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'cleanlinessScore': cleanlinessScore,
      'femaleReviewScore': femaleReviewScore,
      'hasFemaleSection': hasFemaleSection,
      'hasWesternToilet': hasWesternToilet,
      'hasIndianToilet': hasIndianToilet,
      'totalReviews': totalReviews,
      'femaleReviewCount': femaleReviewCount,
      'recentComments': recentComments,
    };
  }

  factory WashroomInfo.fromJson(Map<String, dynamic> json) {
    return WashroomInfo(
      overallScore: (json['overallScore'] ?? 0).toDouble(),
      cleanlinessScore: (json['cleanlinessScore'] ?? 0).toDouble(),
      femaleReviewScore: (json['femaleReviewScore'] ?? 0).toDouble(),
      hasFemaleSection: json['hasFemaleSection'] ?? false,
      hasWesternToilet: json['hasWesternToilet'] ?? false,
      hasIndianToilet: json['hasIndianToilet'] ?? true,
      totalReviews: json['totalReviews'] ?? 0,
      femaleReviewCount: json['femaleReviewCount'] ?? 0,
      recentComments: json['recentComments']?.cast<String>(),
    );
  }
}

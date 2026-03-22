import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/route_segment.dart';

/// Simple latitude/longitude class for use across map services
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

abstract class MapServiceInterface {
  String get providerName;

  /// Search for places by query string
  Future<List<TripLocation>> searchPlaces(String query, {LatLng? nearLocation});

  /// Get place details by place ID
  Future<TripLocation?> getPlaceDetails(String placeId);

  /// Reverse geocode coordinates to address
  Future<TripLocation?> reverseGeocode(double latitude, double longitude);

  /// Get directions between two points
  Future<RouteSegment?> getDirections(
    TripLocation origin,
    TripLocation destination, {
    List<TripLocation>? waypoints,
  });

  /// Get distance matrix for multiple origins and destinations
  Future<List<List<double>>> getDistanceMatrix(
    List<TripLocation> origins,
    List<TripLocation> destinations,
  );

  /// Search for nearby places of a specific type
  Future<List<TripLocation>> searchNearby(
    double latitude,
    double longitude, {
    required String type,
    int radiusMeters = 5000,
  });

  /// Autocomplete place search
  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
    int radiusMeters = 50000,
  });
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

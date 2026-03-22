import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/trip_planning/models/trip.dart';
import '../../../features/trip_planning/models/location.dart';
import '../../../features/trip_planning/models/day_plan.dart';

enum ShareDestination {
  googleMaps,
  appleMaps,
  whatsApp,
  general,
}

class RouteShareService {
  /// Share the entire trip route
  static Future<void> shareRoute(
    Trip trip, {
    ShareDestination destination = ShareDestination.general,
  }) async {
    final locations = trip.optimizedRoute.isNotEmpty
        ? trip.optimizedRoute
        : trip.locations;

    if (locations.isEmpty) return;

    switch (destination) {
      case ShareDestination.googleMaps:
        await _openInGoogleMaps(locations);
        break;
      case ShareDestination.appleMaps:
        await _openInAppleMaps(locations);
        break;
      case ShareDestination.whatsApp:
        await _shareViaWhatsApp(trip, locations);
        break;
      case ShareDestination.general:
        await _shareGeneral(trip, locations);
        break;
    }
  }

  /// Share a specific day's route
  static Future<void> shareDayRoute(
    Trip trip,
    DayPlan dayPlan, {
    ShareDestination destination = ShareDestination.general,
  }) async {
    final locations = [
      dayPlan.startLocation,
      ...dayPlan.stops.map((s) => s.location),
      dayPlan.endLocation,
    ];

    switch (destination) {
      case ShareDestination.googleMaps:
        await _openInGoogleMaps(locations);
        break;
      case ShareDestination.appleMaps:
        await _openInAppleMaps(locations);
        break;
      case ShareDestination.whatsApp:
        await _shareViaWhatsAppDay(trip, dayPlan, locations);
        break;
      case ShareDestination.general:
        await _shareGeneralDay(trip, dayPlan, locations);
        break;
    }
  }

  /// Generate Google Maps URL with waypoints
  static String generateGoogleMapsUrl(List<TripLocation> locations) {
    if (locations.isEmpty) return '';
    if (locations.length == 1) {
      final loc = locations.first;
      return 'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}';
    }

    final origin = locations.first;
    final destination = locations.last;
    final waypoints = locations.length > 2
        ? locations.sublist(1, locations.length - 1)
        : <TripLocation>[];

    var url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving';

    if (waypoints.isNotEmpty) {
      final waypointStr = waypoints
          .map((w) => '${w.latitude},${w.longitude}')
          .join('|');
      url += '&waypoints=$waypointStr';
    }

    return url;
  }

  /// Generate Apple Maps URL with waypoints
  static String generateAppleMapsUrl(List<TripLocation> locations) {
    if (locations.isEmpty) return '';
    if (locations.length == 1) {
      final loc = locations.first;
      return 'https://maps.apple.com/?q=${loc.latitude},${loc.longitude}';
    }

    final origin = locations.first;
    final destination = locations.last;

    // Apple Maps doesn't support multiple waypoints in URL well
    // So we create a directions URL from origin to destination
    var url = 'https://maps.apple.com/?'
        'saddr=${origin.latitude},${origin.longitude}'
        '&daddr=${destination.latitude},${destination.longitude}'
        '&dirflg=d'; // d = driving

    return url;
  }

  /// Generate shareable text summary of the trip
  static String generateTripSummary(Trip trip, List<TripLocation> locations) {
    final buffer = StringBuffer();

    buffer.writeln('🗺️ *${trip.name}*');
    buffer.writeln('');

    // Route overview
    buffer.writeln('📍 *Route:*');
    for (int i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final prefix = i == 0
          ? '🟢'
          : i == locations.length - 1
              ? '🔴'
              : '📌';
      buffer.writeln('$prefix ${loc.name}');
    }
    buffer.writeln('');

    // Stats
    if (trip.totalDistanceKm > 0) {
      buffer.writeln('📊 *Trip Details:*');
      buffer.writeln('• Distance: ${trip.totalDistanceKm.toStringAsFixed(0)} km');
      buffer.writeln('• Duration: ${_formatDuration(trip.estimatedDurationMinutes)}');
      if (trip.dayPlans.isNotEmpty) {
        buffer.writeln('• Days: ${trip.dayPlans.length}');
      }
      buffer.writeln('');
    }

    // Google Maps link
    final googleUrl = generateGoogleMapsUrl(locations);
    buffer.writeln('🔗 *Open in Google Maps:*');
    buffer.writeln(googleUrl);

    return buffer.toString();
  }

  /// Generate day summary
  static String generateDaySummary(Trip trip, DayPlan day, List<TripLocation> locations) {
    final buffer = StringBuffer();

    buffer.writeln('🗺️ *${trip.name} - Day ${day.dayNumber}*');
    buffer.writeln('');

    // Route
    buffer.writeln('📍 *Route:*');
    buffer.writeln('🟢 ${day.startLocation.name}');
    for (var stop in day.stops) {
      if (stop.type == StopType.destination) {
        buffer.writeln('📌 ${stop.location.name}');
      }
    }
    buffer.writeln('🔴 ${day.endLocation.name}');
    buffer.writeln('');

    // Stats
    buffer.writeln('📊 *Day Details:*');
    buffer.writeln('• Distance: ${day.totalDistanceKm.toStringAsFixed(0)} km');
    buffer.writeln('• Duration: ${_formatDuration(day.totalDurationMinutes)}');
    buffer.writeln('• Stops: ${day.stops.length}');
    buffer.writeln('');

    // Breaks & amenities
    final breaks = day.stops.where((s) =>
      s.type == StopType.teaBreak ||
      s.type == StopType.mealBreak ||
      s.type == StopType.fuelStop
    ).toList();

    if (breaks.isNotEmpty) {
      buffer.writeln('☕ *Suggested Stops:*');
      for (var stop in breaks) {
        final icon = stop.type == StopType.teaBreak
            ? '☕'
            : stop.type == StopType.mealBreak
                ? '🍽️'
                : '⛽';
        buffer.writeln('$icon ${stop.location.name}');
      }
      buffer.writeln('');
    }

    // Stay
    if (day.stayOption != null) {
      buffer.writeln('🏨 *Stay:* ${day.stayOption!.name}');
      buffer.writeln('');
    }

    // Google Maps link
    final googleUrl = generateGoogleMapsUrl(locations);
    buffer.writeln('🔗 *Open in Google Maps:*');
    buffer.writeln(googleUrl);

    return buffer.toString();
  }

  static Future<void> _openInGoogleMaps(List<TripLocation> locations) async {
    final url = generateGoogleMapsUrl(locations);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openInAppleMaps(List<TripLocation> locations) async {
    final url = generateAppleMapsUrl(locations);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _shareViaWhatsApp(Trip trip, List<TripLocation> locations) async {
    final text = generateTripSummary(trip, locations);
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = 'whatsapp://send?text=$encodedText';

    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to general share
      await _shareGeneral(trip, locations);
    }
  }

  static Future<void> _shareViaWhatsAppDay(
    Trip trip,
    DayPlan day,
    List<TripLocation> locations,
  ) async {
    final text = generateDaySummary(trip, day, locations);
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = 'whatsapp://send?text=$encodedText';

    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to general share
      await _shareGeneralDay(trip, day, locations);
    }
  }

  static Future<void> _shareGeneral(Trip trip, List<TripLocation> locations) async {
    final text = generateTripSummary(trip, locations);
    await Share.share(text, subject: trip.name);
  }

  static Future<void> _shareGeneralDay(
    Trip trip,
    DayPlan day,
    List<TripLocation> locations,
  ) async {
    final text = generateDaySummary(trip, day, locations);
    await Share.share(text, subject: '${trip.name} - Day ${day.dayNumber}');
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return '${days}d ${remainingHours}h';
  }
}

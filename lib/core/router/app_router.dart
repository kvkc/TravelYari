import 'package:flutter/material.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/trip_planning/screens/trip_planning_screen.dart';
import '../../features/trip_planning/screens/route_view_screen.dart';
import '../../features/trip_planning/models/trip.dart';
import '../../features/trip_planning/models/location.dart';
import '../../features/location_search/screens/location_search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/api_keys_screen.dart';
import '../../features/amenities/screens/amenities_screen.dart';
import '../../features/collaboration/screens/invite_participants_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String tripPlanning = '/trip-planning';
  static const String routeView = '/route-view';
  static const String locationSearch = '/location-search';
  static const String settings = '/settings';
  static const String apiKeys = '/api-keys';
  static const String amenities = '/amenities';
  static const String inviteParticipants = '/invite-participants';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case tripPlanning:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => TripPlanningScreen(
            tripId: args?['tripId'],
            initialLocation: args?['initialLocation'] as TripLocation?,
          ),
        );
      case routeView:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RouteViewScreen(
            tripId: args['tripId'],
          ),
        );
      case locationSearch:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => LocationSearchScreen(
            mapProvider: args?['mapProvider'] ?? 'google',
          ),
        );
      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      case apiKeys:
        return MaterialPageRoute(
          builder: (_) => const ApiKeysScreen(),
        );
      case amenities:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AmenitiesScreen(
            tripId: args['tripId'],
            amenityType: args['amenityType'],
          ),
        );
      case inviteParticipants:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => InviteParticipantsScreen(
            trip: args['trip'] as Trip,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

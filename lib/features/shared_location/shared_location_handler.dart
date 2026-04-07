import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uni_links/uni_links.dart';

import '../../core/services/sync/trip_sync_service.dart';
import '../../core/router/app_router.dart';
import '../trip_planning/models/location.dart';
import '../trip_planning/models/trip.dart';
import 'location_parser.dart';

/// Handles shared locations from WhatsApp, Google Maps, and other apps
/// Also handles trip invite deep links (travelyari://join?code=XXX)
class SharedLocationHandler {
  static StreamSubscription? _sharedTextSubscription;
  static StreamSubscription? _linkSubscription;
  static WidgetRef? _ref;
  static Function(TripLocation)? _onLocationReceived;
  static Function(Trip)? _onTripJoined;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void init(WidgetRef ref, {GlobalKey<NavigatorState>? navigatorKey}) {
    _ref = ref;
    _navigatorKey = navigatorKey;
    _setupListeners();
  }

  static void setOnLocationReceived(Function(TripLocation) callback) {
    _onLocationReceived = callback;
  }

  static void setOnTripJoined(Function(Trip) callback) {
    _onTripJoined = callback;
  }

  static void _setupListeners() {
    // Sharing intent only works on mobile platforms
    if (!kIsWeb) {
      // Handle text shared from other apps (WhatsApp location shares, etc.)
      _sharedTextSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          for (var file in files) {
            if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
              _handleSharedText(file.path);
            }
          }
        },
        onError: (e) => print('Shared media error: $e'),
      );

      // Handle initial shared media (when app is opened via share)
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
        for (var file in files) {
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
            _handleSharedText(file.path);
          }
        }
      });
    }

    // Handle deep links (maps URLs) - only on mobile
    if (!kIsWeb) {
      _linkSubscription = linkStream.listen(
        _handleDeepLink,
        onError: (e) => print('Deep link error: $e'),
      );

      // Handle initial deep link
      getInitialLink().then((link) {
        if (link != null) _handleDeepLink(link);
      });
    }
  }

  static Future<void> _handleSharedText(String text) async {
    final location = await LocationParser.parseSharedText(text, _ref!);
    if (location != null && _onLocationReceived != null) {
      _onLocationReceived!(location);
    }
  }

  static Future<void> _handleDeepLink(String? link) async {
    if (link == null) return;

    // Check if this is a trip invite link
    if (_isInviteLink(link)) {
      await _handleInviteLink(link);
      return;
    }

    // Otherwise treat as location link
    final location = await LocationParser.parseUrl(link, _ref!);
    if (location != null && _onLocationReceived != null) {
      _onLocationReceived!(location);
    }
  }

  /// Check if the link is a trip invite link
  static bool _isInviteLink(String link) {
    // Handle both custom scheme and web URL formats
    // travelyari://join?code=XXX
    // https://travelyari.app/join?code=XXX
    return link.contains('travelyari://join') ||
           link.contains('travelyari.app/join');
  }

  /// Handle trip invite deep link
  static Future<void> _handleInviteLink(String link) async {
    try {
      final uri = Uri.parse(link);
      final shareCode = uri.queryParameters['code'];

      if (shareCode == null || shareCode.isEmpty) {
        debugPrint('Invalid invite link: no share code found');
        return;
      }

      // Join the trip using the share code
      final syncService = _ref!.read(tripSyncServiceProvider.notifier);
      final trip = await syncService.joinTripByShareCode(shareCode);

      if (trip != null) {
        debugPrint('Successfully joined trip: ${trip.name}');

        // Notify callback if set
        if (_onTripJoined != null) {
          _onTripJoined!(trip);
        }

        // Navigate to the trip if navigator key is available
        if (_navigatorKey?.currentState != null) {
          _navigatorKey!.currentState!.pushNamed(
            AppRouter.tripPlanning,
            arguments: {'tripId': trip.id},
          );
        }
      } else {
        debugPrint('Failed to join trip with code: $shareCode');
      }
    } catch (e) {
      debugPrint('Error handling invite link: $e');
    }
  }

  static void dispose() {
    _sharedTextSubscription?.cancel();
    _linkSubscription?.cancel();
  }
}

/// Provider for the shared location state
final sharedLocationProvider = StateNotifierProvider<SharedLocationNotifier, TripLocation?>((ref) {
  return SharedLocationNotifier();
});

class SharedLocationNotifier extends StateNotifier<TripLocation?> {
  SharedLocationNotifier() : super(null);

  void setLocation(TripLocation location) {
    state = location;
  }

  void clear() {
    state = null;
  }
}

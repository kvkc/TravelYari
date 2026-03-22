import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uni_links/uni_links.dart';

import '../../core/services/map/unified_map_service.dart';
import '../trip_planning/models/location.dart';
import 'location_parser.dart';

/// Handles shared locations from WhatsApp, Google Maps, and other apps
class SharedLocationHandler {
  static StreamSubscription? _sharedTextSubscription;
  static StreamSubscription? _linkSubscription;
  static WidgetRef? _ref;
  static Function(TripLocation)? _onLocationReceived;

  static void init(WidgetRef ref) {
    _ref = ref;
    _setupListeners();
  }

  static void setOnLocationReceived(Function(TripLocation) callback) {
    _onLocationReceived = callback;
  }

  static void _setupListeners() {
    // Handle text shared from other apps (WhatsApp location shares, etc.)
    _sharedTextSubscription = ReceiveSharingIntent.getTextStream().listen(
      _handleSharedText,
      onError: (e) => print('Shared text error: $e'),
    );

    // Handle initial shared text (when app is opened via share)
    ReceiveSharingIntent.getInitialText().then((text) {
      if (text != null) _handleSharedText(text);
    });

    // Handle deep links (maps URLs)
    _linkSubscription = linkStream.listen(
      _handleDeepLink,
      onError: (e) => print('Deep link error: $e'),
    );

    // Handle initial deep link
    getInitialLink().then((link) {
      if (link != null) _handleDeepLink(link);
    });
  }

  static Future<void> _handleSharedText(String text) async {
    final location = await LocationParser.parseSharedText(text, _ref!);
    if (location != null && _onLocationReceived != null) {
      _onLocationReceived!(location);
    }
  }

  static Future<void> _handleDeepLink(String? link) async {
    if (link == null) return;

    final location = await LocationParser.parseUrl(link, _ref!);
    if (location != null && _onLocationReceived != null) {
      _onLocationReceived!(location);
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

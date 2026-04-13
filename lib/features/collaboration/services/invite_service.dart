import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/sync/trip_sync_service.dart';
import '../../trip_planning/models/trip.dart';

class InviteService {
  final TripSyncService _syncService;

  // Firebase Hosting domain
  static const String _hostingDomain = 'yatraplanner-50f70.web.app';

  InviteService(this._syncService);

  /// Get or generate share code for a trip
  Future<String?> getShareCode(Trip trip) async {
    // Use existing share code if available (avoids network call)
    if (trip.shareCode != null && trip.shareCode!.isNotEmpty) {
      return trip.shareCode;
    }

    // Generate new share code
    return await _syncService.shareTrip(trip.id);
  }

  /// Generate a shareable invite link for a trip
  /// Uses Firebase Hosting URL which is clickable AND opens the app via App Links
  String generateInviteLink(String shareCode) {
    return 'https://$_hostingDomain/join?code=$shareCode';
  }

  /// Generate invite message with clickable link
  String generateInviteMessage(Trip trip, String shareCode) {
    final link = generateInviteLink(shareCode);
    return '''Join my trip "${trip.name}" on Travel Yaari!

$link

Or enter code manually: *$shareCode*''';
  }

  /// Share invite via system share sheet
  Future<void> shareInvite(Trip trip) async {
    final shareCode = await getShareCode(trip);
    if (shareCode == null) {
      debugPrint('Failed to generate share code');
      return;
    }

    final message = generateInviteMessage(trip, shareCode);
    await Share.share(message, subject: 'Join my trip: ${trip.name}');
  }

  /// Send invite via WhatsApp to a specific number
  Future<bool> sendWhatsAppInvite(Trip trip, String phoneNumber) async {
    final shareCode = await getShareCode(trip);
    if (shareCode == null) return false;

    final message = generateInviteMessage(trip, shareCode);
    final encodedMessage = Uri.encodeComponent(message);

    // Clean and normalize phone number for wa.me (requires country code)
    final cleanNumber = _normalizePhoneNumber(phoneNumber);

    final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    final uri = Uri.parse(whatsappUrl);

    try {
      // Try launching directly - canLaunchUrl can be unreliable on some devices
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      debugPrint('Failed to open WhatsApp: $e');
      return false;
    }
  }

  /// Normalize phone number to international format for wa.me
  /// wa.me requires numbers without + prefix but with country code
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Handle Indian numbers (default country code)
    if (digits.startsWith('91') && digits.length == 12) {
      // Already has country code: 919876543210
      return digits;
    } else if (digits.startsWith('0') && digits.length == 11) {
      // Starts with 0: 09876543210 -> 919876543210
      return '91${digits.substring(1)}';
    } else if (digits.length == 10) {
      // Just 10 digits: 9876543210 -> 919876543210
      return '91$digits';
    }

    // Return as-is for other formats (international numbers)
    return digits;
  }

  /// Send invite via SMS
  Future<bool> sendSmsInvite(Trip trip, String phoneNumber) async {
    final shareCode = await getShareCode(trip);
    if (shareCode == null) return false;

    final message = generateInviteMessage(trip, shareCode);
    final encodedMessage = Uri.encodeComponent(message);

    // Clean phone number (keep original format for SMS, just remove spaces)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s]'), '');

    final smsUrl = 'sms:$cleanNumber?body=$encodedMessage';
    final uri = Uri.parse(smsUrl);

    try {
      await launchUrl(uri);
      return true;
    } catch (e) {
      debugPrint('Failed to open SMS: $e');
      return false;
    }
  }

  /// Send invite via email
  Future<bool> sendEmailInvite(Trip trip, String email, {String? name}) async {
    final shareCode = await getShareCode(trip);
    if (shareCode == null) return false;

    final subject = Uri.encodeComponent('Join my trip: ${trip.name}');
    final body = Uri.encodeComponent(generateInviteMessage(trip, shareCode));

    final emailUrl = 'mailto:$email?subject=$subject&body=$body';
    final uri = Uri.parse(emailUrl);

    try {
      await launchUrl(uri);
      return true;
    } catch (e) {
      debugPrint('Failed to open email: $e');
      return false;
    }
  }

  /// Parse share code from an invite link
  /// Handles both web URLs (https://travelyari.app/join?code=XXX)
  /// and custom scheme (travelyari://join?code=XXX)
  String? parseShareCodeFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      return uri.queryParameters['code'];
    } catch (e) {
      // Try simple regex for share code
      final match = RegExp(r'code=([A-Z0-9]{6})', caseSensitive: false).firstMatch(link);
      return match?.group(1)?.toUpperCase();
    }
  }

  /// Join trip using share code
  Future<Trip?> joinTripWithCode(String shareCode, {String? joinerName}) async {
    return await _syncService.joinTripByShareCode(shareCode, joinerName: joinerName);
  }
}

// Provider
final inviteServiceProvider = Provider<InviteService>((ref) {
  final syncService = ref.watch(tripSyncServiceProvider.notifier);
  return InviteService(syncService);
});

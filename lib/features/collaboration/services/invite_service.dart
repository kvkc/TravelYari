import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/sync/trip_sync_service.dart';
import '../../trip_planning/models/trip.dart';

class InviteService {
  final TripSyncService _syncService;

  InviteService(this._syncService);

  /// Generate a shareable invite link for a trip
  Future<String?> generateInviteLink(Trip trip) async {
    // Get or generate share code
    String? shareCode = trip.shareCode;

    if (shareCode == null || shareCode.isEmpty) {
      shareCode = await _syncService.shareTrip(trip.id);
    }

    if (shareCode == null) return null;

    // Generate deep link
    // Format: yatraplanner://join?code=ABC123
    // Web fallback: https://yatraplanner.app/join?code=ABC123
    return 'yatraplanner://join?code=$shareCode';
  }

  /// Generate invite message with link
  String generateInviteMessage(Trip trip, String inviteLink) {
    return '''
Join my trip "${trip.name}" on Yatra Planner!

Click to join: $inviteLink

Download Yatra Planner to collaborate on trip planning.
''';
  }

  /// Share invite via system share sheet
  Future<void> shareInvite(Trip trip) async {
    final inviteLink = await generateInviteLink(trip);
    if (inviteLink == null) {
      debugPrint('Failed to generate invite link');
      return;
    }

    final message = generateInviteMessage(trip, inviteLink);
    await Share.share(message, subject: 'Join my trip: ${trip.name}');
  }

  /// Send invite via WhatsApp to a specific number
  Future<bool> sendWhatsAppInvite(Trip trip, String phoneNumber) async {
    final inviteLink = await generateInviteLink(trip);
    if (inviteLink == null) return false;

    final message = generateInviteMessage(trip, inviteLink);
    final encodedMessage = Uri.encodeComponent(message);

    // Clean phone number (remove spaces, dashes)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
    final uri = Uri.parse(whatsappUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }

    return false;
  }

  /// Send invite via SMS
  Future<bool> sendSmsInvite(Trip trip, String phoneNumber) async {
    final inviteLink = await generateInviteLink(trip);
    if (inviteLink == null) return false;

    final message = generateInviteMessage(trip, inviteLink);
    final encodedMessage = Uri.encodeComponent(message);

    final smsUrl = 'sms:$phoneNumber?body=$encodedMessage';
    final uri = Uri.parse(smsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }

    return false;
  }

  /// Send invite via email
  Future<bool> sendEmailInvite(Trip trip, String email, {String? name}) async {
    final inviteLink = await generateInviteLink(trip);
    if (inviteLink == null) return false;

    final subject = Uri.encodeComponent('Join my trip: ${trip.name}');
    final body = Uri.encodeComponent(generateInviteMessage(trip, inviteLink));

    final emailUrl = 'mailto:$email?subject=$subject&body=$body';
    final uri = Uri.parse(emailUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }

    return false;
  }

  /// Parse share code from an invite link
  String? parseShareCodeFromLink(String link) {
    try {
      final uri = Uri.parse(link);
      return uri.queryParameters['code'];
    } catch (e) {
      // Try simple regex for share code
      final match = RegExp(r'code=([A-Z0-9]{6})').firstMatch(link);
      return match?.group(1);
    }
  }

  /// Join trip using share code
  Future<Trip?> joinTripWithCode(String shareCode) async {
    return await _syncService.joinTripByShareCode(shareCode);
  }
}

// Provider
final inviteServiceProvider = Provider<InviteService>((ref) {
  final syncService = ref.watch(tripSyncServiceProvider.notifier);
  return InviteService(syncService);
});

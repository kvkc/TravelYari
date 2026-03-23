import 'package:flutter/material.dart';

import '../../../core/services/share/route_share_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/day_plan.dart';

class ShareOptionsSheet extends StatelessWidget {
  final Trip trip;
  final DayPlan? dayPlan;

  const ShareOptionsSheet({
    super.key,
    required this.trip,
    this.dayPlan,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    DayPlan? dayPlan,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareOptionsSheet(
        trip: trip,
        dayPlan: dayPlan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDay = dayPlan != null;
    final title = isDay
        ? '${trip.name} - Day ${dayPlan!.dayNumber}'
        : trip.name;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Share Route',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Share options
            _buildOption(
              context,
              icon: Icons.map,
              iconColor: Colors.green,
              title: 'Open in Google Maps',
              subtitle: 'View route with turn-by-turn directions',
              onTap: () => _shareRoute(context, ShareDestination.googleMaps),
            ),
            _buildOption(
              context,
              icon: Icons.map_outlined,
              iconColor: Colors.blue,
              title: 'Open in Apple Maps',
              subtitle: 'View route on Apple Maps (iOS)',
              onTap: () => _shareRoute(context, ShareDestination.appleMaps),
            ),
            _buildOption(
              context,
              icon: Icons.chat,
              iconColor: Colors.green[700]!,
              title: 'Share via WhatsApp',
              subtitle: 'Send trip summary with map link',
              onTap: () => _shareRoute(context, ShareDestination.whatsApp),
            ),
            _buildOption(
              context,
              icon: Icons.share,
              iconColor: AppTheme.primaryColor,
              title: 'Share',
              subtitle: 'Share to any app',
              onTap: () => _shareRoute(context, ShareDestination.general),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareRoute(BuildContext context, ShareDestination destination) async {
    Navigator.pop(context);

    try {
      if (dayPlan != null) {
        await RouteShareService.shareDayRoute(
          trip,
          dayPlan!,
          destination: destination,
        );
      } else {
        await RouteShareService.shareRoute(
          trip,
          destination: destination,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

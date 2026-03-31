import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/amenity.dart';

class EditStaySheet extends StatelessWidget {
  final Amenity stay;
  final VoidCallback? onChangeStay;
  final VoidCallback? onRemoveStay;

  const EditStaySheet({
    super.key,
    required this.stay,
    this.onChangeStay,
    this.onRemoveStay,
  });

  static Future<void> show(
    BuildContext context, {
    required Amenity stay,
    VoidCallback? onChangeStay,
    VoidCallback? onRemoveStay,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EditStaySheet(
        stay: stay,
        onChangeStay: onChangeStay,
        onRemoveStay: onRemoveStay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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

            // Stay info header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.hotel,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stay.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stay.address != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          stay.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (stay.rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              stay.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (stay.reviewCount != null) ...[
                              Text(
                                ' (${stay.reviewCount} reviews)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionTile(
              context,
              icon: Icons.map_outlined,
              iconColor: Colors.blue,
              title: 'Open in Google Maps',
              subtitle: 'View location and get directions',
              onTap: () => _openInGoogleMaps(context),
            ),

            const SizedBox(height: 8),

            _buildActionTile(
              context,
              icon: Icons.swap_horiz,
              iconColor: AppTheme.primaryColor,
              title: 'Change Stay',
              subtitle: 'Search for a different hotel',
              onTap: onChangeStay != null
                  ? () {
                      Navigator.pop(context);
                      onChangeStay!();
                    }
                  : null,
            ),

            const SizedBox(height: 8),

            _buildActionTile(
              context,
              icon: Icons.delete_outline,
              iconColor: Colors.red,
              title: 'Remove Stay',
              subtitle: 'Remove this accommodation from your plan',
              onTap: onRemoveStay != null
                  ? () {
                      Navigator.pop(context);
                      onRemoveStay!();
                    }
                  : null,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
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
      ),
    );
  }

  Future<void> _openInGoogleMaps(BuildContext context) async {
    Navigator.pop(context);

    // Build Google Maps URL
    String url;
    if (stay.placeId != null && stay.placeId!.isNotEmpty) {
      url = 'https://www.google.com/maps/search/?api=1'
          '&query=${stay.latitude},${stay.longitude}'
          '&query_place_id=${stay.placeId}';
    } else {
      // Fallback to coordinates with name
      final encodedName = Uri.encodeComponent(stay.name);
      url = 'https://www.google.com/maps/search/?api=1'
          '&query=$encodedName'
          '&center=${stay.latitude},${stay.longitude}';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }
}

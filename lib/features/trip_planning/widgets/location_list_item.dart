import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/location.dart';

class LocationListItem extends StatelessWidget {
  final TripLocation location;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onRemove;

  const LocationListItem({
    super.key,
    required this.location,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 16,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? AppTheme.successColor
                        : isLast
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isFirst
                        ? const Icon(Icons.play_arrow, color: Colors.white, size: 14)
                        : isLast
                            ? const Icon(Icons.flag, color: Colors.white, size: 14)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 16,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
              ],
            ),
          ),

          // Location card
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Drag handle
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_handle,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Location info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (location.address != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              location.address!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          _buildSourceBadge(),
                        ],
                      ),
                    ),

                    // Remove button
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onRemove,
                      color: Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge() {
    String label;
    Color color;

    switch (location.source) {
      case LocationSource.googleMaps:
        label = 'Google';
        color = Colors.blue;
        break;
      case LocationSource.mappls:
        label = 'Mappls';
        color = Colors.green;
        break;
      case LocationSource.bhuvan:
        label = 'Bhuvan';
        color = Colors.orange;
        break;
      case LocationSource.openStreetMap:
        label = 'OSM';
        color = Colors.teal;
        break;
      case LocationSource.shared:
        label = 'Shared';
        color = Colors.purple;
        break;
      case LocationSource.manual:
        label = 'Manual';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

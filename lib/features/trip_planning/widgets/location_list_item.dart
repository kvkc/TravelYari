import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/location.dart';

class LocationListItem extends StatelessWidget {
  final TripLocation location;
  final int index;
  final bool isFirst;
  final bool isLast;
  final bool isStartingPoint;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  const LocationListItem({
    super.key,
    required this.location,
    required this.index,
    required this.isFirst,
    required this.isLast,
    this.isStartingPoint = false,
    required this.onRemove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Timeline indicator
          SizedBox(
            width: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 12,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isStartingPoint
                        ? Colors.green
                        : isFirst
                            ? AppTheme.successColor
                            : isLast
                                ? AppTheme.accentColor
                                : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isStartingPoint
                        ? const Icon(Icons.my_location, color: Colors.white, size: 14)
                        : isFirst
                            ? const Icon(Icons.play_arrow, color: Colors.white, size: 14)
                            : isLast
                                ? const Icon(Icons.flag, color: Colors.white, size: 14)
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 12,
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Location card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Drag handle on the left
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.drag_indicator,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Location info (takes remaining space)
                    Expanded(
                      child: GestureDetector(
                        onTap: onEdit,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (isStartingPoint)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'START',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    location.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (location.address != null && location.address!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                location.address!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Remove button on the right
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onRemove,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
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
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/day_plan.dart';
import '../models/amenity.dart';

class DayPlanCard extends StatelessWidget {
  final DayPlan dayPlan;
  final Function(Amenity)? onAmenityTap;
  final VoidCallback? onShare;

  const DayPlanCard({
    super.key,
    required this.dayPlan,
    this.onAmenityTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day header
        _buildDayHeader(),
        const SizedBox(height: 16),

        // Stops timeline
        ...List.generate(dayPlan.stops.length, (index) {
          return _buildStopItem(dayPlan.stops[index], index);
        }),

        // Stay option
        if (dayPlan.stayOption != null) ...[
          const SizedBox(height: 16),
          _buildStayOption(),
        ],
      ],
    );
  }

  Widget _buildDayHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day ${dayPlan.dayNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(dayPlan.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (onShare != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.share, size: 20, color: AppTheme.primaryColor),
                        onPressed: onShare,
                        tooltip: 'Share day route',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.route,
                  dayPlan.formattedDistance,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.timer,
                  dayPlan.formattedDuration,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.pin_drop,
                  '${dayPlan.stops.length} stops',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(PlannedStop stop, int index) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 8,
                  color: index == 0
                      ? Colors.transparent
                      : AppTheme.primaryColor.withOpacity(0.3),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _getStopColor(stop.type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStopIcon(stop.type),
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: index == dayPlan.stops.length - 1
                        ? Colors.transparent
                        : AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Stop card
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: stop.amenity != null
                    ? () => onAmenityTap?.call(stop.amenity!)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stop.location.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStopColor(stop.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stop.typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStopColor(stop.type),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (stop.distanceFromPreviousKm > 0) ...[
                            Icon(
                              Icons.route,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${stop.distanceFromPreviousKm.toStringAsFixed(0)} km',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stop.formattedDuration,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (stop.amenity?.rating != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              stop.amenity!.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (stop.amenity?.hasGoodWashroom == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.wc, size: 12, color: AppTheme.successColor),
                            const SizedBox(width: 4),
                            Text(
                              'Good washroom facilities',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStayOption() {
    final stay = dayPlan.stayOption!;

    return Card(
      color: AppTheme.secondaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hotel,
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recommended Stay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stay.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (stay.address != null) ...[
              const SizedBox(height: 4),
              Text(
                stay.address!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (stay.rating != null) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    stay.rating!.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                ],
                if (stay.hasGoodWashroom) ...[
                  Icon(Icons.wc, size: 16, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Clean facilities',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStopColor(StopType type) {
    switch (type) {
      case StopType.destination:
        return AppTheme.primaryColor;
      case StopType.fuelStop:
        return Colors.orange;
      case StopType.mealBreak:
        return Colors.red;
      case StopType.teaBreak:
        return Colors.brown;
      case StopType.restStop:
        return Colors.teal;
      case StopType.overnight:
        return Colors.purple;
    }
  }

  IconData _getStopIcon(StopType type) {
    switch (type) {
      case StopType.destination:
        return Icons.place;
      case StopType.fuelStop:
        return Icons.local_gas_station;
      case StopType.mealBreak:
        return Icons.restaurant;
      case StopType.teaBreak:
        return Icons.local_cafe;
      case StopType.restStop:
        return Icons.airline_seat_recline_normal;
      case StopType.overnight:
        return Icons.hotel;
    }
  }
}

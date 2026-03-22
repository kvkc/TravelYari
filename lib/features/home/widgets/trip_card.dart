import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoItem(
                        Icons.place,
                        '${trip.locations.length} places',
                      ),
                      const SizedBox(width: 16),
                      if (trip.totalDistanceKm > 0)
                        _buildInfoItem(
                          Icons.route,
                          '${trip.totalDistanceKm.toStringAsFixed(0)} km',
                        ),
                      if (trip.dayPlans.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _buildInfoItem(
                          Icons.calendar_today,
                          '${trip.dayPlans.length} days',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (trip.locations.isNotEmpty)
                    Text(
                      trip.locations.map((l) => l.name).join(' → '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Updated ${_formatDate(trip.updatedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      _buildVehicleIcon(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;

    switch (trip.status) {
      case TripStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
      case TripStatus.planned:
        color = AppTheme.primaryColor;
        label = 'Planned';
        break;
      case TripStatus.inProgress:
        color = AppTheme.secondaryColor;
        label = 'In Progress';
        break;
      case TripStatus.completed:
        color = AppTheme.successColor;
        label = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleIcon() {
    IconData icon;
    switch (trip.vehicleType) {
      case VehicleType.car:
        icon = Icons.directions_car;
        break;
      case VehicleType.bike:
        icon = Icons.two_wheeler;
        break;
      case VehicleType.ev:
        icon = Icons.electric_car;
        break;
    }

    return Icon(icon, size: 20, color: Colors.grey[500]);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}

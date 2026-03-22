import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';

class TripStatsCard extends StatelessWidget {
  final Trip trip;

  const TripStatsCard({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.route,
                value: '${trip.totalDistanceKm.toStringAsFixed(0)} km',
                label: 'Total Distance',
              ),
              _buildStatItem(
                icon: Icons.timer,
                value: _formatDuration(trip.estimatedDurationMinutes),
                label: 'Drive Time',
              ),
              _buildStatItem(
                icon: Icons.calendar_today,
                value: '${trip.dayPlans.length}',
                label: 'Days',
              ),
            ],
          ),
          if (trip.dayPlans.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSmallStat(
                  Icons.place,
                  '${trip.locations.length} places',
                ),
                _buildSmallStat(
                  Icons.local_gas_station,
                  '${_countStops(trip, 'fuel')} fuel stops',
                ),
                _buildSmallStat(
                  Icons.restaurant,
                  '${_countStops(trip, 'meal')} meals',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return '${days}d ${remainingHours}h';
  }

  int _countStops(Trip trip, String type) {
    int count = 0;
    for (var day in trip.dayPlans) {
      for (var stop in day.stops) {
        if (type == 'fuel' && stop.type.name.contains('fuel')) count++;
        if (type == 'meal' && stop.type.name.contains('meal')) count++;
      }
    }
    return count;
  }
}

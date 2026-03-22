import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EmptyTripsWidget extends StatelessWidget {
  final VoidCallback onCreateTrip;

  const EmptyTripsWidget({
    super.key,
    required this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start planning your next adventure!\nAdd multiple locations and let us find the best route.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Trip'),
            ),
            const SizedBox(height: 24),
            _buildFeatureList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    return Column(
      children: [
        _buildFeatureItem(Icons.route, 'Optimized routes'),
        _buildFeatureItem(Icons.local_gas_station, 'Find petrol & EV stations'),
        _buildFeatureItem(Icons.restaurant, 'Rated restaurants'),
        _buildFeatureItem(Icons.wc, 'Clean washroom facilities'),
        _buildFeatureItem(Icons.hotel, 'Stay recommendations'),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.secondaryColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

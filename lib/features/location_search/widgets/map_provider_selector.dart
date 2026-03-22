import 'package:flutter/material.dart';

import '../../../core/services/map/unified_map_service.dart';

class MapProviderSelector extends StatelessWidget {
  final MapProvider selectedProvider;
  final Function(MapProvider) onProviderChanged;

  const MapProviderSelector({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildProviderChip(
          provider: MapProvider.google,
          label: 'Google',
          icon: Icons.map,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        _buildProviderChip(
          provider: MapProvider.mappls,
          label: 'Mappls',
          icon: Icons.explore,
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        _buildProviderChip(
          provider: MapProvider.bhuvan,
          label: 'Bhuvan',
          icon: Icons.satellite,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildProviderChip({
    required MapProvider provider,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedProvider == provider;

    return GestureDetector(
      onTap: () => onProviderChanged(provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

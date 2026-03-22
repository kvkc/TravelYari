import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/map/unified_map_service.dart';
import '../../../core/services/api_key_storage.dart';

class MapProviderSelector extends ConsumerWidget {
  final MapProvider selectedProvider;
  final Function(MapProvider) onProviderChanged;

  const MapProviderSelector({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyStatusAsync = ref.watch(apiKeyStatusProvider);

    return keyStatusAsync.when(
      data: (keyStatus) => _buildProviderChips(keyStatus),
      loading: () => _buildProviderChips({}),
      error: (_, __) => _buildProviderChips({}),
    );
  }

  Widget _buildProviderChips(Map<String, bool> keyStatus) {
    final hasGoogleKey = keyStatus['googleMaps'] == true;
    final hasMapplsKey = keyStatus['mappls'] == true &&
                         keyStatus['mapplsClientId'] == true;
    // Bhuvan doesn't need API key for basic search

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // OpenStreetMap - always available (FREE)
          _buildProviderChip(
            provider: MapProvider.openStreetMap,
            label: 'OpenStreetMap',
            icon: Icons.public,
            color: Colors.teal,
            isFree: true,
          ),
          const SizedBox(width: 8),

          // Only show other providers if they have API keys configured
          if (hasGoogleKey) ...[
            _buildProviderChip(
              provider: MapProvider.google,
              label: 'Google',
              icon: Icons.map,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
          ],
          if (hasMapplsKey) ...[
            _buildProviderChip(
              provider: MapProvider.mappls,
              label: 'Mappls',
              icon: Icons.explore,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
          ],
          // Note: Bhuvan requires API key and doesn't work on web due to CORS
          // Only show if we have other providers configured (indicates advanced user)
        ],
      ),
    );
  }

  Widget _buildProviderChip({
    required MapProvider provider,
    required String label,
    required IconData icon,
    required Color color,
    bool isFree = false,
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
            if (isFree) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FREE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

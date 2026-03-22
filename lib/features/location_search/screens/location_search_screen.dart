import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/map/unified_map_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/location.dart';
import '../widgets/location_search_bar.dart';
import '../widgets/location_result_tile.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  final String mapProvider;

  const LocationSearchScreen({
    super.key,
    this.mapProvider = 'openStreetMap',
  });

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TripLocation> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    final mapService = ref.read(unifiedMapServiceProvider);

    try {
      // Automatically search across all available providers
      // The service will use whatever works (OSM is always available)
      final results = await mapService.searchPlaces(query);
      if (mounted) {
        _searchResults = results;
      }
    } catch (e) {
      print('Search error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onLocationSelected(TripLocation location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: LocationSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_searchResults.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final location = _searchResults[index];
          return LocationResultTile(
            name: location.name,
            address: location.address ?? '',
            source: location.source,
            onTap: () => _onLocationSelected(location),
          );
        },
      );
    }

    if (!_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No locations found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            Icons.location_on,
            'Search by name',
            'Enter a place name, address, or landmark',
          ),
          _buildTipItem(
            Icons.pin_drop,
            'Use coordinates',
            'Paste coordinates like 12.9716, 77.5946',
          ),
          _buildTipItem(
            Icons.share,
            'Share from other apps',
            'Share a location from Google Maps or WhatsApp',
          ),
          _buildTipItem(
            Icons.filter_alt,
            'Multiple providers',
            'Tap the filter icon to search across all map providers',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/map/map_service_interface.dart';
import '../../../core/services/map/unified_map_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/location.dart';
import '../widgets/location_search_bar.dart';
import '../widgets/location_result_tile.dart';
import '../widgets/map_provider_selector.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  final String mapProvider;

  const LocationSearchScreen({
    super.key,
    this.mapProvider = 'google',
  });

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _predictions = [];
  List<TripLocation> _searchResults = [];
  bool _isLoading = false;
  bool _showAllProviders = false;
  MapProvider _selectedProvider = MapProvider.google;

  @override
  void initState() {
    super.initState();
    _selectedProvider = MapProvider.values.firstWhere(
      (p) => p.name == widget.mapProvider,
      orElse: () => MapProvider.google,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
        _searchResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    final mapService = ref.read(unifiedMapServiceProvider);

    try {
      if (_showAllProviders) {
        // Search across all providers
        _searchResults = await mapService.searchPlacesAllProviders(query);
        _predictions = [];
      } else {
        // Autocomplete with selected provider
        _predictions = await mapService.autocomplete(
          query,
          provider: _selectedProvider,
        );
        _searchResults = [];
      }
    } catch (e) {
      print('Search error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    setState(() => _isLoading = true);

    final mapService = ref.read(unifiedMapServiceProvider);
    final location = await mapService.getPlaceDetails(
      prediction.placeId,
      prediction.source,
    );

    setState(() => _isLoading = false);

    if (location != null && mounted) {
      Navigator.of(context).pop(location);
    }
  }

  void _onLocationSelected(TripLocation location) {
    Navigator.of(context).pop(location);
  }

  void _onProviderChanged(MapProvider provider) {
    setState(() {
      _selectedProvider = provider;
      _predictions = [];
      _searchResults = [];
    });
    if (_searchController.text.isNotEmpty) {
      _onSearchChanged(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
        actions: [
          IconButton(
            icon: Icon(
              _showAllProviders ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() {
                _showAllProviders = !_showAllProviders;
              });
              if (_searchController.text.isNotEmpty) {
                _onSearchChanged(_searchController.text);
              }
            },
            tooltip: _showAllProviders ? 'Search selected provider' : 'Search all providers',
          ),
        ],
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

          // Provider selector
          if (!_showAllProviders)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MapProviderSelector(
                selectedProvider: _selectedProvider,
                onProviderChanged: _onProviderChanged,
              ),
            ),

          const SizedBox(height: 8),

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

    if (_showAllProviders && _searchResults.isNotEmpty) {
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

    if (!_showAllProviders && _predictions.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _predictions.length,
        itemBuilder: (context, index) {
          final prediction = _predictions[index];
          return LocationResultTile(
            name: prediction.mainText,
            address: prediction.secondaryText,
            source: prediction.source,
            onTap: () => _onPredictionSelected(prediction),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/trip/trip_planner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/location.dart';
import '../widgets/location_list_item.dart';
import '../widgets/trip_preferences_sheet.dart';
import '../widgets/trip_stats_card.dart';

class TripPlanningScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const TripPlanningScreen({
    super.key,
    this.tripId,
  });

  @override
  ConsumerState<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends ConsumerState<TripPlanningScreen> {
  late Trip _trip;
  bool _isLoading = false;
  bool _isPlanning = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateTrip();
  }

  void _loadOrCreateTrip() {
    if (widget.tripId != null) {
      final savedTrip = StorageService.getTrip(widget.tripId!);
      if (savedTrip != null) {
        _trip = savedTrip;
        return;
      }
    }

    // Create new trip
    _trip = Trip(
      name: 'New Trip',
      status: TripStatus.draft,
    );
  }

  Future<void> _saveTrip() async {
    await StorageService.saveTrip(_trip);
  }

  Future<void> _addLocation() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.locationSearch,
    );

    if (result != null && result is TripLocation) {
      setState(() {
        _trip = _trip.copyWith(
          locations: [..._trip.locations, result],
        );
      });
      await _saveTrip();
    }
  }

  void _removeLocation(int index) {
    setState(() {
      final locations = List<TripLocation>.from(_trip.locations);
      locations.removeAt(index);
      _trip = _trip.copyWith(locations: locations);
    });
    _saveTrip();
  }

  void _reorderLocations(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final locations = List<TripLocation>.from(_trip.locations);
      final item = locations.removeAt(oldIndex);
      locations.insert(newIndex, item);
      _trip = _trip.copyWith(locations: locations);
    });
    _saveTrip();
  }

  Future<void> _planTrip() async {
    if (_trip.locations.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 locations to plan a trip'),
        ),
      );
      return;
    }

    setState(() => _isPlanning = true);

    try {
      final plannerService = ref.read(tripPlannerServiceProvider);
      final plannedTrip = await plannerService.generateTripPlan(
        trip: _trip,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );

      setState(() {
        _trip = plannedTrip;
        _isPlanning = false;
      });

      await _saveTrip();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip planned successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isPlanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planning failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showPreferences() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TripPreferencesSheet(
        preferences: _trip.preferences,
        vehicleType: _trip.vehicleType,
        onSave: (preferences, vehicleType) {
          setState(() {
            _trip = _trip.copyWith(
              preferences: preferences,
              vehicleType: vehicleType,
            );
          });
          _saveTrip();
        },
      ),
    );
  }

  void _viewRoute() {
    if (_trip.status == TripStatus.draft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan the trip first to view the route'),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRouter.routeView,
      arguments: {'tripId': _trip.id},
    );
  }

  void _editTripName() {
    final controller = TextEditingController(text: _trip.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter trip name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _trip = _trip.copyWith(name: controller.text);
                });
                _saveTrip();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editTripName,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _trip.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showPreferences,
            tooltip: 'Trip Preferences',
          ),
          if (_trip.status != TripStatus.draft)
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: _viewRoute,
              tooltip: 'View Route',
            ),
        ],
      ),
      body: Column(
        children: [
          // Trip stats (if planned)
          if (_trip.status != TripStatus.draft)
            TripStatsCard(trip: _trip),

          // Locations list
          Expanded(
            child: _trip.locations.isEmpty
                ? _buildEmptyLocations()
                : _buildLocationsList(),
          ),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyLocations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_location_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Add locations to your trip',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for places or share locations from other apps',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addLocation,
              icon: const Icon(Icons.add),
              label: const Text('Add Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trip.locations.length,
      onReorder: _reorderLocations,
      itemBuilder: (context, index) {
        final location = _trip.locations[index];
        return LocationListItem(
          key: ValueKey(location.id),
          location: location,
          index: index,
          isFirst: index == 0,
          isLast: index == _trip.locations.length - 1,
          onRemove: () => _removeLocation(index),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addLocation,
                icon: const Icon(Icons.add),
                label: const Text('Add Location'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPlanning ? null : _planTrip,
                icon: _isPlanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.route),
                label: Text(_isPlanning ? 'Planning...' : 'Plan Trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

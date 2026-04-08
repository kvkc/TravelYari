import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/sync/trip_sync_service.dart';
import '../../../core/services/trip/trip_planner_service.dart';
import '../../../core/services/map/unified_map_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/location.dart';
import '../widgets/location_list_item.dart';
import '../widgets/trip_preferences_sheet.dart';
import '../widgets/trip_stats_card.dart';

class TripPlanningScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final TripLocation? initialLocation;

  const TripPlanningScreen({
    super.key,
    this.tripId,
    this.initialLocation,
  });

  @override
  ConsumerState<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends ConsumerState<TripPlanningScreen> {
  late Trip _trip;
  TripLocation? _startingPoint;
  bool _isLoading = false;
  bool _isPlanning = false;
  bool _isLoadingLocation = false;
  StreamSubscription<Trip>? _remoteTripSubscription;

  @override
  void initState() {
    super.initState();
    _loadOrCreateTrip();
    _initStartingPoint();
    _listenForRemoteUpdates();
  }

  void _listenForRemoteUpdates() {
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    _remoteTripSubscription = syncService.tripUpdates.listen((updatedTrip) {
      if (updatedTrip.id == _trip.id && mounted) {
        setState(() {
          _trip = updatedTrip;
        });
      }
    });
  }

  @override
  void dispose() {
    _remoteTripSubscription?.cancel();
    super.dispose();
  }

  void _loadOrCreateTrip() {
    if (widget.tripId != null) {
      final savedTrip = StorageService.getTrip(widget.tripId!);
      if (savedTrip != null) {
        _trip = savedTrip;
        // Load starting point from trip if exists
        if (_trip.locations.isNotEmpty) {
          // Check if first location is marked as starting point
          final first = _trip.locations.first;
          if (first.metadata?['isStartingPoint'] == true) {
            _startingPoint = first;
          }
        }
        return;
      }
    }

    // Create new trip with optional initial location
    _trip = Trip(
      name: widget.initialLocation != null
          ? 'Trip to ${widget.initialLocation!.name}'
          : 'New Trip',
      status: TripStatus.draft,
      locations: widget.initialLocation != null
          ? [widget.initialLocation!]
          : [],
    );

    // Auto-save if we have an initial location
    if (widget.initialLocation != null) {
      _saveTrip();
    }
  }

  Future<void> _initStartingPoint() async {
    if (_startingPoint != null) return;

    setState(() => _isLoadingLocation = true);

    try {
      // Try to get current location
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Location timeout');
      });

      // Reverse geocode to get address
      final mapService = ref.read(unifiedMapServiceProvider);
      final location = await mapService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          // Create starting point with unique name to distinguish from destinations
          _startingPoint = TripLocation(
            name: location?.name ?? 'My Location',
            address: location?.address ?? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            latitude: position.latitude,
            longitude: position.longitude,
            source: LocationSource.manual,
            metadata: {'isStartingPoint': true},
          );
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Failed to get current location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _saveTrip() async {
    await StorageService.saveTrip(_trip);
    // Auto-sync to Firestore if trip is shared with participants
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    syncService.syncIfShared(_trip);
  }

  Future<void> _editStartingPoint() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.locationSearch,
    );

    if (result != null && result is TripLocation) {
      setState(() {
        _startingPoint = result.copyWith(
          metadata: {...?result.metadata, 'isStartingPoint': true},
        );
      });
    }
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
      await _autoOptimizeIfNeeded();
    }
  }

  void _removeLocation(int index) async {
    setState(() {
      final locations = List<TripLocation>.from(_trip.locations);
      locations.removeAt(index);
      _trip = _trip.copyWith(locations: locations);
    });
    await _saveTrip();
    await _autoOptimizeIfNeeded();
  }

  void _reorderLocations(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final locations = List<TripLocation>.from(_trip.locations);
      final item = locations.removeAt(oldIndex);
      locations.insert(newIndex, item);
      _trip = _trip.copyWith(locations: locations);
    });
    await _saveTrip();
  }

  Future<void> _autoOptimizeIfNeeded() async {
    if (!_trip.preferences.autoOptimize) return;
    if (_trip.locations.length < 2) return;
    if (_isPlanning) return;

    setState(() => _isPlanning = true);

    try {
      final plannerService = ref.read(tripPlannerServiceProvider);

      // Include starting point in planning if set
      final locationsToOptimize = _startingPoint != null
          ? [_startingPoint!, ..._trip.locations]
          : _trip.locations;

      final tripToOptimize = _trip.copyWith(locations: locationsToOptimize);

      final plannedTrip = await plannerService.generateTripPlan(
        trip: tripToOptimize,
        startDate: _trip.startDate ?? DateTime.now().add(const Duration(days: 1)),
      );

      setState(() {
        _trip = plannedTrip.copyWith(
          locations: _startingPoint != null
              ? plannedTrip.locations.skip(1).toList()
              : plannedTrip.locations,
        );
        _isPlanning = false;
      });

      await _saveTrip();
    } catch (e) {
      setState(() => _isPlanning = false);
      print('Auto-optimize failed: $e');
    }
  }

  /// Check if two locations are the same (within ~500m)
  bool _isSameLocation(TripLocation a, TripLocation b) {
    final distance = a.distanceTo(b);
    return distance < 0.5; // Less than 500 meters
  }

  Future<void> _planTrip() async {
    if (_trip.locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 1 destination to plan a trip'),
        ),
      );
      return;
    }

    setState(() => _isPlanning = true);

    try {
      final plannerService = ref.read(tripPlannerServiceProvider);

      // Build locations list, avoiding duplicates with starting point
      List<TripLocation> locationsToOptimize;
      if (_startingPoint != null) {
        // Filter out destinations that are same as starting point
        final filteredDestinations = _trip.locations.where((dest) {
          return !_isSameLocation(dest, _startingPoint!);
        }).toList();

        if (filteredDestinations.isEmpty) {
          setState(() => _isPlanning = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add destinations different from your starting point'),
              ),
            );
          }
          return;
        }

        locationsToOptimize = [_startingPoint!, ...filteredDestinations];
      } else {
        locationsToOptimize = _trip.locations;
      }

      final tripToOptimize = _trip.copyWith(locations: locationsToOptimize);

      final plannedTrip = await plannerService.generateTripPlan(
        trip: tripToOptimize,
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

          // Starting point card
          _buildStartingPointCard(),

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

  Widget _buildStartingPointCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _editStartingPoint,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Starting Point',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isLoadingLocation)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _startingPoint?.name ??
                            (_isLoadingLocation ? 'Getting current location...' : 'Tap to set starting point'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _startingPoint != null ? Colors.black87 : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_startingPoint?.address != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          _startingPoint!.address!,
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
                Icon(
                  Icons.edit_outlined,
                  color: Colors.green[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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
              'Add destinations to your trip',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for places you want to visit',
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
              label: const Text('Add Destination'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Destinations (${_trip.locations.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ),
        ),
      ],
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
                label: const Text('Add Destination'),
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

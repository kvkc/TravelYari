import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/trip/trip_planner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../../trip_planning/models/location.dart';
import '../../shared_location/shared_location_handler.dart';
import '../../shared_location/widgets/trip_selector_sheet.dart';
import '../widgets/trip_card.dart';
import '../widgets/empty_trips_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _setupSharedLocationHandler();
  }

  void _loadTrips() {
    setState(() {
      _trips = StorageService.getAllTrips();
      _trips.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  void _setupSharedLocationHandler() {
    SharedLocationHandler.setOnLocationReceived((location) {
      // Show trip selector when a location is shared from another app
      _showTripSelector(location);
    });
  }

  void _showTripSelector(TripLocation location) {
    TripSelectorSheet.show(
      context,
      location: location,
      onTripSelected: (trip) => _addLocationToTrip(trip, location),
      onCreateNewTrip: () => _createNewTripWithLocation(location),
    );
  }

  void _addLocationToTrip(Trip trip, TripLocation location) async {
    // Add location to existing trip
    var updatedTrip = trip.copyWith(
      locations: [...trip.locations, location],
    );

    // Auto-optimize if enabled and enough locations
    if (updatedTrip.preferences.autoOptimize && updatedTrip.locations.length >= 2) {
      try {
        final plannerService = ref.read(tripPlannerServiceProvider);
        updatedTrip = await plannerService.generateTripPlan(
          trip: updatedTrip,
          startDate: updatedTrip.startDate ?? DateTime.now().add(const Duration(days: 1)),
        );
      } catch (e) {
        // Silently fail - trip is still saved with new location
        print('Auto-optimize failed: $e');
      }
    }

    await StorageService.saveTrip(updatedTrip);
    _loadTrips();

    if (mounted) {
      final message = updatedTrip.preferences.autoOptimize && updatedTrip.locations.length >= 2
          ? 'Added "${location.name}" to "${trip.name}" and optimized route'
          : 'Added "${location.name}" to "${trip.name}"';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _openTrip(updatedTrip),
          ),
        ),
      );
    }
  }

  void _createNewTripWithLocation(TripLocation location) {
    Navigator.pushNamed(
      context,
      AppRouter.tripPlanning,
      arguments: {'initialLocation': location},
    ).then((_) {
      _loadTrips();
    });
  }

  void _createNewTrip() {
    Navigator.pushNamed(context, AppRouter.tripPlanning).then((_) {
      _loadTrips();
    });
  }

  void _openTrip(Trip trip) {
    Navigator.pushNamed(
      context,
      AppRouter.tripPlanning,
      arguments: {'tripId': trip.id},
    ).then((_) {
      _loadTrips();
    });
  }

  void _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete "${trip.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteTrip(trip.id);
      _loadTrips();
    }
  }

  void _joinTrip() {
    Navigator.pushNamed(context, AppRouter.joinTrip).then((_) {
      _loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Yaari'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _joinTrip,
            tooltip: 'Join Trip',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.settings);
            },
          ),
        ],
      ),
      body: _trips.isEmpty
          ? EmptyTripsWidget(onCreateTrip: _createNewTrip)
          : RefreshIndicator(
              onRefresh: () async => _loadTrips(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _trips.length,
                itemBuilder: (context, index) {
                  final trip = _trips[index];
                  return TripCard(
                    trip: trip,
                    onTap: () => _openTrip(trip),
                    onDelete: () => _deleteTrip(trip),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTrip,
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }
}

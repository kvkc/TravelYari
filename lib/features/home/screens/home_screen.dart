import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../../shared_location/shared_location_handler.dart';
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
      // When a location is shared from another app, create a new trip with it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location received: ${location.name}'),
          action: SnackBarAction(
            label: 'Add to Trip',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRouter.tripPlanning,
                arguments: {'initialLocation': location},
              );
            },
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yatra Planner'),
        actions: [
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

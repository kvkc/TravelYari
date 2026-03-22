import 'package:flutter/material.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../../trip_planning/models/location.dart';

class TripSelectorSheet extends StatefulWidget {
  final TripLocation location;
  final Function(Trip) onTripSelected;
  final VoidCallback onCreateNewTrip;

  const TripSelectorSheet({
    super.key,
    required this.location,
    required this.onTripSelected,
    required this.onCreateNewTrip,
  });

  static Future<void> show(
    BuildContext context, {
    required TripLocation location,
    required Function(Trip) onTripSelected,
    required VoidCallback onCreateNewTrip,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TripSelectorSheet(
        location: location,
        onTripSelected: onTripSelected,
        onCreateNewTrip: onCreateNewTrip,
      ),
    );
  }

  @override
  State<TripSelectorSheet> createState() => _TripSelectorSheetState();
}

class _TripSelectorSheetState extends State<TripSelectorSheet> {
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    setState(() {
      _trips = StorageService.getAllTrips();
      _trips.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Location to Trip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.location.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.location.address != null)
                                Text(
                                  widget.location.address!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Trip list or empty state
            Expanded(
              child: _trips.isEmpty
                  ? _buildEmptyState()
                  : _buildTripList(scrollController),
            ),

            // Create new trip button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCreateNewTrip();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Trip'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new trip to add this location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _buildTripItem(trip);
      },
    );
  }

  Widget _buildTripItem(Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.map,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          trip.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${trip.locations.length} locations',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          color: AppTheme.primaryColor,
        ),
        onTap: () {
          Navigator.pop(context);
          widget.onTripSelected(trip);
        },
      ),
    );
  }
}

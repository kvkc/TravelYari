import 'package:flutter/material.dart';

import '../../trip_planning/models/location.dart';

class LocationResultTile extends StatelessWidget {
  final String name;
  final String address;
  final LocationSource source;
  final VoidCallback onTap;

  const LocationResultTile({
    super.key,
    required this.name,
    required this.address,
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getSourceColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.location_on,
            color: _getSourceColor(),
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (address.isNotEmpty)
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getSourceColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getSourceLabel(),
                style: TextStyle(
                  fontSize: 10,
                  color: _getSourceColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  String _getSourceLabel() {
    switch (source) {
      case LocationSource.googleMaps:
        return 'Google Maps';
      case LocationSource.openStreetMap:
        return 'OSM';
      case LocationSource.shared:
        return 'Shared';
      case LocationSource.manual:
        return 'Manual';
    }
  }

  Color _getSourceColor() {
    switch (source) {
      case LocationSource.googleMaps:
        return Colors.blue;
      case LocationSource.openStreetMap:
        return Colors.teal;
      case LocationSource.shared:
        return Colors.purple;
      case LocationSource.manual:
        return Colors.grey;
    }
  }
}

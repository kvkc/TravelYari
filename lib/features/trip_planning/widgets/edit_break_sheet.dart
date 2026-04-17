import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/day_plan.dart';
import '../models/amenity.dart';
import '../models/location.dart';

class EditBreakSheet extends StatefulWidget {
  final PlannedStop stop;
  final Function(PlannedStop updatedStop)? onUpdate;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onRemove;

  const EditBreakSheet({
    super.key,
    required this.stop,
    this.onUpdate,
    this.onChangeLocation,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required PlannedStop stop,
    Function(PlannedStop updatedStop)? onUpdate,
    VoidCallback? onChangeLocation,
    VoidCallback? onRemove,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => EditBreakSheet(
        stop: stop,
        onUpdate: onUpdate,
        onChangeLocation: onChangeLocation,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<EditBreakSheet> createState() => _EditBreakSheetState();
}

class _EditBreakSheetState extends State<EditBreakSheet> {
  late StopType _selectedType;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.stop.type;
    _durationMinutes = widget.stop.plannedDurationMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with stop info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStopColor(_selectedType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStopIcon(_selectedType),
                    color: _getStopColor(_selectedType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stop.location.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTypeLabel(_selectedType),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStopColor(_selectedType),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Change type section
            const Text(
              'Stop Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildTypeSelector(),

            const SizedBox(height: 24),

            // Duration section
            const Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDurationSelector(),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionTile(
              icon: Icons.map_outlined,
              iconColor: Colors.blue,
              title: 'Open in Google Maps',
              subtitle: 'View location and nearby places',
              onTap: () => _openInGoogleMaps(),
            ),

            const SizedBox(height: 8),

            _buildActionTile(
              icon: Icons.location_searching,
              iconColor: AppTheme.primaryColor,
              title: 'Change Location',
              subtitle: 'Find a different place for this stop',
              onTap: widget.onChangeLocation != null
                  ? () {
                      Navigator.pop(context);
                      widget.onChangeLocation!();
                    }
                  : null,
            ),

            const SizedBox(height: 8),

            _buildActionTile(
              icon: Icons.delete_outline,
              iconColor: Colors.red,
              title: 'Remove Stop',
              subtitle: 'Delete this stop from your plan',
              onTap: widget.onRemove != null
                  ? () {
                      Navigator.pop(context);
                      widget.onRemove!();
                    }
                  : null,
            ),

            const SizedBox(height: 16),

            // Save button
            if (_hasChanges())
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      StopType.teaBreak,
      StopType.mealBreak,
      StopType.fuelStop,
      StopType.restStop,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = type == _selectedType;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStopIcon(type),
                size: 16,
                color: isSelected ? Colors.white : _getStopColor(type),
              ),
              const SizedBox(width: 6),
              Text(_getTypeLabel(type)),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedType = type;
                // Adjust duration based on type
                if (type == StopType.mealBreak && _durationMinutes < 30) {
                  _durationMinutes = 45;
                } else if (type == StopType.fuelStop && _durationMinutes > 30) {
                  _durationMinutes = 15;
                }
              });
            }
          },
          selectedColor: _getStopColor(type),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    final durations = _selectedType == StopType.mealBreak
        ? [30, 45, 60, 90]
        : _selectedType == StopType.fuelStop
            ? [10, 15, 20, 30]
            : [10, 15, 20, 30];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: durations.map((duration) {
        final isSelected = duration == _durationMinutes;
        return ChoiceChip(
          label: Text('${duration}m'),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _durationMinutes = duration);
            }
          },
          selectedColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasChanges() {
    return _selectedType != widget.stop.type ||
        _durationMinutes != widget.stop.plannedDurationMinutes;
  }

  void _saveChanges() {
    if (widget.onUpdate != null) {
      final updatedStop = widget.stop.copyWith(
        type: _selectedType,
        plannedDurationMinutes: _durationMinutes,
      );
      Navigator.pop(context);
      widget.onUpdate!(updatedStop);
    }
  }

  Future<void> _openInGoogleMaps() async {
    final location = widget.stop.location;
    final lat = location.latitude;
    final lng = location.longitude;

    // Determine search term based on stop type
    String? searchTerm;
    switch (_selectedType) {
      case StopType.teaBreak:
        searchTerm = 'cafe';
        break;
      case StopType.mealBreak:
        searchTerm = 'restaurant';
        break;
      case StopType.fuelStop:
        searchTerm = 'petrol pump';
        break;
      default:
        searchTerm = null;
    }

    // Use Google Maps URL format that positions the map at the stop location
    // Format: https://www.google.com/maps/search/QUERY/@LAT,LNG,15z
    final String url;
    if (searchTerm != null) {
      // Search for nearby places, centered at the stop location with zoom level 15
      final encodedQuery = Uri.encodeComponent(searchTerm);
      url = 'https://www.google.com/maps/search/$encodedQuery/@$lat,$lng,15z';
    } else {
      // Just navigate to the exact location
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  Color _getStopColor(StopType type) {
    switch (type) {
      case StopType.destination:
        return AppTheme.primaryColor;
      case StopType.fuelStop:
        return Colors.orange;
      case StopType.mealBreak:
        return Colors.red;
      case StopType.teaBreak:
        return Colors.brown;
      case StopType.restStop:
        return Colors.teal;
      case StopType.overnight:
        return Colors.purple;
    }
  }

  IconData _getStopIcon(StopType type) {
    switch (type) {
      case StopType.destination:
        return Icons.place;
      case StopType.fuelStop:
        return Icons.local_gas_station;
      case StopType.mealBreak:
        return Icons.restaurant;
      case StopType.teaBreak:
        return Icons.local_cafe;
      case StopType.restStop:
        return Icons.airline_seat_recline_normal;
      case StopType.overnight:
        return Icons.hotel;
    }
  }

  String _getTypeLabel(StopType type) {
    switch (type) {
      case StopType.destination:
        return 'Destination';
      case StopType.fuelStop:
        return 'Fuel Stop';
      case StopType.mealBreak:
        return 'Meal Break';
      case StopType.teaBreak:
        return 'Tea/Coffee';
      case StopType.restStop:
        return 'Rest Stop';
      case StopType.overnight:
        return 'Overnight';
    }
  }
}

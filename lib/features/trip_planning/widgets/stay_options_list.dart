import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/amenities/amenities_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/amenity.dart';
import '../models/location.dart';
import '../models/route_segment.dart';

class StayOptionsSheet extends ConsumerStatefulWidget {
  final TripLocation location;
  final Amenity? currentStay;
  final Function(Amenity) onStaySelected;

  const StayOptionsSheet({
    super.key,
    required this.location,
    this.currentStay,
    required this.onStaySelected,
  });

  static Future<Amenity?> show(
    BuildContext context, {
    required TripLocation location,
    Amenity? currentStay,
  }) {
    return showModalBottomSheet<Amenity>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StayOptionsSheet(
          location: location,
          currentStay: currentStay,
          onStaySelected: (stay) => Navigator.pop(context, stay),
        ),
      ),
    );
  }

  @override
  ConsumerState<StayOptionsSheet> createState() => _StayOptionsSheetState();
}

class _StayOptionsSheetState extends ConsumerState<StayOptionsSheet> {
  List<Amenity> _stayOptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStayOptions();
  }

  Future<void> _loadStayOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final amenitiesService = ref.read(amenitiesServiceProvider);
      final options = await amenitiesService.findStayOptions(
        location: LatLng(widget.location.latitude, widget.location.longitude),
        searchRadiusKm: 15.0,
        maxResults: 15,
        minRating: 3.0,
      );

      setState(() {
        _stayOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stay options: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Stay',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hotels near ${widget.location.name}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for hotels...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStayOptions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stayOptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hotel_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No hotels found nearby',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching in a larger area',
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _stayOptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stay = _stayOptions[index];
        final isCurrentStay = widget.currentStay?.id == stay.id ||
            (widget.currentStay?.placeId != null &&
                widget.currentStay?.placeId == stay.placeId);

        return _StayOptionCard(
          stay: stay,
          isSelected: isCurrentStay,
          onTap: () => widget.onStaySelected(stay),
          onOpenMaps: () => _openInMaps(stay),
        );
      },
    );
  }

  Future<void> _openInMaps(Amenity stay) async {
    final encodedName = Uri.encodeComponent(stay.name);
    final url = 'https://www.google.com/maps/search/?api=1'
        '&query=$encodedName'
        '&center=${stay.latitude},${stay.longitude}';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StayOptionCard extends StatelessWidget {
  final Amenity stay;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenMaps;

  const _StayOptionCard({
    required this.stay,
    required this.isSelected,
    required this.onTap,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hotel icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.hotel,
                      color: AppTheme.secondaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Hotel info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stay.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (stay.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            stay.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rating and actions row
              Row(
                children: [
                  if (stay.rating != null) ...[
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      stay.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (stay.reviewCount != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${stay.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                  if (stay.hasGoodWashroom) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.wc, size: 14, color: AppTheme.successColor),
                    const SizedBox(width: 4),
                    Text(
                      'Clean facilities',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onOpenMaps,
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

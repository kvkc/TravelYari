import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/amenities/amenities_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../../trip_planning/models/amenity.dart';
import '../../trip_planning/models/route_segment.dart';

class AmenitiesScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String amenityType;

  const AmenitiesScreen({
    super.key,
    required this.tripId,
    required this.amenityType,
  });

  @override
  ConsumerState<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends ConsumerState<AmenitiesScreen> {
  Trip? _trip;
  List<Amenity> _amenities = [];
  bool _isLoading = true;
  String _sortBy = 'distance';
  bool _showGoodWashroomsOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trip = StorageService.getTrip(widget.tripId);
    if (trip == null) return;

    setState(() {
      _trip = trip;
      _isLoading = true;
    });

    // Get amenities from route segments
    List<Amenity> amenities = [];
    for (var segment in trip.routeSegments) {
      amenities.addAll(segment.suggestedStops.where((a) {
        return a.type.name == widget.amenityType;
      }));
    }

    // If no amenities in segments, fetch new ones
    if (amenities.isEmpty && trip.routeSegments.isNotEmpty) {
      final amenitiesService = ref.read(amenitiesServiceProvider);
      final allPoints = trip.routeSegments
          .expand((s) => s.polylinePoints)
          .toList();

      if (allPoints.isNotEmpty) {
        switch (widget.amenityType) {
          case 'petrolStation':
            amenities = await amenitiesService.findPetrolStations(
              routePoints: allPoints,
            );
            break;
          case 'evStation':
            amenities = await amenitiesService.findEvStations(
              routePoints: allPoints,
            );
            break;
          case 'restaurant':
            amenities = await amenitiesService.findRestaurants(
              routePoints: allPoints,
              minRating: trip.preferences.minRestaurantRating,
              preferGoodWashrooms: trip.preferences.preferGoodWashrooms,
            );
            break;
          case 'hotel':
            final midPoint = allPoints[allPoints.length ~/ 2];
            amenities = await amenitiesService.findStayOptions(
              location: midPoint,
              minRating: trip.preferences.minHotelRating,
            );
            break;
        }
      }
    }

    setState(() {
      _amenities = amenities;
      _isLoading = false;
    });

    _sortAmenities();
  }

  void _sortAmenities() {
    setState(() {
      switch (_sortBy) {
        case 'distance':
          _amenities.sort((a, b) => a.distanceFromRoute.compareTo(b.distanceFromRoute));
          break;
        case 'rating':
          _amenities.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
        case 'washroom':
          _amenities.sort((a, b) {
            final aScore = a.washroomInfo?.overallScore ?? 0;
            final bScore = b.washroomInfo?.overallScore ?? 0;
            return bScore.compareTo(aScore);
          });
          break;
      }

      if (_showGoodWashroomsOnly) {
        _amenities = _amenities.where((a) => a.hasGoodWashroom).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _amenities.isEmpty
              ? _buildEmptyState()
              : _buildAmenitiesList(),
    );
  }

  String _getTitle() {
    switch (widget.amenityType) {
      case 'petrolStation':
        return 'Petrol Stations';
      case 'evStation':
        return 'EV Charging';
      case 'restaurant':
        return 'Restaurants';
      case 'hotel':
        return 'Hotels';
      case 'teaStall':
        return 'Tea/Coffee Stalls';
      default:
        return 'Amenities';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getAmenityIcon(),
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_getTitle().toLowerCase()} found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAmenityIcon() {
    switch (widget.amenityType) {
      case 'petrolStation':
        return Icons.local_gas_station;
      case 'evStation':
        return Icons.ev_station;
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'teaStall':
        return Icons.local_cafe;
      default:
        return Icons.place;
    }
  }

  Widget _buildAmenitiesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _amenities.length,
      itemBuilder: (context, index) {
        return _buildAmenityCard(_amenities[index]);
      },
    );
  }

  Widget _buildAmenityCard(Amenity amenity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAmenityDetails(amenity),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getAmenityIcon(),
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          amenity.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (amenity.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            amenity.address!,
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
              Row(
                children: [
                  if (amenity.rating != null) ...[
                    RatingBarIndicator(
                      rating: amenity.rating!,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      itemCount: 5,
                      itemSize: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amenity.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (amenity.reviewCount != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${amenity.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                  const Spacer(),
                  if (amenity.distanceFromRoute > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${amenity.distanceFromRoute.toStringAsFixed(1)} km off route',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
              if (amenity.washroomInfo != null) ...[
                const SizedBox(height: 8),
                _buildWashroomIndicator(amenity.washroomInfo!),
              ],
              if (!amenity.isOpen) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Currently Closed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWashroomIndicator(WashroomInfo info) {
    final score = info.overallScore;
    Color color;
    String label;

    if (score >= 4) {
      color = AppTheme.successColor;
      label = 'Excellent washroom';
    } else if (score >= 3.5) {
      color = Colors.lightGreen;
      label = 'Good washroom';
    } else if (score >= 3) {
      color = Colors.orange;
      label = 'Average washroom';
    } else {
      color = Colors.red;
      label = 'Poor washroom';
    }

    return Row(
      children: [
        Icon(Icons.wc, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (info.hasFemaleSection) ...[
          const SizedBox(width: 12),
          Icon(Icons.female, size: 14, color: Colors.pink),
          const SizedBox(width: 2),
          Text(
            'Female-friendly',
            style: TextStyle(
              fontSize: 11,
              color: Colors.pink[700],
            ),
          ),
        ],
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort & Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sort by',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildSortChip('distance', 'Distance', setModalState),
                  _buildSortChip('rating', 'Rating', setModalState),
                  _buildSortChip('washroom', 'Washroom Quality', setModalState),
                ],
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Good washrooms only'),
                subtitle: const Text('Show places with clean facilities'),
                value: _showGoodWashroomsOnly,
                onChanged: (value) {
                  setModalState(() => _showGoodWashroomsOnly = value);
                  _sortAmenities();
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String value, String label, StateSetter setModalState) {
    final isSelected = _sortBy == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => _sortBy = value);
        setState(() => _sortBy = value);
        _sortAmenities();
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  void _showAmenityDetails(Amenity amenity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              amenity.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (amenity.address != null) ...[
              const SizedBox(height: 8),
              Text(
                amenity.address!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            if (amenity.rating != null)
              Row(
                children: [
                  RatingBarIndicator(
                    rating: amenity.rating!,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    itemCount: 5,
                    itemSize: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${amenity.rating!.toStringAsFixed(1)} (${amenity.reviewCount ?? 0} reviews)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            if (amenity.washroomInfo != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Washroom Facilities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailedWashroomInfo(amenity.washroomInfo!),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Open in maps
                Navigator.pop(context);
              },
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedWashroomInfo(WashroomInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildWashroomScoreRow('Overall', info.overallScore),
            _buildWashroomScoreRow('Cleanliness', info.cleanlinessScore),
            _buildWashroomScoreRow('Female Rating', info.femaleReviewScore),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFacilityChip(
                  'Female Section',
                  info.hasFemaleSection,
                  Icons.female,
                ),
                _buildFacilityChip(
                  'Western',
                  info.hasWesternToilet,
                  Icons.chair,
                ),
                _buildFacilityChip(
                  'Indian',
                  info.hasIndianToilet,
                  Icons.airline_seat_legroom_reduced,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWashroomScoreRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: score / 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                score >= 4
                    ? AppTheme.successColor
                    : score >= 3
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityChip(String label, bool available, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: available ? AppTheme.successColor : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: available ? Colors.black : Colors.grey,
          ),
        ),
        Icon(
          available ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: available ? AppTheme.successColor : Colors.grey,
        ),
      ],
    );
  }
}

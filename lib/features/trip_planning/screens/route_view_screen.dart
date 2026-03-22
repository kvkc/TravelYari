import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/day_plan.dart';
import '../widgets/day_plan_card.dart';
import '../widgets/route_map_widget.dart';

class RouteViewScreen extends ConsumerStatefulWidget {
  final String tripId;

  const RouteViewScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<RouteViewScreen> createState() => _RouteViewScreenState();
}

class _RouteViewScreenState extends ConsumerState<RouteViewScreen>
    with SingleTickerProviderStateMixin {
  Trip? _trip;
  late TabController _tabController;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    final trip = StorageService.getTrip(widget.tripId);
    if (trip != null) {
      setState(() {
        _trip = trip;
        _tabController = TabController(
          length: trip.dayPlans.length + 1, // +1 for overview tab
          vsync: this,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip!.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Overview'),
            ...List.generate(
              _trip!.dayPlans.length,
              (i) => Tab(text: 'Day ${i + 1}'),
            ),
          ],
          onTap: (index) {
            setState(() {
              _selectedDayIndex = index > 0 ? index - 1 : 0;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareTrip,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          ...List.generate(
            _trip!.dayPlans.length,
            (i) => _buildDayTab(_trip!.dayPlans[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      children: [
        // Map showing full route
        Expanded(
          flex: 2,
          child: RouteMapWidget(
            trip: _trip!,
            showFullRoute: true,
          ),
        ),

        // Trip summary
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildDayOverviewList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.route,
                  '${_trip!.totalDistanceKm.toStringAsFixed(0)} km',
                  'Total Distance',
                ),
                _buildSummaryItem(
                  Icons.timer,
                  _formatDuration(_trip!.estimatedDurationMinutes),
                  'Drive Time',
                ),
                _buildSummaryItem(
                  Icons.calendar_today,
                  '${_trip!.dayPlans.length} days',
                  'Duration',
                ),
              ],
            ),
            const Divider(height: 32),
            _buildRouteStops(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteStops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_trip!.optimizedRoute.length, (index) {
          final location = _trip!.optimizedRoute[index];
          final isFirst = index == 0;
          final isLast = index == _trip!.optimizedRoute.length - 1;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Column(
                  children: [
                    if (!isFirst)
                      Container(
                        width: 2,
                        height: 8,
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? AppTheme.successColor
                            : isLast
                                ? AppTheme.accentColor
                                : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 8,
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayOverviewList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Day-by-Day Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_trip!.dayPlans.length, (index) {
          final day = _trip!.dayPlans[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text('Day ${index + 1}'),
              subtitle: Text(
                '${day.startLocation.name} → ${day.endLocation.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${day.totalDistanceKm.toStringAsFixed(0)} km',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${day.stops.length} stops',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              onTap: () {
                _tabController.animateTo(index + 1);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayTab(DayPlan dayPlan) {
    return Column(
      children: [
        // Map showing day's route
        Expanded(
          flex: 1,
          child: RouteMapWidget(
            trip: _trip!,
            dayPlan: dayPlan,
            showFullRoute: false,
          ),
        ),

        // Day details
        Expanded(
          flex: 2,
          child: DayPlanCard(
            dayPlan: dayPlan,
            onAmenityTap: (amenity) {
              // Navigate to amenity details
              Navigator.pushNamed(
                context,
                AppRouter.amenities,
                arguments: {
                  'tripId': _trip!.id,
                  'amenityType': amenity.type.name,
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _shareTrip() {
    // Implement trip sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing feature coming soon!')),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${mins}m';
  }
}

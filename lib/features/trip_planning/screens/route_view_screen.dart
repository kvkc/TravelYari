import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/sync/trip_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/day_plan.dart';
import '../models/amenity.dart';
import '../widgets/day_plan_card.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/share_options_sheet.dart';
import '../widgets/edit_stay_sheet.dart';
import '../../collaboration/widgets/invite_share_sheet.dart';
import '../widgets/stay_options_list.dart';
import '../widgets/edit_break_sheet.dart';

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
  StreamSubscription<Trip>? _remoteTripSubscription;

  @override
  void initState() {
    super.initState();
    _loadTrip();
    _listenForRemoteUpdates();
  }

  void _listenForRemoteUpdates() {
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    _remoteTripSubscription = syncService.tripUpdates.listen((updatedTrip) {
      if (updatedTrip.id == widget.tripId && mounted) {
        setState(() {
          _trip = updatedTrip;
          // Reinitialize tab controller if day plan count changed
          if (updatedTrip.dayPlans.length + 1 != _tabController.length) {
            _tabController.dispose();
            _tabController = TabController(
              length: updatedTrip.dayPlans.length + 1,
              vsync: this,
            );
          }
        });
      }
    });
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
    _remoteTripSubscription?.cancel();
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
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
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _openExpenses,
            tooltip: 'Expenses',
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _inviteParticipants,
            tooltip: 'Invite participants',
          ),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () => _shareDay(day),
                    tooltip: 'Share day ${index + 1}',
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
    final dayIndex = _trip!.dayPlans.indexOf(dayPlan);

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
            onShare: () => _shareDay(dayPlan),
            onStayTap: (stay) => _handleStayTap(stay, dayIndex),
            onStopEdit: (stop, stopIndex) => _handleStopEdit(stop, stopIndex, dayIndex),
          ),
        ),
      ],
    );
  }

  void _handleStayTap(Amenity stay, int dayIndex) {
    EditStaySheet.show(
      context,
      stay: stay,
      onChangeStay: () => _changeStay(dayIndex),
      onRemoveStay: () => _removeStay(dayIndex),
    );
  }

  Future<void> _changeStay(int dayIndex) async {
    final dayPlan = _trip!.dayPlans[dayIndex];
    final newStay = await StayOptionsSheet.show(
      context,
      location: dayPlan.endLocation,
      currentStay: dayPlan.stayOption,
    );

    if (newStay != null && mounted) {
      _updateDayPlanStay(dayIndex, newStay);
    }
  }

  void _removeStay(int dayIndex) {
    _updateDayPlanStay(dayIndex, null);
  }

  void _updateDayPlanStay(int dayIndex, Amenity? newStay) {
    final updatedDayPlans = List<DayPlan>.from(_trip!.dayPlans);
    updatedDayPlans[dayIndex] = updatedDayPlans[dayIndex].copyWith(
      stayOption: newStay,
      clearStayOption: newStay == null,
    );

    final updatedTrip = _trip!.copyWith(dayPlans: updatedDayPlans);
    _saveAndUpdateTrip(updatedTrip);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newStay != null ? 'Stay updated' : 'Stay removed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleStopEdit(PlannedStop stop, int stopIndex, int dayIndex) {
    EditBreakSheet.show(
      context,
      stop: stop,
      onUpdate: (updatedStop) => _updateStop(dayIndex, stopIndex, updatedStop),
      onChangeLocation: () => _changeStopLocation(dayIndex, stopIndex),
      onRemove: () => _removeStop(dayIndex, stopIndex),
    );
  }

  void _updateStop(int dayIndex, int stopIndex, PlannedStop updatedStop) {
    final updatedDayPlans = List<DayPlan>.from(_trip!.dayPlans);
    final updatedStops = List<PlannedStop>.from(updatedDayPlans[dayIndex].stops);
    updatedStops[stopIndex] = updatedStop;

    updatedDayPlans[dayIndex] = updatedDayPlans[dayIndex].copyWith(
      stops: updatedStops,
    );

    final updatedTrip = _trip!.copyWith(dayPlans: updatedDayPlans);
    _saveAndUpdateTrip(updatedTrip);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stop updated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeStopLocation(int dayIndex, int stopIndex) async {
    // Navigate to location search for the break
    final result = await Navigator.pushNamed(
      context,
      AppRouter.locationSearch,
      arguments: {'returnLocation': true},
    );

    if (result != null && result is Map && mounted) {
      final location = result['location'];
      if (location != null) {
        final currentStop = _trip!.dayPlans[dayIndex].stops[stopIndex];
        final updatedStop = currentStop.copyWith(
          location: location,
        );
        _updateStop(dayIndex, stopIndex, updatedStop);
      }
    }
  }

  void _removeStop(int dayIndex, int stopIndex) {
    final updatedDayPlans = List<DayPlan>.from(_trip!.dayPlans);
    final updatedStops = List<PlannedStop>.from(updatedDayPlans[dayIndex].stops);
    updatedStops.removeAt(stopIndex);

    updatedDayPlans[dayIndex] = updatedDayPlans[dayIndex].copyWith(
      stops: updatedStops,
    );

    final updatedTrip = _trip!.copyWith(dayPlans: updatedDayPlans);
    _saveAndUpdateTrip(updatedTrip);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stop removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAndUpdateTrip(Trip updatedTrip) async {
    await StorageService.saveTrip(updatedTrip);
    setState(() {
      _trip = updatedTrip;
    });
    // Auto-sync to Firestore if trip is shared with participants
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    syncService.syncIfShared(updatedTrip);
  }

  void _shareTrip() {
    ShareOptionsSheet.show(context, trip: _trip!);
  }

  void _inviteParticipants() {
    if (_trip == null) return;
    InviteShareSheet.show(context, _trip!);
  }

  void _openExpenses() {
    Navigator.pushNamed(
      context,
      AppRouter.expenses,
      arguments: {'trip': _trip},
    );
  }

  Future<void> _refreshFromCloud() async {
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    final refreshedTrip = await syncService.refreshTrip(_trip!.id);

    if (refreshedTrip != null && mounted) {
      setState(() {
        _trip = refreshedTrip;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip updated')),
      );
    }
  }

  void _shareDay(DayPlan dayPlan) {
    ShareOptionsSheet.show(context, trip: _trip!, dayPlan: dayPlan);
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/day_plan.dart';

/// Map widget using OpenStreetMap tiles (free, no API key required)
class RouteMapWidget extends StatefulWidget {
  final Trip trip;
  final DayPlan? dayPlan;
  final bool showFullRoute;

  const RouteMapWidget({
    super.key,
    required this.trip,
    this.dayPlan,
    required this.showFullRoute,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _buildMapElements();
  }

  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayPlan != widget.dayPlan ||
        oldWidget.showFullRoute != widget.showFullRoute ||
        oldWidget.trip.id != widget.trip.id) {
      _buildMapElements();
    }
  }

  void _buildMapElements() {
    final markers = <Marker>[];
    final polylines = <Polyline>[];
    final routePoints = <LatLng>[];

    if (widget.showFullRoute && widget.trip.optimizedRoute.isNotEmpty) {
      // Show all locations and full route
      for (int i = 0; i < widget.trip.optimizedRoute.length; i++) {
        final location = widget.trip.optimizedRoute[i];
        final point = LatLng(location.latitude, location.longitude);
        routePoints.add(point);

        markers.add(_createMarker(
          point,
          location.name,
          i == 0
              ? Colors.green
              : i == widget.trip.optimizedRoute.length - 1
                  ? Colors.red
                  : AppTheme.primaryColor,
          i == 0
              ? Icons.play_arrow
              : i == widget.trip.optimizedRoute.length - 1
                  ? Icons.flag
                  : Icons.circle,
          isNumbered: i > 0 && i < widget.trip.optimizedRoute.length - 1,
          number: i,
        ));
      }

      // Add route polylines from segments if available
      bool hasRouteData = false;
      for (var segment in widget.trip.routeSegments) {
        if (segment.polylinePoints.isNotEmpty) {
          hasRouteData = true;
          polylines.add(Polyline(
            points: segment.polylinePoints
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            color: AppTheme.primaryColor,
            strokeWidth: 4,
          ));
        }
      }

      // If no route data, draw straight lines between locations
      if (!hasRouteData && routePoints.length > 1) {
        polylines.add(Polyline(
          points: routePoints,
          color: AppTheme.primaryColor.withOpacity(0.7),
          strokeWidth: 3,
          isDotted: true,
        ));
      }
    } else if (widget.dayPlan != null) {
      // Show only day's route
      final day = widget.dayPlan!;
      final dayRoutePoints = <LatLng>[];

      final startPoint = LatLng(day.startLocation.latitude, day.startLocation.longitude);
      final endPoint = LatLng(day.endLocation.latitude, day.endLocation.longitude);

      dayRoutePoints.add(startPoint);

      markers.add(_createMarker(
        startPoint,
        'Start: ${day.startLocation.name}',
        Colors.green,
        Icons.play_arrow,
      ));

      // Add stop markers
      for (var stop in day.stops) {
        final stopPoint = LatLng(stop.location.latitude, stop.location.longitude);
        dayRoutePoints.add(stopPoint);

        if (stop.type != StopType.destination) {
          markers.add(_createMarker(
            stopPoint,
            stop.location.name,
            _getStopColor(stop.type),
            _getStopIcon(stop.type),
          ));
        }
      }

      dayRoutePoints.add(endPoint);

      markers.add(_createMarker(
        endPoint,
        'End: ${day.endLocation.name}',
        Colors.red,
        Icons.flag,
      ));

      // Draw dotted line connecting all points
      if (dayRoutePoints.length > 1) {
        polylines.add(Polyline(
          points: dayRoutePoints,
          color: AppTheme.primaryColor.withOpacity(0.7),
          strokeWidth: 3,
          isDotted: true,
        ));
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Fit bounds after map is ready
    if (_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  Marker _createMarker(
    LatLng position,
    String title,
    Color color,
    IconData icon, {
    bool isNumbered = false,
    int number = 0,
  }) {
    return Marker(
      point: position,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(title), duration: const Duration(seconds: 1)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isNumbered
                ? Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Color _getStopColor(StopType type) {
    switch (type) {
      case StopType.fuelStop:
        return Colors.orange;
      case StopType.mealBreak:
        return Colors.amber;
      case StopType.teaBreak:
        return Colors.cyan;
      case StopType.overnight:
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getStopIcon(StopType type) {
    switch (type) {
      case StopType.fuelStop:
        return Icons.local_gas_station;
      case StopType.mealBreak:
        return Icons.restaurant;
      case StopType.teaBreak:
        return Icons.coffee;
      case StopType.overnight:
        return Icons.hotel;
      default:
        return Icons.location_on;
    }
  }

  void _fitBounds() {
    if (_markers.isEmpty || !_mapReady) return;

    try {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

      for (var marker in _markers) {
        if (marker.point.latitude < minLat) minLat = marker.point.latitude;
        if (marker.point.latitude > maxLat) maxLat = marker.point.latitude;
        if (marker.point.longitude < minLng) minLng = marker.point.longitude;
        if (marker.point.longitude > maxLng) maxLng = marker.point.longitude;
      }

      // Add padding
      final latPadding = (maxLat - minLat) * 0.15;
      final lngPadding = (maxLng - minLng) * 0.15;

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat - latPadding, minLng - lngPadding),
            LatLng(maxLat + latPadding, maxLng + lngPadding),
          ),
          padding: const EdgeInsets.all(30),
        ),
      );
    } catch (e) {
      print('Fit bounds error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate initial camera position
    LatLng initialPosition;
    double initialZoom = 6;

    if (widget.showFullRoute && widget.trip.optimizedRoute.isNotEmpty) {
      // Center on midpoint of route
      double avgLat = 0, avgLng = 0;
      for (var loc in widget.trip.optimizedRoute) {
        avgLat += loc.latitude;
        avgLng += loc.longitude;
      }
      avgLat /= widget.trip.optimizedRoute.length;
      avgLng /= widget.trip.optimizedRoute.length;
      initialPosition = LatLng(avgLat, avgLng);
    } else if (widget.dayPlan != null) {
      initialPosition = LatLng(
        (widget.dayPlan!.startLocation.latitude + widget.dayPlan!.endLocation.latitude) / 2,
        (widget.dayPlan!.startLocation.longitude + widget.dayPlan!.endLocation.longitude) / 2,
      );
    } else {
      // Default to India center
      initialPosition = LatLng(20.5937, 78.9629);
      initialZoom = 5;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialPosition,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 18,
        onMapReady: () {
          _mapReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
        },
      ),
      children: [
        // OpenStreetMap tile layer - using HTTPS with CORS-friendly headers
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.yatraplanner.app',
          maxZoom: 19,
          tileProvider: NetworkTileProvider(),
        ),
        // Route polylines
        if (_polylines.isNotEmpty)
          PolylineLayer(polylines: _polylines),
        // Markers
        if (_markers.isNotEmpty)
          MarkerLayer(markers: _markers),
        // Attribution (small, bottom left)
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
      ],
    );
  }
}

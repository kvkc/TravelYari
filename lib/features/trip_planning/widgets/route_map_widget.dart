import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/day_plan.dart';
import '../models/route_segment.dart' as model;

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
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _buildMapElements();
  }

  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayPlan != widget.dayPlan ||
        oldWidget.showFullRoute != widget.showFullRoute) {
      _buildMapElements();
    }
  }

  void _buildMapElements() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (widget.showFullRoute) {
      // Show all locations and full route
      for (int i = 0; i < widget.trip.optimizedRoute.length; i++) {
        final location = widget.trip.optimizedRoute[i];
        markers.add(Marker(
          markerId: MarkerId(location.id),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(title: location.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0
                ? BitmapDescriptor.hueGreen
                : i == widget.trip.optimizedRoute.length - 1
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueAzure,
          ),
        ));
      }

      // Add route polyline
      for (var segment in widget.trip.routeSegments) {
        if (segment.polylinePoints.isNotEmpty) {
          polylines.add(Polyline(
            polylineId: PolylineId('${segment.start.id}_${segment.end.id}'),
            points: segment.polylinePoints
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            color: AppTheme.primaryColor,
            width: 4,
          ));
        }
      }
    } else if (widget.dayPlan != null) {
      // Show only day's route
      final day = widget.dayPlan!;

      markers.add(Marker(
        markerId: MarkerId('start_${day.dayNumber}'),
        position: LatLng(day.startLocation.latitude, day.startLocation.longitude),
        infoWindow: InfoWindow(title: 'Start: ${day.startLocation.name}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));

      markers.add(Marker(
        markerId: MarkerId('end_${day.dayNumber}'),
        position: LatLng(day.endLocation.latitude, day.endLocation.longitude),
        infoWindow: InfoWindow(title: 'End: ${day.endLocation.name}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      // Add stop markers
      for (var stop in day.stops) {
        if (stop.type != StopType.destination) {
          markers.add(Marker(
            markerId: MarkerId(stop.location.id),
            position: LatLng(stop.location.latitude, stop.location.longitude),
            infoWindow: InfoWindow(title: stop.location.name),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(stop.type),
            ),
          ));
        }
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Fit bounds to show all markers
    _fitBounds();
  }

  double _getMarkerHue(StopType type) {
    switch (type) {
      case StopType.fuelStop:
        return BitmapDescriptor.hueOrange;
      case StopType.mealBreak:
        return BitmapDescriptor.hueYellow;
      case StopType.teaBreak:
        return BitmapDescriptor.hueCyan;
      case StopType.overnight:
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  void _fitBounds() {
    if (_mapController == null || _markers.isEmpty) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate initial camera position
    LatLng initialPosition;
    if (widget.showFullRoute && widget.trip.optimizedRoute.isNotEmpty) {
      final first = widget.trip.optimizedRoute.first;
      initialPosition = LatLng(first.latitude, first.longitude);
    } else if (widget.dayPlan != null) {
      initialPosition = LatLng(
        widget.dayPlan!.startLocation.latitude,
        widget.dayPlan!.startLocation.longitude,
      );
    } else {
      // Default to India center
      initialPosition = const LatLng(20.5937, 78.9629);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 10,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitBounds();
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}

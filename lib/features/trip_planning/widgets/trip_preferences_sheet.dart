import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';

class TripPreferencesSheet extends StatefulWidget {
  final TripPreferences preferences;
  final VehicleType vehicleType;
  final List<Vehicle> vehicles;
  final Function(TripPreferences, VehicleType, List<Vehicle>) onSave;

  const TripPreferencesSheet({
    super.key,
    required this.preferences,
    required this.vehicleType,
    this.vehicles = const [],
    required this.onSave,
  });

  @override
  State<TripPreferencesSheet> createState() => _TripPreferencesSheetState();
}

class _TripPreferencesSheetState extends State<TripPreferencesSheet> {
  late TripPreferences _preferences;
  late VehicleType _vehicleType;
  late List<Vehicle> _vehicles;

  // Controllers for vehicle input
  final _tankCapacityController = TextEditingController();
  final _mileageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences;
    _vehicleType = widget.vehicleType;
    _vehicles = List.from(widget.vehicles);

    // Initialize with first vehicle or defaults
    if (_vehicles.isNotEmpty) {
      _tankCapacityController.text = _vehicles.first.tankCapacityLiters.toStringAsFixed(0);
      _mileageController.text = _vehicles.first.mileage.toStringAsFixed(1);
    } else {
      // Set defaults based on vehicle type
      _setDefaultVehicleValues();
    }
  }

  void _setDefaultVehicleValues() {
    switch (_vehicleType) {
      case VehicleType.car:
        _tankCapacityController.text = '45';
        _mileageController.text = '15';
        break;
      case VehicleType.bike:
        _tankCapacityController.text = '15';
        _mileageController.text = '40';
        break;
      case VehicleType.ev:
        _tankCapacityController.text = '50'; // kWh
        _mileageController.text = '6'; // km/kWh
        break;
    }
  }

  @override
  void dispose() {
    _tankCapacityController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  void _updateVehicleFromInputs() {
    final tankCapacity = double.tryParse(_tankCapacityController.text) ?? 45;
    final mileage = double.tryParse(_mileageController.text) ?? 15;

    final fuelType = _vehicleType == VehicleType.ev
        ? FuelType.electric
        : FuelType.petrol;

    final vehicle = Vehicle(
      name: _vehicleType == VehicleType.ev ? 'My EV' :
            _vehicleType == VehicleType.bike ? 'My Bike' : 'My Car',
      fuelType: fuelType,
      tankCapacityLiters: tankCapacity,
      mileage: mileage,
    );

    _vehicles = [vehicle];
  }

  double get _calculatedRange {
    final tankCapacity = double.tryParse(_tankCapacityController.text) ?? 45;
    final mileage = double.tryParse(_mileageController.text) ?? 15;
    return tankCapacity * mileage;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Preferences',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _updateVehicleFromInputs();
                      widget.onSave(_preferences, _vehicleType, _vehicles);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Vehicle Type'),
                  _buildVehicleSelector(),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Vehicle Details'),
                  _buildVehicleDetails(),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Driving Preferences'),
                  _buildSlider(
                    label: 'Max daily distance',
                    value: _preferences.maxDailyDistanceKm,
                    min: 200,
                    max: 700,
                    suffix: 'km',
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(maxDailyDistanceKm: v);
                    }),
                  ),
                  _buildSlider(
                    label: 'Break interval',
                    value: _preferences.breakIntervalKm,
                    min: 50,
                    max: 200,
                    suffix: 'km',
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(breakIntervalKm: v);
                    }),
                  ),
                  _buildSlider(
                    label: 'Break duration',
                    value: _preferences.breakDurationMinutes.toDouble(),
                    min: 5,
                    max: 30,
                    suffix: 'min',
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(breakDurationMinutes: v.round());
                    }),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Find Along Route'),
                  _buildSwitch(
                    label: 'Petrol stations',
                    subtitle: 'Find fuel stops along your route',
                    value: _preferences.findPetrolStations,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(findPetrolStations: v);
                    }),
                  ),
                  _buildSwitch(
                    label: 'EV charging stations',
                    subtitle: 'Find electric vehicle charging points',
                    value: _preferences.findEvStations,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(findEvStations: v);
                    }),
                  ),
                  _buildSwitch(
                    label: 'Restaurants',
                    subtitle: 'Find places to eat with good ratings',
                    value: _preferences.findRestaurants,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(findRestaurants: v);
                    }),
                  ),
                  if (_preferences.findRestaurants)
                    _buildSlider(
                      label: 'Minimum restaurant rating',
                      value: _preferences.minRestaurantRating,
                      min: 3.0,
                      max: 4.5,
                      divisions: 6,
                      suffix: '',
                      onChanged: (v) => setState(() {
                        _preferences = _preferences.copyWith(minRestaurantRating: v);
                      }),
                    ),
                  _buildSwitch(
                    label: 'Stay options',
                    subtitle: 'Find hotels for overnight stays',
                    value: _preferences.findStayOptions,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(findStayOptions: v);
                    }),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Route Optimization'),
                  _buildSwitch(
                    label: 'Auto-optimize route',
                    subtitle: 'Automatically find the best route when locations change',
                    value: _preferences.autoOptimize,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(autoOptimize: v);
                    }),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Special Preferences'),
                  _buildSwitch(
                    label: 'Prefer good washrooms',
                    subtitle: 'Prioritize stops with clean facilities (especially for female travelers)',
                    value: _preferences.preferGoodWashrooms,
                    onChanged: (v) => setState(() {
                      _preferences = _preferences.copyWith(preferGoodWashrooms: v);
                    }),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Row(
      children: [
        _buildVehicleOption(VehicleType.car, Icons.directions_car, 'Car'),
        const SizedBox(width: 12),
        _buildVehicleOption(VehicleType.bike, Icons.two_wheeler, 'Bike'),
        const SizedBox(width: 12),
        _buildVehicleOption(VehicleType.ev, Icons.electric_car, 'EV'),
      ],
    );
  }

  Widget _buildVehicleDetails() {
    final isEV = _vehicleType == VehicleType.ev;
    final tankLabel = isEV ? 'Battery capacity (kWh)' : 'Tank capacity (L)';
    final mileageLabel = isEV ? 'Efficiency (km/kWh)' : 'Mileage (km/L)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tankCapacityController,
                    decoration: InputDecoration(
                      labelText: tankLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mileageController,
                    decoration: InputDecoration(
                      labelText: mileageLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_gas_station, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated range: ${_calculatedRange.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fuel stops will be planned based on your vehicle range (with 15% safety margin)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleOption(VehicleType type, IconData icon, String label) {
    final isSelected = _vehicleType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _vehicleType = type;
            // Auto-enable EV stations for EV vehicles
            if (type == VehicleType.ev) {
              _preferences = _preferences.copyWith(findEvStations: true);
            }
            // Update default values for the new vehicle type
            _setDefaultVehicleValues();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required Function(double) onChanged,
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                suffix.isEmpty
                    ? value.toStringAsFixed(1)
                    : '${value.toStringAsFixed(0)} $suffix',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(label),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

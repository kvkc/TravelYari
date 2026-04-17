import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';

class VehicleManagementSheet extends StatefulWidget {
  final Trip trip;
  final String? currentUserId;
  final Function(List<Vehicle>) onSave;

  const VehicleManagementSheet({
    super.key,
    required this.trip,
    this.currentUserId,
    required this.onSave,
  });

  @override
  State<VehicleManagementSheet> createState() => _VehicleManagementSheetState();
}

class _VehicleManagementSheetState extends State<VehicleManagementSheet> {
  late List<Vehicle> _vehicles;

  @override
  void initState() {
    super.initState();
    _vehicles = List.from(widget.trip.vehicles);
  }

  bool get _isOwner => widget.currentUserId == widget.trip.ownerId || widget.trip.ownerId == null;

  String? get _currentDeviceId => StorageService.getSetting<String>('device_id');

  bool _canEditVehicle(Vehicle vehicle) {
    // Owner can edit any vehicle
    if (_isOwner) return true;
    // Participant can edit their own vehicle
    return vehicle.participantId == widget.currentUserId ||
           vehicle.participantId == _currentDeviceId;
  }

  Vehicle? get _limitingVehicle {
    if (_vehicles.isEmpty) return null;
    return _vehicles.reduce((a, b) => a.safeRange < b.safeRange ? a : b);
  }

  void _addVehicle({String? forParticipantId}) {
    _showVehicleEditor(
      null,
      forParticipantId: forParticipantId ?? widget.currentUserId ?? _currentDeviceId,
    );
  }

  void _editVehicle(Vehicle vehicle) {
    if (!_canEditVehicle(vehicle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own vehicle')),
      );
      return;
    }
    _showVehicleEditor(vehicle);
  }

  void _deleteVehicle(Vehicle vehicle) {
    if (!_canEditVehicle(vehicle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only remove your own vehicle')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: Text('Remove "${vehicle.name}" from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _vehicles.removeWhere((v) => v.id == vehicle.id);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showVehicleEditor(Vehicle? existing, {String? forParticipantId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => VehicleEditorSheet(
        vehicle: existing,
        participants: widget.trip.participants,
        forParticipantId: forParticipantId ?? existing?.participantId,
        isOwner: _isOwner,
        onSave: (vehicle) {
          setState(() {
            if (existing != null) {
              final index = _vehicles.indexWhere((v) => v.id == existing.id);
              if (index >= 0) {
                _vehicles[index] = vehicle;
              }
            } else {
              _vehicles.add(vehicle);
            }
          });
        },
      ),
    );
  }

  String _getParticipantName(String? participantId) {
    if (participantId == null) return 'Unknown';

    // Check if it's the owner
    if (participantId == widget.trip.ownerId) {
      final owner = widget.trip.participants.where((p) => p.userId == participantId).firstOrNull;
      return owner?.name ?? 'Trip Owner';
    }

    // Find participant by userId or device ID
    final participant = widget.trip.participants.where(
      (p) => p.userId == participantId || p.id == participantId
    ).firstOrNull;

    return participant?.name ?? 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final limiting = _limitingVehicle;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                    'Trip Vehicles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onSave(_vehicles);
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

            // Limiting vehicle info
            if (limiting != null && _vehicles.length > 1)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fuel stops based on "${limiting.name}" (${limiting.safeRange.toStringAsFixed(0)} km safe range)',
                        style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // Vehicle list
            Expanded(
              child: _vehicles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        final isLimiting = limiting?.id == vehicle.id;
                        final canEdit = _canEditVehicle(vehicle);

                        return _buildVehicleCard(vehicle, isLimiting, canEdit);
                      },
                    ),
            ),

            // Add vehicle button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addVehicle(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Vehicle'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No vehicles added',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your vehicle to get accurate fuel stop planning',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle, bool isLimiting, bool canEdit) {
    final fuelIcon = vehicle.isElectric ? Icons.ev_station : Icons.local_gas_station;
    final participantName = _getParticipantName(vehicle.participantId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLimiting
            ? BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: canEdit ? () => _editVehicle(vehicle) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Vehicle icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (vehicle.isElectric ? Colors.green : AppTheme.primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vehicle.isElectric ? Icons.electric_car : Icons.directions_car,
                  color: vehicle.isElectric ? Colors.green : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),

              // Vehicle details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (isLimiting) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIMITING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      participantName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(fuelIcon, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${vehicle.tankCapacityLiters.toStringAsFixed(0)} ${vehicle.fuelUnitLabel}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.speed, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${vehicle.mileage.toStringAsFixed(1)} ${vehicle.mileageUnitLabel}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Range and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${vehicle.safeRange.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isLimiting ? Colors.orange : AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'safe range',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _editVehicle(vehicle),
                          child: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _deleteVehicle(vehicle),
                          child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editor for a single vehicle
class VehicleEditorSheet extends StatefulWidget {
  final Vehicle? vehicle;
  final List<TripParticipant> participants;
  final String? forParticipantId;
  final bool isOwner;
  final Function(Vehicle) onSave;

  const VehicleEditorSheet({
    super.key,
    this.vehicle,
    required this.participants,
    this.forParticipantId,
    required this.isOwner,
    required this.onSave,
  });

  @override
  State<VehicleEditorSheet> createState() => _VehicleEditorSheetState();
}

class _VehicleEditorSheetState extends State<VehicleEditorSheet> {
  final _nameController = TextEditingController();
  final _tankController = TextEditingController();
  final _mileageController = TextEditingController();

  late FuelType _fuelType;
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();

    if (widget.vehicle != null) {
      _nameController.text = widget.vehicle!.name;
      _tankController.text = widget.vehicle!.tankCapacityLiters.toStringAsFixed(0);
      _mileageController.text = widget.vehicle!.mileage.toStringAsFixed(1);
      _fuelType = widget.vehicle!.fuelType;
      _selectedParticipantId = widget.vehicle!.participantId;
    } else {
      _nameController.text = 'My Car';
      _tankController.text = '45';
      _mileageController.text = '15';
      _fuelType = FuelType.petrol;
      _selectedParticipantId = widget.forParticipantId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tankController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  double get _calculatedRange {
    final tank = double.tryParse(_tankController.text) ?? 0;
    final mileage = double.tryParse(_mileageController.text) ?? 0;
    final range = tank * mileage;
    final safeRange = (range * 0.85 - 35).clamp(50.0, range * 0.85);
    return safeRange.toDouble();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vehicle name')),
      );
      return;
    }

    final tank = double.tryParse(_tankController.text);
    final mileage = double.tryParse(_mileageController.text);

    if (tank == null || tank <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid tank capacity')),
      );
      return;
    }

    if (mileage == null || mileage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid mileage')),
      );
      return;
    }

    final vehicle = Vehicle(
      id: widget.vehicle?.id,
      name: name,
      fuelType: _fuelType,
      tankCapacityLiters: tank,
      mileage: mileage,
      participantId: _selectedParticipantId,
    );

    widget.onSave(vehicle);
    Navigator.pop(context);
  }

  void _setDefaults(FuelType type) {
    switch (type) {
      case FuelType.petrol:
      case FuelType.diesel:
        _tankController.text = '45';
        _mileageController.text = '15';
        break;
      case FuelType.electric:
        _tankController.text = '50';
        _mileageController.text = '6';
        break;
      case FuelType.cng:
        _tankController.text = '10';
        _mileageController.text = '25';
        break;
      case FuelType.hybrid:
        _tankController.text = '40';
        _mileageController.text = '20';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEV = _fuelType == FuelType.electric;
    final tankLabel = isEV ? 'Battery (kWh)' : 'Tank (L)';
    final mileageLabel = isEV ? 'km/kWh' : 'km/L';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Name',
                hintText: 'e.g., My Swift, Dad\'s Innova',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Fuel type selector
            const Text('Fuel Type', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: FuelType.values.map((type) {
                final isSelected = _fuelType == type;
                return ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _fuelType = type;
                      _setDefaults(type);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Tank and mileage
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tankController,
                    decoration: InputDecoration(
                      labelText: tankLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calculated range
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
                    'Safe range: ${_calculatedRange.toStringAsFixed(0)} km',
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
              'Includes 15% reserve + 35km buffer for safety',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            // Owner selector (only for trip owner)
            if (widget.isOwner && widget.participants.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Vehicle Owner', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _selectedParticipantId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...widget.participants.map((p) => DropdownMenuItem(
                    value: p.userId ?? p.id,
                    child: Text(p.name ?? 'Member'),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedParticipantId = value);
                },
              ),
            ],

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(widget.vehicle == null ? 'Add Vehicle' : 'Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

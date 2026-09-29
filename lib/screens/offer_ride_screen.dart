import 'package:flutter/material.dart';
import '../../models/corridor_model.dart';
import '../../models/geocoding_result.dart';
import '../../models/route_result.dart';
import '../../services/route_preview_store.dart';
import '../../services/route_service.dart';
import '../../services/routing_service.dart';
import '../../services/ride_service.dart';
import '../../utils/ride_fare.dart';
import 'navigation/main_navigation_shell.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _capacityController = TextEditingController(text: '1');
  DateTime? _selectedDateTime;
  String _selectedVehicleType = 'bike';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  List<CorridorModel> _corridors = const [];
  CorridorModel? _selectedCorridor;
  HubModel? _selectedOriginHub;
  HubModel? _selectedDestinationHub;
  bool _loadingRoutes = true;
  bool _returningFromVit = false;
  bool _routeLoading = false;
  String? _routeError;
  RouteResult? _routePreview;
  int _routeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadCorridors();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    ++_routeRequestId;
    super.dispose();
  }

  Future<void> _loadCorridors() async {
    try {
      final corridors = await RouteService.listCorridors();
      if (!mounted) return;
      setState(() {
        _corridors = corridors;
        _selectedCorridor = corridors.isEmpty ? null : corridors.first;
        _selectMorningDefaults();
        _loadingRoutes = false;
      });
      _updateRoutePreview();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRoutes = false);
        _updateRoutePreview();
      }
    }
  }

  void _selectMorningDefaults() {
    final corridor = _selectedCorridor;
    if (corridor == null || corridor.hubs.length < 2) return;
    _selectedOriginHub = corridor.hubs.first;
    _selectedDestinationHub = corridor.vitHub ?? corridor.hubs.last;
    _originController.text = _selectedOriginHub!.name;
    _destinationController.text = _selectedDestinationHub!.name;
  }

  void _selectEveningDefaults() {
    final corridor = _selectedCorridor;
    if (corridor == null || corridor.hubs.length < 2) return;
    _selectedOriginHub = corridor.vitHub ?? corridor.hubs.last;
    _selectedDestinationHub = corridor.hubs.first;
    _originController.text = _selectedOriginHub!.name;
    _destinationController.text = _selectedDestinationHub!.name;
  }

  void _selectDirection(bool returning) {
    _returningFromVit = returning;
    if (returning) {
      _selectEveningDefaults();
    } else {
      _selectMorningDefaults();
    }
  }

  Future<void> _updateRoutePreview() async {
    final origin = _selectedOriginHub;
    final destination = _selectedDestinationHub;
    if (origin == null ||
        destination == null ||
        origin.latitude == 0 ||
        origin.longitude == 0 ||
        destination.latitude == 0 ||
        destination.longitude == 0) {
      ++_routeRequestId;
      RoutePreviewStore.instance.clear();
      if (mounted) {
        setState(() {
          _routePreview = null;
          _routeLoading = false;
          _routeError = null;
        });
      }
      return;
    }

    final requestId = ++_routeRequestId;
    RoutePreviewStore.instance.clear();
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _routePreview = null;
    });
    try {
      final route = await RoutingService.getDrivingRoute(
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );
      if (!mounted || requestId != _routeRequestId) return;
      final routeOrigin = GeocodingResult(
        placeId: origin.id,
        displayName: origin.name,
        latitude: origin.latitude,
        longitude: origin.longitude,
        type: 'hub',
      );
      final routeDestination = GeocodingResult(
        placeId: destination.id,
        displayName: destination.name,
        latitude: destination.latitude,
        longitude: destination.longitude,
        type: 'hub',
      );
      RoutePreviewStore.instance.setPreview(
        route: route,
        origin: routeOrigin,
        destination: routeDestination,
      );
      setState(() {
        _routePreview = route;
        _routeLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return;
      RoutePreviewStore.instance.clear();
      setState(() {
        _routeError = 'Could not calculate road route: $error';
        _routeLoading = false;
      });
    }
  }

  Future<void> _submitOffer() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Prepare data for backend
        final rideData = {
          'originName': _originController.text.trim(),
          'destName': _destinationController.text.trim(),
          'departureTime': (_selectedDateTime ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'totalSeats': int.parse(_capacityController.text.trim()),
          'vehicleType': _selectedVehicleType,
          'notes': _notesController.text.trim(),
          // Optional fields with defaults
          'originAddress': '',
          'originLat': 0.0,
          'originLng': 0.0,
          'destAddress': '',
          'destLat': 0.0,
          'destLng': 0.0,
          'waypoints': [],
          'helmetProvided': true,
          'contribution': 0.0,
          if (_selectedCorridor != null) 'corridorId': _selectedCorridor!.id,
          if (_selectedOriginHub != null) 'originHubId': _selectedOriginHub!.id,
          if (_selectedDestinationHub != null)
            'destinationHubId': _selectedDestinationHub!.id,
        };

        // Call the service to create the ride
        final createdRide = await RideService.offerRide(rideData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride offered successfully!')),
          );
          if (widget.embeddedInShell) {
            _originController.clear();
            _destinationController.clear();
            _notesController.clear();
            MainNavigationShell.switchTab(context, 1);
          } else {
            Navigator.pop(context, createdRide);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to offer ride: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (selectedDate == null) return;
    if (!mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (selectedTime == null) return;

    if (mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Ride'),
        automaticallyImplyLeading: !widget.embeddedInShell,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingRoutes)
                const LinearProgressIndicator()
              else if (_corridors.isNotEmpty) ...[
                DropdownButtonFormField<CorridorModel>(
                  value: _selectedCorridor,
                  decoration: const InputDecoration(
                    labelText: 'VIT commute corridor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alt_route),
                  ),
                  items: _corridors
                      .map(
                        (corridor) => DropdownMenuItem(
                          value: corridor,
                          child: Text(corridor.name),
                        ),
                      )
                      .toList(),
                  onChanged: (corridor) {
                    if (corridor == null) return;
                    setState(() {
                      _selectedCorridor = corridor;
                      _selectMorningDefaults();
                    });
                    _updateRoutePreview();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Select hubs in the same direction. VIT College is always one endpoint.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('To VIT')),
                    ButtonSegment(value: true, label: Text('From VIT')),
                  ],
                  selected: {_returningFromVit},
                  onSelectionChanged: (selection) {
                    setState(() => _selectDirection(selection.first));
                    _updateRoutePreview();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HubModel>(
                  value: _selectedOriginHub,
                  decoration: const InputDecoration(
                    labelText: 'Pickup / origin hub',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.trip_origin),
                  ),
                  items: _selectedCorridor!.hubs
                      .map(
                        (hub) =>
                            DropdownMenuItem(value: hub, child: Text(hub.name)),
                      )
                      .toList(),
                  onChanged: (hub) {
                    if (hub == null) return;
                    setState(() {
                      _selectedOriginHub = hub;
                      _originController.text = hub.name;
                    });
                    _updateRoutePreview();
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HubModel>(
                  value: _selectedDestinationHub,
                  decoration: const InputDecoration(
                    labelText: 'Destination hub',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: _selectedCorridor!.hubs
                      .map(
                        (hub) =>
                            DropdownMenuItem(value: hub, child: Text(hub.name)),
                      )
                      .toList(),
                  onChanged: (hub) {
                    if (hub == null) return;
                    setState(() {
                      _selectedDestinationHub = hub;
                      _destinationController.text = hub.name;
                    });
                    _updateRoutePreview();
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _originController,
                readOnly: _corridors.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'Origin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter origin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _destinationController,
                readOnly: _corridors.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter destination';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_routeLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Calculating road distance and fare…'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_routePreview != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Road distance: ${_routePreview!.formattedDistance}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated fare: ${formatRideFare(_routePreview!.distanceMeters)} per seat (₹5/km)',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated driving time: ${_routePreview!.formattedDuration}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The route is shown on the Home map.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_routeError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_routeError!),
                  ),
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date and Time',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDateTime == null
                        ? 'Select date and time'
                        : '${_selectedDateTime!.toLocal()}'.split('.')[0],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity (Seats)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  final capacity = int.tryParse(value?.trim() ?? '');
                  if (capacity == null || capacity < 1) {
                    return 'Enter at least 1 seat';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.two_wheeler),
                ),
                items: const ['bike', 'scooty']
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type[0].toUpperCase() + type.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOffer,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Offer Ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

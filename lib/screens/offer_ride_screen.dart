import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/geocoding_result.dart';
import '../../models/route_result.dart';
import '../../services/geocoding_service.dart';
import '../../services/route_preview_store.dart';
import '../../services/routing_service.dart';
import '../../services/ride_service.dart';
import '../../utils/ride_fare.dart';
import 'map/ride_location_picker_screen.dart';
import 'map/ride_route_preview_map.dart';
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
  String _passengerGenderPreference = 'any';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  GeocodingResult? _originPlace;
  GeocodingResult? _destinationPlace;
  bool _locatingCurrentPosition = true;
  String? _currentLocationError;
  bool _routeLoading = false;
  String? _routeError;
  List<RouteResult>? _routePreview;
  int _selectedRouteIndex = 0;
  GeocodingResult? _viaPlace;
  int _routeRequestId = 0;
  int _currentLocationRequestId = 0;

  RouteResult? get _selectedRoute {
    final routes = _routePreview;
    if (routes == null ||
        _selectedRouteIndex < 0 ||
        _selectedRouteIndex >= routes.length) {
      return null;
    }
    return routes[_selectedRouteIndex];
  }

  @override
  void initState() {
    super.initState();
    _useCurrentLocation();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    ++_routeRequestId;
    ++_currentLocationRequestId;
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final requestId = ++_currentLocationRequestId;
    setState(() {
      _locatingCurrentPosition = true;
      _currentLocationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Location services are turned off. Enable them or choose the start location on the map.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Allow access or choose the start location on the map.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is blocked in device settings. Enable it or choose the start location on the map.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted || requestId != _currentLocationRequestId) return;

      final place = await GeocodingService.reverse(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted || requestId != _currentLocationRequestId) return;

      final currentPlace = GeocodingResult(
        placeId: place.placeId,
        displayName: place.displayName,
        latitude: position.latitude,
        longitude: position.longitude,
        type: place.type,
      );
      setState(() {
        _originPlace = currentPlace;
        _originController.text = currentPlace.displayName;
        _locatingCurrentPosition = false;
      });
      await _updateRoutePreview();
    } catch (error) {
      if (!mounted || requestId != _currentLocationRequestId) return;
      setState(() {
        _locatingCurrentPosition = false;
        _currentLocationError =
            'Could not use your current location: ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _updateRoutePreview() async {
    final origin = _originPlace;
    final destination = _destinationPlace;
    if (origin == null || destination == null) {
      ++_routeRequestId;
      RoutePreviewStore.instance.clear();
      if (mounted) {
        setState(() {
          _routePreview = null;
          _routeLoading = false;
          _routeError = null;
          _selectedRouteIndex = 0;
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
      _selectedRouteIndex = 0;
    });
    try {
      final routes = await RoutingService.getDrivingRoutes(
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
        viaLatitude: _viaPlace?.latitude,
        viaLongitude: _viaPlace?.longitude,
      );
      if (!mounted || requestId != _routeRequestId || routes.isEmpty) return;
      RoutePreviewStore.instance.setPreview(
        route: routes.first,
        origin: origin,
        destination: destination,
      );
      setState(() {
        _routePreview = routes;
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

  void _selectRoute(int routeIndex) {
    final routes = _routePreview;
    if (routes == null || routeIndex < 0 || routeIndex >= routes.length) return;
    setState(() => _selectedRouteIndex = routeIndex);
    final origin = _originPlace;
    final destination = _destinationPlace;
    if (origin != null && destination != null) {
      RoutePreviewStore.instance.setPreview(
        route: routes[routeIndex],
        origin: origin,
        destination: destination,
      );
    }
  }

  Future<void> _chooseLocation({required bool origin}) async {
    if (origin) {
      ++_currentLocationRequestId;
      setState(() => _locatingCurrentPosition = false);
    }
    final initialPlace = origin ? _originPlace : _destinationPlace;
    final place = await Navigator.push<GeocodingResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RideLocationPickerScreen(initialPlace: initialPlace),
      ),
    );
    if (!mounted || place == null) return;
    setState(() {
      if (origin) {
        _originPlace = place;
        _originController.text = place.displayName;
        _currentLocationError = null;
      } else {
        _destinationPlace = place;
        _destinationController.text = place.displayName;
      }
    });
    await _updateRoutePreview();
  }

  Future<void> _chooseViaPoint() async {
    final place = await Navigator.push<GeocodingResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RideLocationPickerScreen(initialPlace: _viaPlace),
      ),
    );
    if (!mounted || place == null) return;
    setState(() => _viaPlace = place);
    await _updateRoutePreview();
  }

  Future<void> _submitOffer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_originPlace == null || _destinationPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a start and destination on the map.'),
        ),
      );
      return;
    }
    if (_selectedRoute == null || _routeLoading || _routeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wait for a valid route preview before offering the ride.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final origin = _originPlace!;
      final destination = _destinationPlace!;
      final rideData = {
        'originName': origin.displayName,
        'destName': destination.displayName,
        'departureTime': (_selectedDateTime ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'totalSeats': int.parse(_capacityController.text.trim()),
        'vehicleType': _selectedVehicleType,
        'passengerGenderPreference': _passengerGenderPreference,
        'notes': _notesController.text.trim(),
        'originAddress': origin.displayName,
        'originLat': origin.latitude,
        'originLng': origin.longitude,
        'destAddress': destination.displayName,
        'destLat': destination.latitude,
        'destLng': destination.longitude,
        'waypoints': [],
        'viaPoints': [
          if (_viaPlace != null)
            {
              'latitude': _viaPlace!.latitude,
              'longitude': _viaPlace!.longitude,
            },
        ],
        'selectedRouteIndex': _selectedRouteIndex,
        'helmetProvided': true,
        'contribution': 0.0,
      };

      final createdRide = await RideService.offerRide(rideData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride offered successfully!')),
      );
      if (widget.embeddedInShell) {
        _originController.clear();
        _destinationController.clear();
        _notesController.clear();
        setState(() {
          _originPlace = null;
          _destinationPlace = null;
          _routePreview = null;
          _routeError = null;
          _selectedRouteIndex = 0;
          _viaPlace = null;
        });
        RoutePreviewStore.instance.clear();
        MainNavigationShell.switchTab(context, 1);
      } else {
        Navigator.pop(context, createdRide);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to offer ride: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
              if (_locatingCurrentPosition)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text('Getting your current location…')),
                    ],
                  ),
                ),
              if (_currentLocationError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentLocationError!),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _useCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Try current location again'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextFormField(
                controller: _originController,
                readOnly: true,
                onTap: () => _chooseLocation(origin: true),
                decoration: const InputDecoration(
                  labelText: 'Start location',
                  helperText:
                      'Prefilled from your current location. Tap to adjust.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trip_origin),
                  suffixIcon: Icon(Icons.map_outlined),
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
                readOnly: true,
                onTap: () => _chooseLocation(origin: false),
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  helperText: 'Search for a place, then confirm its map pin.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                  suffixIcon: Icon(Icons.map_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter destination';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _routeLoading ? null : _chooseViaPoint,
                icon: const Icon(Icons.add_road),
                label: Text(
                  _viaPlace == null
                      ? 'Add a via point (optional)'
                      : 'Via: ${_viaPlace!.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_viaPlace != null)
                TextButton.icon(
                  onPressed: _routeLoading
                      ? null
                      : () {
                          setState(() => _viaPlace = null);
                          _updateRoutePreview();
                        },
                  icon: const Icon(Icons.close),
                  label: const Text('Remove via point'),
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
                          'Route ${_selectedRouteIndex + 1} of ${_routePreview!.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Road distance: ${_selectedRoute!.formattedDistance}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated fare: ${formatRideFare(_selectedRoute!.distanceMeters)} per seat (₹5/km)',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated driving time: ${_selectedRoute!.formattedDuration}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _routePreview!.length == 1
                              ? 'Only one route was returned. Add a via point to request another route.'
                              : 'Tap a different route line on the map to select it.',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Start'),
                            SizedBox(width: 16),
                            Icon(Icons.circle, size: 10, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Destination'),
                            if (_viaPlace != null) ...[
                              SizedBox(width: 16),
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: Colors.deepOrange,
                              ),
                              SizedBox(width: 4),
                              Text('Via point'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: RideRoutePreviewMap(
                            key: ValueKey(_routeRequestId),
                            routes: _routePreview!,
                            selectedRouteIndex: _selectedRouteIndex,
                            onRouteSelected: _selectRoute,
                            origin: _originPlace!,
                            destination: _destinationPlace!,
                            viaPoint: _viaPlace,
                          ),
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
              DropdownButtonFormField<String>(
                value: _passengerGenderPreference,
                decoration: const InputDecoration(
                  labelText: 'Passenger gender preference',
                  helperText: 'Only compatible seekers can request this ride.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('Any gender')),
                  DropdownMenuItem(value: 'female', child: Text('Women')),
                  DropdownMenuItem(value: 'male', child: Text('Men')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _passengerGenderPreference = value);
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

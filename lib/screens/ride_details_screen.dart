import 'package:flutter/material.dart';
import '../components/components.dart';
import '../models/geocoding_result.dart';
import '../models/ride_model.dart';
import '../models/route_result.dart';
import '../services/booking_service.dart';
import '../services/ride_service.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/ride_fare.dart';
import 'map/ride_route_preview_map.dart';
import 'map/ride_route_point_picker_screen.dart';
import 'rides/my_rides_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  const RideDetailsScreen({super.key, required this.ride});

  final RideModel ride;

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late RideModel _ride;
  bool _isLoadingDetails = false;

  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _noteController = TextEditingController();

  GeocodingResult? _pickupPlace;
  GeocodingResult? _dropPlace;
  List<List<double>> _routeCoordinates = const [];
  String? _routeLoadError;
  bool _isLoadingRoute = false;
  double? _farePerSeat;
  String? _fareLoadError;
  bool _isLoadingFare = false;
  int _fareRequestId = 0;
  int _seatsToBook = 1;
  bool _isSubmittingBooking = false;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _routeCoordinates = _ride.routeCoordinates;
    _pickupController.text = _ride.originName;
    _dropController.text = _ride.destName;
    _pickupPlace = _endpointPlace(
      _ride.originName,
      _ride.originLat,
      _ride.originLng,
      'pickup',
    );
    _dropPlace = _endpointPlace(
      _ride.destName,
      _ride.destLat,
      _ride.destLng,
      'drop-off',
    );
    _fetchFreshDetails();
    _refreshBookingFare();
  }

  GeocodingResult? _endpointPlace(
    String name,
    double latitude,
    double longitude,
    String type,
  ) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }
    return GeocodingResult(
      placeId: 'ride-${_ride.id}-$type',
      displayName: name,
      latitude: latitude,
      longitude: longitude,
      type: type,
    );
  }

  bool get _canSelectRoutePoints => _routeCoordinates.length >= 2;

  Future<void> _chooseRoutePoint({required bool pickup}) async {
    if (!_canSelectRoutePoints) return;
    final selectedPlace = await Navigator.push<GeocodingResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RideRoutePointPickerScreen(
          routeCoordinates: _routeCoordinates,
          pointLabel: pickup ? 'pickup' : 'drop-off',
          initialPlace: pickup ? _pickupPlace : _dropPlace,
        ),
      ),
    );
    if (!mounted || selectedPlace == null) return;
    setState(() {
      if (pickup) {
        _pickupPlace = selectedPlace;
        _pickupController.text = selectedPlace.displayName;
      } else {
        _dropPlace = selectedPlace;
        _dropController.text = selectedPlace.displayName;
      }
    });
    _refreshBookingFare();
  }

  Future<void> _refreshBookingFare() async {
    final requestId = ++_fareRequestId;
    final pickup = _pickupPlace;
    final dropoff = _dropPlace;
    if (pickup == null || dropoff == null) {
      setState(() {
        _farePerSeat = null;
        _fareLoadError = null;
        _isLoadingFare = false;
      });
      return;
    }

    setState(() {
      _farePerSeat = null;
      _fareLoadError = null;
      _isLoadingFare = true;
    });
    try {
      final route = await RoutingService.getDrivingRoute(
        originLatitude: pickup.latitude,
        originLongitude: pickup.longitude,
        destinationLatitude: dropoff.latitude,
        destinationLongitude: dropoff.longitude,
      );
      if (!mounted || requestId != _fareRequestId) return;
      setState(() {
        _farePerSeat = estimateRideFare(route.distanceMeters);
        _isLoadingFare = false;
      });
    } catch (error) {
      if (!mounted || requestId != _fareRequestId) return;
      setState(() {
        _fareLoadError =
            'Could not calculate the fare for these points: $error';
        _isLoadingFare = false;
      });
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchFreshDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    try {
      final freshRide = await RideService.getRideDetail(_ride.id);
      if (mounted) {
        setState(() {
          _ride = freshRide;
          _routeCoordinates = freshRide.routeCoordinates;
          _routeLoadError = null;
          if (_pickupController.text.isEmpty) {
            _pickupController.text = freshRide.originName;
          }
          if (_dropController.text.isEmpty) {
            _dropController.text = freshRide.destName;
          }
        });
        if (_routeCoordinates.length < 2) {
          await _loadRouteFromEndpoints(freshRide);
        }
      }
    } catch (_) {
      if (mounted && _routeCoordinates.length < 2) {
        await _loadRouteFromEndpoints(_ride);
      }
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _loadRouteFromEndpoints(RideModel ride) async {
    if (!_hasValidRideEndpoints(ride)) {
      if (mounted) {
        setState(() {
          _routeLoadError =
              'This ride has no saved route or valid start and destination coordinates.';
        });
      }
      return;
    }
    setState(() {
      _isLoadingRoute = true;
      _routeLoadError = null;
    });
    try {
      final route = await RoutingService.getDrivingRoute(
        originLatitude: ride.originLat,
        originLongitude: ride.originLng,
        destinationLatitude: ride.destLat,
        destinationLongitude: ride.destLng,
      );
      if (!mounted || _ride.id != ride.id) return;
      setState(() {
        _routeCoordinates = route.coordinates;
        _routeLoadError = null;
      });
    } catch (error) {
      if (!mounted || _ride.id != ride.id) return;
      setState(() {
        _routeLoadError = 'Could not load the route map: $error';
      });
    } finally {
      if (mounted && _ride.id == ride.id) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  bool _hasValidRideEndpoints(RideModel ride) =>
      ride.originLat.isFinite &&
      ride.originLng.isFinite &&
      ride.destLat.isFinite &&
      ride.destLng.isFinite &&
      ride.originLat >= -90 &&
      ride.originLat <= 90 &&
      ride.destLat >= -90 &&
      ride.destLat <= 90 &&
      ride.originLng >= -180 &&
      ride.originLng <= 180 &&
      ride.destLng >= -180 &&
      ride.destLng <= 180 &&
      !(ride.originLat == 0 && ride.originLng == 0) &&
      !(ride.destLat == 0 && ride.destLng == 0) &&
      !(ride.originLat == ride.destLat && ride.originLng == ride.destLng);

  Future<void> _sendBookingRequest() async {
    if (_isLoadingFare) {
      _showBookingError('Please wait while your route fare is calculated.');
      return;
    }
    if (_farePerSeat == null) {
      _showBookingError(
        _fareLoadError ?? 'The fare for your selected route is unavailable.',
      );
      return;
    }
    if (_isLoadingRoute) {
      _showBookingError('Please wait while the biker’s route map loads.');
      return;
    }
    if (!_canSelectRoutePoints) {
      _showBookingError(
        _routeLoadError ??
            'The biker’s route map could not be loaded, so pickup and drop-off points cannot be verified.',
      );
      return;
    }
    if (_pickupPlace == null || _dropPlace == null) {
      _showBookingError(
        'Choose both your pickup and drop-off points on the biker’s route.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_ride.availableSeats < _seatsToBook) {
      _showBookingError('This ride no longer has enough available seats.');
      await _fetchFreshDetails();
      return;
    }

    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    final note = _noteController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify both pickup and drop-off locations'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmittingBooking = true);

    try {
      final booking = await BookingService.requestBooking(
        rideId: _ride.id,
        pickupName: pickup,
        dropName: drop,
        seatsRequested: _seatsToBook,
        passengerNote: note.isNotEmpty ? note : null,
        pickupLat: _pickupPlace?.latitude ?? 0,
        pickupLng: _pickupPlace?.longitude ?? 0,
        dropLat: _dropPlace?.latitude ?? 0,
        dropLng: _dropPlace?.longitude ?? 0,
      );

      if (!mounted) return;

      _showBookingSuccessDialog(booking.id);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().toLowerCase();
      _showBookingError(
        message.contains('only 0 seat') || message.contains('not enough seats')
            ? 'This ride is full. Please choose another ride.'
            : 'Failed to send booking request: $e',
      );
      if (message.contains('only ') || message.contains('not enough seats')) {
        await _fetchFreshDetails();
      }
    } finally {
      if (mounted) setState(() => _isSubmittingBooking = false);
    }
  }

  void _showBookingError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showBookingSuccessDialog(String bookingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        contentPadding: const EdgeInsets.all(AppSpacing.xl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.secondaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.secondary,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Request Sent! 🚀',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your lift request for $_seatsToBook seat(s) has been sent to ${_ride.driver?.name ?? 'the biker'}. You will receive a notification and verification OTP once approved.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                text: 'View in My Bookings',
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRidesScreen(initialTabIndex: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context); // Return to previous screen
              },
              child: const Text('Back to Rides'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build Screen UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasSeats = _ride.availableSeats > 0;
    final totalCalculatedFare = _farePerSeat == null
        ? null
        : _farePerSeat! * _seatsToBook;
    final driver = _ride.driver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Ride Details',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_isLoadingDetails)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          AppSpacing.md,
          AppSpacing.marginMobile,
          100, // Space for sticky bottom bar
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Driver Profile & Vehicle Specs Card ───────────────────
              _buildDriverProfileCard(driver),

              const SizedBox(height: AppSpacing.md),
              _buildPassengerGenderPreferenceCard(),

              const SizedBox(height: AppSpacing.md),

              // ── 2. Route Timeline Card ───────────────────────────────────
              _buildRouteTimelineCard(),

              const SizedBox(height: AppSpacing.md),
              _buildBikerRouteMapCard(),

              const SizedBox(height: AppSpacing.md),

              // ── 3. Vehicle & Safety Features ─────────────────────────────
              _buildVehicleAndSafetyCard(),

              if (_ride.bookings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildCoPassengersCard(),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── 5. Booking Request Customization Form ────────────────────
              Text(
                'CUSTOMIZE YOUR REQUEST',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildBookingRequestForm(hasSeats),
            ],
          ),
        ),
      ),

      // ── Sticky Bottom Booking Action Bar ─────────────────────────────────
      bottomSheet: _buildStickyBottomBar(hasSeats, totalCalculatedFare),
    );
  }

  Widget _buildBikerRouteMapCard() {
    final routeCoordinates = _routeCoordinates;
    final hasRoute =
        routeCoordinates.length >= 2 &&
        routeCoordinates.every(
          (point) =>
              point.length >= 2 &&
              point[0] >= -180 &&
              point[0] <= 180 &&
              point[1] >= -90 &&
              point[1] <= 90,
        );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Biker’s route',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_isLoadingRoute)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasRoute)
            SizedBox(
              height: 240,
              child: RideRoutePreviewMap(
                key: ValueKey('ride-route-${_ride.id}-${_ride.updatedAt}'),
                routes: [
                  RouteResult(
                    distanceMeters: 0,
                    durationSeconds: 0,
                    coordinates: routeCoordinates,
                  ),
                ],
                selectedRouteIndex: 0,
                onRouteSelected: (_) {},
                origin: GeocodingResult(
                  placeId: 'ride-${_ride.id}-origin',
                  displayName: _ride.originName,
                  latitude: _ride.originLat,
                  longitude: _ride.originLng,
                  type: 'origin',
                ),
                destination: GeocodingResult(
                  placeId: 'ride-${_ride.id}-destination',
                  displayName: _ride.destName,
                  latitude: _ride.destLat,
                  longitude: _ride.destLng,
                  type: 'destination',
                ),
                selectable: false,
              ),
            )
          else
            Text(
              _routeLoadError ??
                  'The biker’s saved route is not available for this ride.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  // ── Driver Profile Card ───────────────────────────────────────────────────
  Widget _buildDriverProfileCard(dynamic driver) {
    final driverName = driver?.name.isNotEmpty == true
        ? driver!.name
        : 'Campus Biker';
    final ratingAvg = driver?.ratingAvg ?? 5.0;
    final ratingCount = driver?.ratingCount ?? 0;
    final isVerified = driver?.isVerified ?? true;
    final college = driver?.college ?? '';
    final rollNumber = driver?.rollNumber ?? '';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              driverName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        driverName,
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                if (college.isNotEmpty || rollNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      college,
                      rollNumber,
                    ].where((value) => value.isNotEmpty).join(' • '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (driver?.phone.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    driver!.phone,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      ratingAvg.toStringAsFixed(1),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ratingCount > 0)
                      Text(
                        ' ($ratingCount review${ratingCount == 1 ? '' : 's'})',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Biker',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerGenderPreferenceCard() {
    final preference = switch (_ride.passengerGenderPreference) {
      'female' => 'Women',
      'male' => 'Men',
      'other' => 'Other',
      _ => 'Any gender',
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.people_outline, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passenger preference',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  preference,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Route Timeline Card ───────────────────────────────────────────────────
  Widget _buildRouteTimelineCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDepartureDateTime(_ride.departureTime),
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              AppStatusBadge(
                status: _ride.availableSeats > 0
                    ? RideStatusType.available
                    : RideStatusType.cancelled,
                customLabel: _ride.availableSeats > 0
                    ? '${_ride.availableSeats} Seats Open'
                    : 'Fully Booked',
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),

          // Origin & Destination Timeline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  Container(width: 2, height: 40, color: AppColors.border),
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ride.originName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_ride.originAddress.isNotEmpty)
                      Text(
                        _ride.originAddress,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      _ride.destName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_ride.destAddress.isNotEmpty)
                      Text(
                        _ride.destAddress,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_ride.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.radiusSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Biker note: "${_ride.notes}"',
                      style: AppTypography.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Vehicle & Safety Card ─────────────────────────────────────────────────
  Widget _buildVehicleAndSafetyCard() {
    final vehicleModel = _ride.driver?.vehicleModel.isNotEmpty ?? false
        ? _ride.driver!.vehicleModel
        : _ride.vehicleType;
    final vehiclePlate = _ride.driver?.vehiclePlate ?? '';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.two_wheeler_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Vehicle & Safety Specs',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildSpecTile(
                  'Vehicle',
                  vehicleModel,
                  Icons.commute_rounded,
                ),
              ),
              if (vehiclePlate.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildSpecTile(
                    'Plate',
                    vehiclePlate,
                    Icons.badge_outlined,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildSpecTile(
                  'Helmet Provided',
                  _ride.helmetProvided ? 'Yes (Included)' : 'Bring your own',
                  Icons.sports_motorsports_rounded,
                  isPositive: _ride.helmetProvided,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSpecTile(
                  'Full route / seat',
                  _ride.contribution > 0
                      ? '₹${_ride.contribution.toStringAsFixed(2)}'
                      : 'Free',
                  Icons.payments_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile(
    String title,
    String value,
    IconData icon, {
    bool? isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.radiusSm,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isPositive == true ? AppColors.secondary : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPositive == true
                        ? AppColors.secondary
                        : AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Co-Passengers Card ────────────────────────────────────────────────────
  Widget _buildCoPassengersCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Co-Passengers on Board (${_ride.bookings.length})',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ride.bookings.map((booking) {
              final name = booking.passenger?.name ?? 'Passenger';
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: AppColors.primaryTint,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text('$name (${booking.seatsRequested} seat)'),
                backgroundColor: AppColors.surfaceContainerLow,
                side: const BorderSide(color: AppColors.border),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Booking Request Form ──────────────────────────────────────────────────
  Widget _buildBookingRequestForm(bool hasSeats) {
    if (!hasSeats) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorTint,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              color: AppColors.error,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No Seats Available',
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'This ride is fully booked. Check other scheduled rides or coordinate an auto pool.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pickup Location
          AppTextField(
            controller: _pickupController,
            label: 'Your Pickup Point',
            hintText: _canSelectRoutePoints
                ? 'Tap to select your pickup on the biker’s route'
                : 'e.g. Library Front Steps',
            helperText: _canSelectRoutePoints
                ? 'Choose a point on the blue route on the map.'
                : _isLoadingRoute
                ? 'Loading the biker’s route map…'
                : 'Booking is unavailable because no valid route map could be loaded.',
            prefixIcon: const Icon(
              Icons.radio_button_checked,
              color: AppColors.primary,
              size: 18,
            ),
            suffixIcon: _canSelectRoutePoints
                ? const Icon(Icons.map_outlined)
                : null,
            readOnly: true,
            enabled: _canSelectRoutePoints,
            onTap: _canSelectRoutePoints
                ? () => _chooseRoutePoint(pickup: true)
                : null,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter pickup point'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Drop-off Location
          AppTextField(
            controller: _dropController,
            label: 'Your Drop-off Point',
            hintText: _canSelectRoutePoints
                ? 'Tap to select your drop-off on the biker’s route'
                : 'e.g. Metro Gate 2',
            helperText: _canSelectRoutePoints
                ? 'Choose a point on the same route on the map.'
                : _isLoadingRoute
                ? 'Loading the biker’s route map…'
                : 'Booking is unavailable because no valid route map could be loaded.',
            prefixIcon: const Icon(
              Icons.location_on,
              color: AppColors.secondary,
              size: 18,
            ),
            suffixIcon: _canSelectRoutePoints
                ? const Icon(Icons.map_outlined)
                : null,
            readOnly: true,
            enabled: _canSelectRoutePoints,
            onTap: _canSelectRoutePoints
                ? () => _chooseRoutePoint(pickup: false)
                : null,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter drop point'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Seat Quantity Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seats Needed',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_ride.availableSeats} seat(s) remaining on this pool',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _seatsToBook > 1
                          ? () => setState(() => _seatsToBook--)
                          : null,
                    ),
                    Text(
                      '$_seatsToBook',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _seatsToBook < _ride.availableSeats
                          ? () => setState(() => _seatsToBook++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fare for your selected route',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isLoadingFare)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Calculating route fare…'),
                    ],
                  )
                else if (_fareLoadError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fareLoadError!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshBookingFare,
                        child: const Text('Retry fare calculation'),
                      ),
                    ],
                  )
                else if (_farePerSeat != null)
                  Text(
                    '₹${_farePerSeat!.toStringAsFixed(2)} per seat · '
                    '₹${(_farePerSeat! * _seatsToBook).toStringAsFixed(2)} '
                    'for $_seatsToBook seat(s)',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Note to Driver
          AppTextField(
            controller: _noteController,
            label: 'Note to Driver (Optional)',
            hintText: 'e.g. I have a medium backpack, wearing blue jacket.',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Safety Disclaimer
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verification OTP will be generated upon driver acceptance for your safety.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky Bottom Bar ─────────────────────────────────────────────────────
  Widget _buildStickyBottomBar(bool hasSeats, double? totalFare) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL CONTRIBUTION',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _isLoadingFare
                      ? 'Calculating…'
                      : totalFare == null
                      ? 'Unavailable'
                      : '₹${totalFare.toStringAsFixed(2)}',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: totalFare == null || _isLoadingFare
                        ? AppColors.onSurfaceVariant
                        : totalFare > 0
                        ? AppColors.onSurface
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppPrimaryButton(
                text: hasSeats ? 'Request Lift ($_seatsToBook)' : 'Ride Full',
                icon: Icons.hail_rounded,
                isLoading: _isSubmittingBooking,
                onPressed: hasSeats && !_isLoadingFare && _farePerSeat != null
                    ? _sendBookingRequest
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDepartureDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        localDt.year == now.year &&
        localDt.month == now.month &&
        localDt.day == now.day;
    final isTomorrow =
        localDt.year == now.year &&
        localDt.month == now.month &&
        localDt.day == now.day + 1;

    final hour = localDt.hour > 12
        ? localDt.hour - 12
        : (localDt.hour == 0 ? 12 : localDt.hour);
    final period = localDt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = localDt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minuteStr $period';

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    return '${localDt.day}/${localDt.month}/${localDt.year}, $timeStr';
  }
}

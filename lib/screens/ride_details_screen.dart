import 'package:flutter/material.dart';
import '../components/components.dart';
import '../models/ride_model.dart';
import '../services/booking_service.dart';
import '../services/ride_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
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

  int _seatsToBook = 1;
  bool _isSubmittingBooking = false;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _pickupController.text = _ride.originName;
    _dropController.text = _ride.destName;
    _fetchFreshDetails();
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
          if (_pickupController.text.isEmpty) {
            _pickupController.text = freshRide.originName;
          }
          if (_dropController.text.isEmpty) {
            _dropController.text = freshRide.destName;
          }
        });
      }
    } catch (_) {
      // Retain existing widget.ride if fetch fails
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _sendBookingRequest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      );

      if (!mounted) return;

      _showBookingSuccessDialog(booking.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send booking request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingBooking = false);
    }
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
              'Your lift request for $_seatsToBook seat(s) has been sent to ${_ride.driver?.name ?? 'the driver'}. You will receive a notification and verification OTP once approved.',
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
    final totalCalculatedFare = _ride.contribution * _seatsToBook;
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

              // ── 2. Route Timeline Card ───────────────────────────────────
              _buildRouteTimelineCard(),

              const SizedBox(height: AppSpacing.md),

              // ── 3. Vehicle & Safety Features ─────────────────────────────
              _buildVehicleAndSafetyCard(),

              // ── 4. Accepted Co-Passengers (if any) ───────────────────────
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

  // ── Driver Profile Card ───────────────────────────────────────────────────
  Widget _buildDriverProfileCard(dynamic driver) {
    final driverName = (driver?.name.isNotEmpty ?? false)
        ? driver!.name
        : 'Student Driver';
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
                    ].where((s) => s.isNotEmpty).join(' • '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      'Driver',
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
                      'Driver note: "${_ride.notes}"',
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
                  'Rate / Seat',
                  _ride.contribution > 0
                      ? '₹${_ride.contribution.toStringAsFixed(0)}'
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
            hintText: 'e.g. Library Front Steps',
            prefixIcon: const Icon(
              Icons.radio_button_checked,
              color: AppColors.primary,
              size: 18,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter pickup point'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Drop-off Location
          AppTextField(
            controller: _dropController,
            label: 'Your Drop-off Point',
            hintText: 'e.g. Metro Gate 2',
            prefixIcon: const Icon(
              Icons.location_on,
              color: AppColors.secondary,
              size: 18,
            ),
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
  Widget _buildStickyBottomBar(bool hasSeats, double totalFare) {
    return Container(
      color: AppColors.surface,
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
                  totalFare > 0
                      ? '₹${totalFare.toStringAsFixed(0)}'
                      : 'Free Ride',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: totalFare > 0
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
                onPressed: hasSeats ? _sendBookingRequest : null,
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

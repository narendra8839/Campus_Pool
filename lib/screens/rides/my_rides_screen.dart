import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/booking_model.dart';
import '../../models/ride_model.dart';
import '../../services/booking_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../find_rides_screen.dart';
import '../offer_ride_screen.dart';
import '../reviews/post_ride_review_screen.dart';
import 'driver_request_queue_screen.dart';

enum RideFilter { all, active, past }

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key, this.initialTabIndex = 0});

  /// 0 = Driver (Offered), 1 = Passenger (Bookings)
  final int initialTabIndex;

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RideFilter _selectedFilter = RideFilter.all;

  bool _loadingDriverRides = false;
  bool _loadingPassengerBookings = false;
  String? _driverError;
  String? _passengerError;

  List<RideModel> _driverRides = [];
  List<BookingModel> _passengerBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_fetchDriverRides(), _fetchPassengerBookings()]);
  }

  Future<void> _fetchDriverRides() async {
    setState(() {
      _loadingDriverRides = true;
      _driverError = null;
    });

    try {
      final rides = await RideService.getMyRides();
      if (mounted) {
        setState(() {
          _driverRides = rides;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driverError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDriverRides = false;
        });
      }
    }
  }

  Future<void> _fetchPassengerBookings() async {
    setState(() {
      _loadingPassengerBookings = true;
      _passengerError = null;
    });

    try {
      final bookings = await BookingService.listUserBookings();
      if (mounted) {
        setState(() {
          _passengerBookings = bookings;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _passengerError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPassengerBookings = false;
        });
      }
    }
  }

  // ── Filter Helpers ────────────────────────────────────────────────────────
  List<RideModel> get _filteredDriverRides {
    return _driverRides.where((r) {
      final isCompletedOrCancelled =
          r.status == 'COMPLETED' || r.status == 'CANCELLED';
      if (_selectedFilter == RideFilter.active) {
        return !isCompletedOrCancelled;
      } else if (_selectedFilter == RideFilter.past) {
        return isCompletedOrCancelled;
      }
      return true;
    }).toList();
  }

  List<BookingModel> get _filteredPassengerBookings {
    return _passengerBookings.where((b) {
      final isCompletedOrCancelled =
          b.status == 'COMPLETED' ||
          b.status == 'CANCELLED' ||
          b.status == 'REJECTED';
      if (_selectedFilter == RideFilter.active) {
        return !isCompletedOrCancelled;
      } else if (_selectedFilter == RideFilter.past) {
        return isCompletedOrCancelled;
      }
      return true;
    }).toList();
  }

  // ── Driver Actions ────────────────────────────────────────────────────────
  Future<void> _updateRideStatus(RideModel ride, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text(
          newStatus == 'ONGOING'
              ? 'Start Ride?'
              : newStatus == 'COMPLETED'
              ? 'Complete Ride?'
              : 'Cancel Ride?',
          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          newStatus == 'ONGOING'
              ? 'Mark this ride as ongoing. Passengers will be notified.'
              : newStatus == 'COMPLETED'
              ? 'Mark this ride as completed? This will finalize all accepted passenger lifts.'
              : 'Are you sure you want to cancel this ride? All passenger bookings will be cancelled.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'CANCELLED'
                  ? AppColors.error
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newStatus == 'ONGOING'
                  ? 'Start'
                  : newStatus == 'COMPLETED'
                  ? 'Complete'
                  : 'Cancel Ride',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (newStatus == 'CANCELLED') {
        await RideService.cancelRide(ride.id);
      } else {
        await RideService.updateRideStatus(ride.id, newStatus);
      }

      if (!mounted) return;
      final actionText = switch (newStatus) {
        'ONGOING' => 'started successfully',
        'COMPLETED' => 'completed successfully',
        'CANCELLED' => 'cancelled successfully',
        _ => 'updated successfully',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride $actionText'),
          backgroundColor: AppColors.secondary,
        ),
      );
      _fetchDriverRides();
    } catch (e) {
      if (!mounted) return;
      final actionText = switch (newStatus) {
        'ONGOING' => 'start ride',
        'COMPLETED' => 'complete ride',
        'CANCELLED' => 'cancel ride',
        _ => 'update ride',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $actionText: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _respondToBooking(BookingModel booking, String newStatus) async {
    try {
      await BookingService.respondToBookingRequest(booking.id, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking request ${newStatus.toLowerCase()}!'),
          backgroundColor: newStatus == 'ACCEPTED'
              ? AppColors.secondary
              : AppColors.error,
        ),
      );
      _fetchDriverRides();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to respond: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Passenger Actions ─────────────────────────────────────────────────────
  Future<void> _cancelPassengerBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel your lift request? The driver will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BookingService.cancelBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: AppColors.secondary,
        ),
      );
      _fetchPassengerBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel booking: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showRatingModal(BookingModel booking) async {
    final ride = booking.ride;
    if (ride == null || ride.driverId.isEmpty) return;
    await _openReview(
      rideId: booking.rideId,
      revieweeId: ride.driverId,
      revieweeName: ride.driver?.name ?? 'your driver',
    );
  }

  Future<void> _openReview({
    required String rideId,
    required String revieweeId,
    required String revieweeName,
  }) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostRideReviewScreen(
          rideId: rideId,
          revieweeId: revieweeId,
          revieweeName: revieweeName,
        ),
      ),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for sharing your feedback!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _showPassengerRequestsSheet(RideModel ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bookings = ride.bookings;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passenger Requests',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ride.availableSeats} of ${ride.totalSeats} seats remaining',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                if (bookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        'No requests received yet for this ride.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return _buildPassengerRequestCard(
                          booking,
                          setSheetState,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassengerRequestCard(
    BookingModel booking,
    StateSetter setSheetState,
  ) {
    final passenger = booking.passenger;
    final isPending = booking.status == 'PENDING';
    final isAccepted = booking.status == 'ACCEPTED';
    final isCompleted = booking.status == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.border,
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  (passenger?.name.isNotEmpty ?? false)
                      ? passenger!.name[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger?.name ?? 'Passenger',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (passenger?.phone.isNotEmpty ?? false)
                      Text(
                        passenger!.phone,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              _buildBookingStatusBadge(booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Route and notes
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.pin_drop_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Pickup: ${booking.pickupName}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Drop: ${booking.dropName}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (booking.passengerNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Note: "${booking.passengerNote}"',
                    style: AppTypography.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seats: ${booking.seatsRequested} • Total: ₹${booking.fareAmount.toStringAsFixed(0)}',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isAccepted && booking.verificationOtp.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  child: Text(
                    'OTP: ${booking.verificationOtp}',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.radiusMd,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () async {
                      await _respondToBooking(booking, 'REJECTED');
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.radiusMd,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () async {
                      await _respondToBooking(booking, 'ACCEPTED');
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (isCompleted && passenger != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star_outline_rounded),
                onPressed: () => _openReview(
                  rideId: booking.rideId,
                  revieweeId: booking.passengerId,
                  revieweeName: passenger.name.isEmpty
                      ? 'your passenger'
                      : passenger.name,
                ),
                label: const Text('Rate passenger'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Build Method ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Activity',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.pending_actions_rounded),
            tooltip: 'Booking Requests Queue',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverRequestQueueScreen(),
                ),
              );
              _loadAllData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.radiusFull,
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppSpacing.radiusFull,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              labelStyle: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: AppTypography.labelMd,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Driver (${_driverRides.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.backpack_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Passenger (${_passengerBookings.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Filter Segment Bar ──────────────────────────────────────────
          _buildFilterBar(),

          // ── Tab Views ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Driver View
                _buildDriverTab(),

                // Passenger View
                _buildPassengerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _buildFilterChip('All', RideFilter.all),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Upcoming / Active', RideFilter.active),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Past', RideFilter.past),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, RideFilter filter) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      borderRadius: AppSpacing.radiusFull,
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.radiusFull,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── Driver Tab ────────────────────────────────────────────────────────────
  Widget _buildDriverTab() {
    if (_loadingDriverRides && _driverRides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_driverError != null && _driverRides.isEmpty) {
      return _buildErrorState(_driverError!, _fetchDriverRides);
    }

    final filtered = _filteredDriverRides;
    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchDriverRides,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No Offered Rides Found',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You have not offered any rides yet. Heading to campus or returning home? Share your journey with fellow students!',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppPrimaryButton(
                  text: 'Offer a Ride',
                  icon: Icons.add_circle_outline_rounded,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfferRideScreen(),
                      ),
                    );
                    _fetchDriverRides();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDriverRides,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final ride = filtered[index];
          return _buildDriverRideCard(ride);
        },
      ),
    );
  }

  Widget _buildDriverRideCard(RideModel ride) {
    final pendingRequestsCount = ride.bookings
        .where((b) => b.status == 'PENDING')
        .length;
    final acceptedCount = ride.bookings
        .where((b) => b.status == 'ACCEPTED')
        .length;
    final isScheduled = ride.status == 'SCHEDULED';
    final isOngoing = ride.status == 'ONGOING';
    final isTerminal = ride.status == 'COMPLETED' || ride.status == 'CANCELLED';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Departure time & status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(ride.departureTime),
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildRideStatusBadge(ride.status),
            ],
          ),
          const Divider(height: AppSpacing.md),

          // Origin -> Destination
          Row(
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  Container(width: 2, height: 24, color: AppColors.border),
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.originName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ride.destName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Price / Contribution
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ride.contribution > 0
                        ? '₹${ride.contribution.toStringAsFixed(0)}'
                        : 'Free',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'per seat',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Seat Capacity & Passenger Requests Indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${ride.availableSeats} of ${ride.totalSeats} seats open',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showPassengerRequestsSheet(ride),
                  child: Row(
                    children: [
                      Text(
                        pendingRequestsCount > 0
                            ? '$pendingRequestsCount Request${pendingRequestsCount > 1 ? 's' : ''}'
                            : '$acceptedCount Passenger${acceptedCount != 1 ? 's' : ''}',
                        style: AppTypography.labelSm.copyWith(
                          color: pendingRequestsCount > 0
                              ? AppColors.tertiary
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pendingRequestsCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.outlineVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Driver Status Controls
          if (!isTerminal) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (isScheduled) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      onPressed: () => _updateRideStatus(ride, 'CANCELLED'),
                      child: const Text('Cancel Ride'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      onPressed: () => _updateRideStatus(ride, 'ONGOING'),
                      child: const Text('Start Ride'),
                    ),
                  ),
                ] else if (isOngoing) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      onPressed: () => _updateRideStatus(ride, 'COMPLETED'),
                      label: const Text('Complete Ride'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Passenger Tab ─────────────────────────────────────────────────────────
  Widget _buildPassengerTab() {
    if (_loadingPassengerBookings && _passengerBookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_passengerError != null && _passengerBookings.isEmpty) {
      return _buildErrorState(_passengerError!, _fetchPassengerBookings);
    }

    final filtered = _filteredPassengerBookings;
    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPassengerBookings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.backpack_rounded,
                    size: 40,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No Bookings Found',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You have not booked any lifts yet. Find students heading your direction and hitch a convenient ride!',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppPrimaryButton(
                  text: 'Find a Ride',
                  icon: Icons.search_rounded,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindRidesScreen(),
                      ),
                    );
                    _fetchPassengerBookings();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPassengerBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final booking = filtered[index];
          return _buildPassengerBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildPassengerBookingCard(BookingModel booking) {
    final ride = booking.ride;
    final driver = ride?.driver;
    final isAccepted = booking.status == 'ACCEPTED';
    final isPending = booking.status == 'PENDING';
    final isCompleted = booking.status == 'COMPLETED';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Driver info & booking status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  (driver?.name.isNotEmpty ?? false)
                      ? driver!.name[0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.name ?? 'Driver',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (driver?.vehicleModel != null &&
                            driver!.vehicleModel.isNotEmpty) ...[
                          Text(
                            driver.vehicleModel,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (driver?.ratingAvg != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              Text(
                                driver!.ratingAvg.toStringAsFixed(1),
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildBookingStatusBadge(booking.status),
            ],
          ),
          const Divider(height: AppSpacing.md),

          // Route Details
          Row(
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  Container(width: 2, height: 24, color: AppColors.border),
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.pickupName.isNotEmpty
                          ? booking.pickupName
                          : (ride?.originName ?? 'Origin'),
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      booking.dropName.isNotEmpty
                          ? booking.dropName
                          : (ride?.destName ?? 'Destination'),
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    booking.fareAmount > 0
                        ? '₹${booking.fareAmount.toStringAsFixed(0)}'
                        : 'Free',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${booking.seatsRequested} seat${booking.seatsRequested > 1 ? 's' : ''}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (ride != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Departure: ${_formatDateTime(ride.departureTime)}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          // Secure OTP Verification Card (When Accepted)
          if (isAccepted && booking.verificationOtp.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: AppSpacing.radiusMd,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOARDING VERIFICATION OTP',
                          style: AppTypography.caption.copyWith(
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          booking.verificationOtp,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Share with driver when boarding',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Passenger Actions
          if (isPending || isAccepted) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.radiusMd,
                  ),
                ),
                onPressed: () => _cancelPassengerBooking(booking),
                child: const Text('Cancel Booking'),
              ),
            ),
          ] else if (isCompleted) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star_rounded),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.radiusMd,
                  ),
                ),
                onPressed: () => _showRatingModal(booking),
                label: const Text('Rate & Review Driver'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Status Badges & Helpers ───────────────────────────────────────────────
  Widget _buildRideStatusBadge(String status) {
    return switch (status.toUpperCase()) {
      'SCHEDULED' => const AppStatusBadge(
        status: RideStatusType.available,
        customLabel: 'Scheduled',
      ),
      'ONGOING' => const AppStatusBadge(
        status: RideStatusType.active,
        customLabel: 'Live / Ongoing',
      ),
      'COMPLETED' => const AppStatusBadge(
        status: RideStatusType.completed,
        customLabel: 'Completed',
      ),
      'CANCELLED' => const AppStatusBadge(
        status: RideStatusType.cancelled,
        customLabel: 'Cancelled',
      ),
      _ => AppStatusBadge(status: RideStatusType.pending, customLabel: status),
    };
  }

  Widget _buildBookingStatusBadge(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => const AppStatusBadge(
        status: RideStatusType.pending,
        customLabel: 'Pending',
      ),
      'ACCEPTED' => const AppStatusBadge(
        status: RideStatusType.confirmed,
        customLabel: 'Accepted',
      ),
      'REJECTED' => const AppStatusBadge(
        status: RideStatusType.cancelled,
        customLabel: 'Declined',
      ),
      'COMPLETED' => const AppStatusBadge(
        status: RideStatusType.completed,
        customLabel: 'Completed',
      ),
      'CANCELLED' => const AppStatusBadge(
        status: RideStatusType.cancelled,
        customLabel: 'Cancelled',
      ),
      _ => AppStatusBadge(status: RideStatusType.pending, customLabel: status),
    };
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load data',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              error,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRetry,
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow =
        dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minuteStr $period';

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
  }
}

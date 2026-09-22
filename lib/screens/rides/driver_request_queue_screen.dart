import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/booking_model.dart';
import '../../models/ride_model.dart';
import '../../services/booking_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class DriverRequestQueueScreen extends StatefulWidget {
  const DriverRequestQueueScreen({
    super.key,
    this.initialRideId,
    this.initialFilterStatus,
  });

  final String? initialRideId;
  final String? initialFilterStatus;

  @override
  State<DriverRequestQueueScreen> createState() => _DriverRequestQueueScreenState();
}

class _DriverRequestQueueScreenState extends State<DriverRequestQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<BookingModel> _allBookings = [];
  List<RideModel> _myRides = [];
  String? _selectedRideFilter;

  @override
  void initState() {
    super.initState();
    _selectedRideFilter = widget.initialRideId;
    _tabController = TabController(length: 3, vsync: this);
    _loadQueueData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQueueData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        BookingService.getDriverBookingRequests(rideId: _selectedRideFilter),
        RideService.getMyRides(),
      ]);

      if (mounted) {
        setState(() {
          _allBookings = results[0] as List<BookingModel>;
          _myRides = results[1] as List<RideModel>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── Segregated Lists ──────────────────────────────────────────────────────
  List<BookingModel> get _pendingBookings =>
      _allBookings.where((b) => b.status == 'PENDING').toList();

  List<BookingModel> get _acceptedBookings =>
      _allBookings.where((b) => b.status == 'ACCEPTED').toList();

  List<BookingModel> get _historyBookings =>
      _allBookings.where((b) => b.status != 'PENDING' && b.status != 'ACCEPTED').toList();

  // ── Accept Confirmation Flow ──────────────────────────────────────────────
  Future<void> _showAcceptConfirmation(BookingModel booking) async {
    final noteController = TextEditingController();
    bool isProcessing = false;

    // Find associated ride
    final associatedRide = _myRides.firstWhere(
      (r) => r.id == booking.rideId,
      orElse: () => booking.ride ?? RideModel(
        id: booking.rideId,
        driverId: '',
        originName: booking.pickupName,
        destName: booking.dropName,
        departureTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final remainingSeats = associatedRide.availableSeats - booking.seatsRequested;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final passenger = booking.passenger;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              AppSpacing.lg,
              AppSpacing.marginMobile,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.secondary, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Accept Passenger Request',
                          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Passenger & Seat Summary Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: AppColors.border),
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
                                  fontWeight: FontWeight.bold, color: AppColors.onPrimary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passenger?.name ?? 'Student Passenger',
                                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (passenger?.rollNumber.isNotEmpty ?? false)
                                  Text(
                                    '${passenger?.college ?? ''} • ${passenger?.rollNumber}',
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+₹${booking.fareAmount.toStringAsFixed(0)}',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${booking.seatsRequested} seat(s)',
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.md),

                      // Capacity Impact
                      Row(
                        children: [
                          Icon(
                            remainingSeats >= 0 ? Icons.airline_seat_recline_normal_rounded : Icons.warning_rounded,
                            size: 16,
                            color: remainingSeats >= 0 ? AppColors.secondary : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            remainingSeats >= 0
                                ? '$remainingSeats open seat(s) remaining after accepting'
                                : 'Warning: Exceeds current available seats ($remainingSeats)',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: remainingSeats >= 0 ? AppColors.secondary : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Pickup instructions note
                AppTextField(
                  controller: noteController,
                  label: 'Pickup Note to Passenger (Optional)',
                  hintText: 'e.g. Wait near library stairs; I am riding a black scooter.',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Confirmation Button
                AppPrimaryButton(
                  text: 'Confirm & Accept Request',
                  icon: Icons.check_rounded,
                  isLoading: isProcessing,
                  onPressed: () async {
                    setModalState(() => isProcessing = true);
                    final navigator = Navigator.of(sheetContext);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await BookingService.respondToBookingRequest(
                        booking.id,
                        'ACCEPTED',
                        driverResponseNote: noteController.text.trim(),
                      );
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Accepted ${passenger?.name ?? 'Passenger'}! Seat confirmed.'),
                          backgroundColor: AppColors.secondary,
                        ),
                      );
                      _loadQueueData();
                    } catch (e) {
                      setModalState(() => isProcessing = false);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to accept: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Reject Confirmation Flow ──────────────────────────────────────────────
  Future<void> _showRejectConfirmation(BookingModel booking) async {
    String selectedReason = 'Vehicle is full';
    final noteController = TextEditingController();
    bool isProcessing = false;

    final reasons = [
      'Vehicle is full',
      'Route/timing conflict',
      'Too far from route',
      'Ride cancelled',
      'Other reason',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final passenger = booking.passenger;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              AppSpacing.lg,
              AppSpacing.marginMobile,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.errorTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Decline Request',
                          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Let ${passenger?.name ?? 'the passenger'} know why you cannot accept their request.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Reason Chips
                Text(
                  'SELECT A REASON',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((reason) {
                    final isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(reason),
                      selected: isSelected,
                      selectedColor: AppColors.errorContainer,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.error : AppColors.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedReason = reason;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),

                // Custom note
                AppTextField(
                  controller: noteController,
                  label: 'Additional Note (Optional)',
                  hintText: 'Provide extra details if necessary...',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isProcessing
                            ? null
                            : () async {
                                setModalState(() => isProcessing = true);
                                final navigator = Navigator.of(sheetContext);
                                final messenger = ScaffoldMessenger.of(context);

                                final note = noteController.text.trim().isNotEmpty
                                    ? '$selectedReason - ${noteController.text.trim()}'
                                    : selectedReason;

                                try {
                                  await BookingService.respondToBookingRequest(
                                    booking.id,
                                    'REJECTED',
                                    driverResponseNote: note,
                                  );
                                  if (!mounted) return;
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Request declined.'),
                                      backgroundColor: AppColors.onSurfaceVariant,
                                    ),
                                  );
                                  _loadQueueData();
                                } catch (e) {
                                  setModalState(() => isProcessing = false);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Failed to decline: $e'), backgroundColor: AppColors.error),
                                  );
                                }
                              },
                        child: isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Confirm Decline'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── OTP Boarding Verification Modal ───────────────────────────────────────
  Future<void> _showOtpVerificationModal(BookingModel booking) async {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? otpError;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pin_rounded, color: AppColors.onPrimary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Verify Passenger OTP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask ${booking.passenger?.name ?? 'the passenger'} for their 4-digit verification code before boarding.',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  errorText: otpError,
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.radiusMd,
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                onChanged: (_) {
                  if (otpError != null) setModalState(() => otpError = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final inputOtp = otpController.text.trim();
                      if (inputOtp.length < 4) {
                        setModalState(() => otpError = 'Please enter full 4-digit OTP');
                        return;
                      }

                      setModalState(() => isVerifying = true);
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await BookingService.verifyBookingOtp(booking.id, inputOtp);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Passenger verified! Boarding confirmed.'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                        _loadQueueData();
                      } catch (e) {
                        setModalState(() {
                          isVerifying = false;
                          otpError = e.toString();
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Verify Boarding'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build Main UI ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Requests Queue',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: _loadQueueData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Ride selector chips if driver has multiple rides
              if (_myRides.length > 1) _buildRideFilterSelector(),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
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
                  labelStyle: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                  unselectedLabelStyle: AppTypography.labelMd,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('Pending (${_pendingBookings.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.how_to_reg_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('Confirmed (${_acceptedBookings.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text('History (${_historyBookings.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(_pendingBookings, isPendingTab: true),
                    _buildRequestsList(_acceptedBookings, isAcceptedTab: true),
                    _buildRequestsList(_historyBookings, isHistoryTab: true),
                  ],
                ),
    );
  }

  Widget _buildRideFilterSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Offered Rides'),
            selected: _selectedRideFilter == null,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedRideFilter = null);
                _loadQueueData();
              }
            },
          ),
          const SizedBox(width: 8),
          ..._myRides.map((ride) {
            final isSelected = _selectedRideFilter == ride.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text('${ride.originName} → ${ride.destName}'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedRideFilter = selected ? ride.id : null;
                  });
                  _loadQueueData();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    List<BookingModel> bookings, {
    bool isPendingTab = false,
    bool isAcceptedTab = false,
    bool isHistoryTab = false,
  }) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadQueueData,
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
                  decoration: BoxDecoration(
                    color: isPendingTab
                        ? AppColors.warningTint
                        : isAcceptedTab
                            ? AppColors.secondaryTint
                            : AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPendingTab
                        ? Icons.hourglass_empty_rounded
                        : isAcceptedTab
                            ? Icons.group_outlined
                            : Icons.task_alt_rounded,
                    size: 40,
                    color: isPendingTab
                        ? AppColors.tertiary
                        : isAcceptedTab
                            ? AppColors.secondary
                            : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isPendingTab
                      ? 'No Pending Requests'
                      : isAcceptedTab
                          ? 'No Confirmed Passengers'
                          : 'No Past Requests',
                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isPendingTab
                      ? 'All incoming passenger requests have been addressed!'
                      : isAcceptedTab
                          ? 'Accept passenger requests from the pending tab to confirm them here.'
                          : 'Resolved requests and completed rides will appear here.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueueData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildQueueCard(
            booking,
            isPending: isPendingTab,
            isAccepted: isAcceptedTab,
          );
        },
      ),
    );
  }

  Widget _buildQueueCard(
    BookingModel booking, {
    bool isPending = false,
    bool isAccepted = false,
  }) {
    final passenger = booking.passenger;
    final ride = booking.ride;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Passenger Profile & Status
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  (passenger?.name.isNotEmpty ?? false) ? passenger!.name[0].toUpperCase() : 'P',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onPrimary, fontSize: 16),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            passenger?.name ?? 'Passenger',
                            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (passenger?.isVerified ?? false) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (passenger?.rollNumber.isNotEmpty ?? false) ...[
                          Text(
                            passenger!.rollNumber,
                            style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (passenger?.ratingAvg != null)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              Text(
                                passenger!.ratingAvg.toStringAsFixed(1),
                                style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(booking.status),
            ],
          ),

          const Divider(height: AppSpacing.md),

          // Associated Ride Banner
          if (ride != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.radiusSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ride: ${ride.originName} → ${ride.destName}',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTime(ride.departureTime),
                    style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Passenger Pickup & Drop Points
          Row(
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, size: 16, color: AppColors.primary),
                  Container(width: 2, height: 22, color: AppColors.border),
                  const Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup: ${booking.pickupName}',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Drop: ${booking.dropName}',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
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
                    '₹${booking.fareAmount.toStringAsFixed(0)}',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${booking.seatsRequested} seat${booking.seatsRequested > 1 ? 's' : ''}',
                    style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),

          // Passenger Note
          if (booking.passengerNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xs + 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '"${booking.passengerNote}"',
                      style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Driver Response Note (if declined / accepted with note)
          if (booking.driverResponseNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xs + 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.radiusSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your note: "${booking.driverResponseNote}"',
                      style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── ACTION BUTTONS ────────────────────────────────────────────────
          if (isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showRejectConfirmation(booking),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showAcceptConfirmation(booking),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.pin_rounded, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusMd),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showOtpVerificationModal(booking),
                    label: const Text('Verify Boarding OTP'),
                  ),
                ),
                if (passenger?.phone.isNotEmpty ?? false) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppSpacing.radiusMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Call Passenger',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contact ${passenger?.name}: ${passenger?.phone}'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
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

  Widget _buildStatusBadge(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => const AppStatusBadge(
          status: RideStatusType.pending,
          customLabel: 'Pending Review',
        ),
      'ACCEPTED' => const AppStatusBadge(
          status: RideStatusType.confirmed,
          customLabel: 'Confirmed',
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Failed to load queue',
                style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            Text(_errorMessage!,
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadQueueData,
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }
}

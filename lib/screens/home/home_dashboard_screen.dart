import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/booking_model.dart';
import '../../models/ride_model.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/ride_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../auto_groups/auto_groups_screen.dart';
import '../find_rides_screen.dart';
import '../offer_ride_screen.dart';
import '../navigation/main_navigation_shell.dart';
import '../profile/profile_screen.dart';
import '../ride_details_screen.dart';
import '../rides/driver_request_queue_screen.dart';
import '../rides/my_rides_screen.dart';
import '../map/map_screen.dart';

/// Campus Pool Home Dashboard Screen
/// Based on Stitch design: projects/4131098890607133930/screens/f3c45ada102f44db80a425cc7c5598b1
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.userName,
    this.embeddedInShell = false,
  });

  final String? userName;
  final bool embeddedInShell;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentNavIndex = 0;
  RideModel? _activeRide;
  List<RideModel> _nearbyRides = const [];
  bool _isLoadingDashboard = true;
  String? _dashboardError;
  String _displayName = 'there';

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : (AuthService.cachedUser?.name.trim().isNotEmpty == true
              ? AuthService.cachedUser!.name.trim()
              : 'there');
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = await AuthService.loadSession();
      if (mounted && user?.name.trim().isNotEmpty == true) {
        setState(() => _displayName = user!.name.trim());
      }
      final results = await Future.wait<dynamic>([
        BookingService.listUserBookings(),
        RideService.searchRides({'limit': '5'}),
      ]);
      final bookings = results[0] as List<BookingModel>;
      final nearbyRides = results[1] as List<RideModel>;
      BookingModel? activeBooking;
      for (final booking in bookings) {
        final rideStatus = booking.ride?.status.toUpperCase();
        if (booking.status.toUpperCase() == 'ACCEPTED' &&
            booking.ride != null &&
            rideStatus != 'CANCELLED' &&
            rideStatus != 'COMPLETED') {
          activeBooking = booking;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _activeRide = activeBooking?.ride;
        _nearbyRides = nearbyRides;
        _isLoadingDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboard = false;
        _dashboardError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Mobile Top Bar ──────────────────────────────────────────
            _buildTopBar(),

            // ── Scrollable Content ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Location Card ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      child: _buildLocationCard(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Bento Action Cards ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      child: _buildActionCards(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Auto Groups Card ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      child: AppCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AutoGroupsScreen(),
                          ),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shared Auto Pooling',
                                    style: AppTypography.labelMd.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Match with 3-4 students heading your route',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.outlineVariant,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Active Ride Section ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      child: _buildActiveRideSection(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Nearby Rides Section ──────────────────────────────
                    _buildNearbyRidesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation Bar ───────────────────────────────────────────
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyRidesScreen()),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfferRideScreen()),
                  );
                } else if (index == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverRequestQueueScreen(),
                    ),
                  );
                } else if (index == 4) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                } else {
                  setState(() => _currentNavIndex = index);
                }
              },
              items: const [
                AppNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                AppNavItem(
                  icon: Icons.two_wheeler_outlined,
                  selectedIcon: Icons.two_wheeler_rounded,
                  label: 'Rides',
                ),
                AppNavItem(
                  icon: Icons.add_circle_outline_rounded,
                  selectedIcon: Icons.add_circle_rounded,
                  label: 'Offer',
                ),
                AppNavItem(
                  icon: Icons.notifications_none_rounded,
                  selectedIcon: Icons.notifications_rounded,
                  label: 'Alerts',
                  badgeCount: 2,
                ),
                AppNavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.lg,
        AppSpacing.marginMobile,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $_displayName! 👋',
                style: AppTypography.headlineLgMobile.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to move?',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _NotificationButton(
                onTap: () {
                  if (widget.embeddedInShell) {
                    MainNavigationShell.switchTab(context, 3);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverRequestQueueScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : 'U',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.radiusMd,
                ),
                onSelected: (value) async {
                  if (value == 'profile') {
                    if (widget.embeddedInShell) {
                      MainNavigationShell.switchTab(context, 4);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    }
                  } else if (value == 'logout') {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Student Account',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'My Profile',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location Card ────────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT LOCATION',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Campus Library',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.outlineVariant,
            size: 22,
          ),
        ],
      ),
    );
  }

  // ── Bento Grid Action Cards ──────────────────────────────────────────────
  Widget _buildActionCards() {
    return Row(
      children: [
        // Find a Ride (Light Card)
        Expanded(
          child: _ActionCard(
            height: 180,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindRidesScreen()),
            ),
            child: Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceContainerLow,
                          AppColors.surfaceContainer.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: AppSpacing.radiusLg,
                    ),
                  ),
                ),
                // Icon in top-right
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ),
                // Text at bottom
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.xl + AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Find a Ride',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Going the same way? Coordinate a shared auto with fellow students.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Offer a Ride (Primary Blue Card)
        Expanded(
          child: _ActionCard(
            height: 180,
            backgroundColor: AppColors.primary,
            hasBorder: false,
            onTap: () {
              if (widget.embeddedInShell) {
                MainNavigationShell.switchTab(context, 2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfferRideScreen()),
                );
              }
            },
            child: Stack(
              children: [
                // Decorative blobs
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Motorcycle icon in top-right
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler_rounded,
                      color: AppColors.onPrimary,
                      size: 26,
                    ),
                  ),
                ),
                // Text at bottom
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.xl + AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Offer a Ride',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Heading out? Pick up a fellow student on your way.',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Active Ride Section ──────────────────────────────────────────────────
  Widget _buildActiveRideSection() {
    if (_isLoadingDashboard) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            'Active Ride',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_activeRide != null)
          _buildRideCard(
            _activeRide!,
            status: _activeRide!.status.toUpperCase() == 'ONGOING'
                ? RideStatusType.active
                : RideStatusType.confirmed,
            bookButtonText: 'Track',
          )
        else
          // Empty State
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.radiusLg,
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
                // Dashed border simulation via BoxDecoration
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AppColors.outline,
                    size: 24,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No active rides right now.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () {
                    if (widget.embeddedInShell) {
                      MainNavigationShell.switchTab(context, 1);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const MyRidesScreen(initialTabIndex: 0),
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View History',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Nearby Rides Section ─────────────────────────────────────────────────
  Widget _buildNearbyRidesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            0,
            AppSpacing.marginMobile,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Rides',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindRidesScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                ),
                child: Text(
                  'See all',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingDashboard)
          const SizedBox(
            height: 258,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_nearbyRides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Text(
              _dashboardError == null
                  ? 'No nearby rides available.'
                  : 'Unable to load nearby rides.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 258,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
              ),
              itemCount: _nearbyRides.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) => SizedBox(
                width: 320,
                child: _buildRideCard(_nearbyRides[index]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRideCard(
    RideModel ride, {
    RideStatusType status = RideStatusType.available,
    String bookButtonText = 'Book Seat',
  }) {
    final driver = ride.driver;
    return AppRideCard(
      driverName: driver?.name.isNotEmpty == true
          ? driver!.name
          : 'Campus Driver',
      origin: ride.originName,
      destination: ride.destName,
      departureTime: status == RideStatusType.active
          ? 'NOW'
          : MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(ride.departureTime.toLocal()),
            ),
      availableSeats: ride.availableSeats,
      price: ride.contribution,
      vehicleType: ride.vehicleType,
      vehicleModel: driver?.vehicleModel.isNotEmpty == true
          ? driver!.vehicleModel
          : null,
      driverRating: driver?.ratingAvg ?? 0.0,
      status: status,
      bookButtonText: bookButtonText,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)),
      ),
      onBookTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)),
      ),
    );
  }
}

// ── Reusable Internal Widgets ────────────────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap:
                  onTap ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverRequestQueueScreen(),
                      ),
                    );
                  },
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.onSurface,
                size: 22,
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.child,
    required this.onTap,
    this.height = 180,
    this.backgroundColor = AppColors.surface,
    this.hasBorder = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;
  final Color backgroundColor;
  final bool hasBorder;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: AppSpacing.radiusLg,
            border: widget.hasBorder
                ? Border.all(color: AppColors.border, width: 1)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: widget.child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../components/components.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Interactive Design System Showcase for Campus Pool
class DesignSystemShowcase extends StatefulWidget {
  const DesignSystemShowcase({super.key});

  @override
  State<DesignSystemShowcase> createState() => _DesignSystemShowcaseState();
}

class _DesignSystemShowcaseState extends State<DesignSystemShowcase> {
  int _selectedTabIndex = 0;
  int _currentNavIndex = 0;
  bool _isButtonLoading = false;
  String _selectedRole = 'Bike';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  final List<String> _tabs = [
    'Overview & Tokens',
    'Buttons',
    'Inputs',
    'Badges & Chips',
    'Ride Cards',
    'Banners & Nav',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'CampusFlow Design System',
        subtitle: 'MVP Mobile UI • Tokens & Components',
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme: Light • Inter Typography • 16px Radius'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Category Tabs
          Container(
            height: 48,
            color: AppColors.surface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedTabIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(_tabs[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTabIndex = index);
                    },
                    selectedColor: AppColors.primaryFixed,
                    backgroundColor: AppColors.surfaceContainerLow,
                    labelStyle: AppTypography.labelSm.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: isSelected
                        ? const BorderSide(color: AppColors.primary, width: 1)
                        : const BorderSide(color: AppColors.border, width: 1),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildOverviewTab(),
                _buildButtonsTab(),
                _buildInputsTab(),
                _buildBadgesTab(),
                _buildRideCardsTab(),
                _buildBannersAndNavTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
        items: const [
          AppNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          AppNavItem(
            icon: Icons.directions_car_outlined,
            selectedIcon: Icons.directions_car_rounded,
            label: 'Find Ride',
          ),
          AppNavItem(
            icon: Icons.add_circle_outline_rounded,
            selectedIcon: Icons.add_circle_rounded,
            label: 'Offer Ride',
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

  // TAB 1: OVERVIEW & TOKENS
  Widget _buildOverviewTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('Brand Colors', 'Primary & secondary semantic tokens'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildColorCard('Primary Campus Blue', '#0058BE', AppColors.primary, Colors.white),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildColorCard('Blue Light', '#3B82F6', AppColors.primaryLight, Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildColorCard('Secondary Transit Teal', '#006C49', AppColors.secondary, Colors.white),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildColorCard('Teal Accent', '#10B981', AppColors.secondaryLight, Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildColorCard('Warning Amber', '#825100', AppColors.tertiary, Colors.white),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildColorCard('Critical Red', '#BA1A1A', AppColors.error, Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildColorCard('Background Canvas', '#F9F9FF', AppColors.background, AppColors.onBackground, hasBorder: true),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildColorCard('Card Surface', '#FFFFFF', AppColors.surface, AppColors.onSurface, hasBorder: true),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Typography Scale', 'Inter Font Family Hierarchy'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Headline Large (32px Bold)', style: AppTypography.headlineLg),
              const SizedBox(height: 4),
              Text('Headline Medium (20px SemiBold)', style: AppTypography.headlineMd),
              const SizedBox(height: 4),
              Text('Headline Small (18px SemiBold)', style: AppTypography.headlineSm),
              const SizedBox(height: 6),
              Text('Body Large: Student carpooling and bike sharing across campus grounds.', style: AppTypography.bodyLg),
              const SizedBox(height: 4),
              Text('Body Medium: Standard 16px text with optimal readability for mobile screens.', style: AppTypography.bodyMd),
              const SizedBox(height: 4),
              Text('Body Small: 14px secondary text for micro-details and meta information.', style: AppTypography.bodySm),
              const SizedBox(height: 6),
              Text('LABEL LARGE (16px SemiBold)', style: AppTypography.labelLg),
              const SizedBox(height: 2),
              Text('LABEL MEDIUM (14px SemiBold)', style: AppTypography.labelMd),
              const SizedBox(height: 2),
              Text('LABEL SMALL (12px Medium)', style: AppTypography.labelSm),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Design Standards', 'Dimensions, touch targets and corner radii'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppCard(
                child: Column(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(height: 4),
                    Text('56px', style: AppTypography.headlineMd),
                    Text('Min Touch Target', style: AppTypography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppCard(
                child: Column(
                  children: [
                    const Icon(Icons.rounded_corner_rounded, color: AppColors.secondary, size: 28),
                    const SizedBox(height: 4),
                    Text('16px', style: AppTypography.headlineMd),
                    Text('Standard Radius', style: AppTypography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppCard(
                child: Column(
                  children: [
                    const Icon(Icons.layers_outlined, color: AppColors.tertiary, size: 28),
                    const SizedBox(height: 4),
                    Text('Level 1', style: AppTypography.headlineMd),
                    Text('Soft Elevation', style: AppTypography.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // TAB 2: BUTTONS
  Widget _buildButtonsTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('Primary Buttons', 'Campus Blue • 56px Touch Target • 16px Radius'),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          text: 'Find a Ride',
          icon: Icons.search_rounded,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          text: 'Offer a Ride',
          icon: Icons.add_rounded,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppPrimaryButton(
          text: _isButtonLoading ? 'Processing...' : 'Toggle Loading State',
          isLoading: _isButtonLoading,
          onPressed: () {
            setState(() => _isButtonLoading = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _isButtonLoading = false);
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppPrimaryButton(
          text: 'Disabled Button State',
          onPressed: null,
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Secondary Buttons', 'Tinted (#EFF6FF) & Outlined Variants'),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          text: 'View Ride Details',
          icon: Icons.visibility_outlined,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          text: 'Cancel Request (Outlined)',
          variant: SecondaryButtonVariant.outlined,
          icon: Icons.close_rounded,
          onPressed: () {},
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Icon Action Buttons', '44px Accessible Touch Targets'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              foregroundColor: AppColors.primary,
              tooltip: 'Chat with rider',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.call_outlined,
              foregroundColor: AppColors.secondary,
              tooltip: 'Call driver',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.share_outlined,
              tooltip: 'Share ride',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.favorite_border_rounded,
              foregroundColor: AppColors.error,
              tooltip: 'Favorite route',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  // TAB 3: INPUTS
  Widget _buildInputsTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('Campus Search Bar', 'Search bar with interactive filter action'),
        const SizedBox(height: AppSpacing.sm),
        AppSearchBar(
          controller: _searchController,
          hintText: 'Search campus gates, library, hostel...',
          onFilterTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Filter tapped')),
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Text Form Fields', '56px height • 16px radius • 2px blue focus ring'),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _emailController,
          label: 'Campus Email',
          hintText: 'student@campus.edu.in',
          prefixIcon: const Icon(Icons.school_outlined),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _passController,
          label: 'Password',
          hintText: '••••••••',
          isPassword: true,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTextField(
          label: 'Vehicle Number (Disabled State)',
          initialValue: 'MH-12-AB-1234',
          enabled: false,
          prefixIcon: Icon(Icons.two_wheeler_rounded),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppTextField(
          label: 'Validation Error State',
          initialValue: 'invalid_route',
          errorText: 'Please enter a valid campus pickup point',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
      ],
    );
  }

  // TAB 4: BADGES & CHIPS
  Widget _buildBadgesTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('Ride Status Badges', 'Semantic status indicators with dot accents'),
        const SizedBox(height: AppSpacing.sm),
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppStatusBadge(status: RideStatusType.available),
            AppStatusBadge(status: RideStatusType.active),
            AppStatusBadge(status: RideStatusType.confirmed),
            AppStatusBadge(status: RideStatusType.pending),
            AppStatusBadge(status: RideStatusType.completed),
            AppStatusBadge(status: RideStatusType.cancelled),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Transport & Role Chips', 'Selectable transport mode chips'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppRoleChip(
              label: 'Bike / Scooter',
              icon: Icons.two_wheeler_rounded,
              badgeText: 'Popular',
              isSelected: _selectedRole == 'Bike',
              onSelected: (_) => setState(() => _selectedRole = 'Bike'),
            ),
            AppRoleChip(
              label: 'Carpool',
              icon: Icons.directions_car_rounded,
              badgeText: '3 seats',
              isSelected: _selectedRole == 'Carpool',
              onSelected: (_) => setState(() => _selectedRole = 'Carpool'),
            ),
            AppRoleChip(
              label: 'Campus Shuttle',
              icon: Icons.directions_bus_rounded,
              isSelected: _selectedRole == 'Shuttle',
              onSelected: (_) => setState(() => _selectedRole = 'Shuttle'),
            ),
            AppRoleChip(
              label: 'Walking Buddy',
              icon: Icons.directions_walk_rounded,
              isSelected: _selectedRole == 'Walk',
              onSelected: (_) => setState(() => _selectedRole = 'Walk'),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildSectionHeader('Interactive Surface Card', 'Scale-down feedback on tap'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card tapped with tactile scale animation')),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Instant Campus Match', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Tap this card to preview the 98% scale animation.', style: AppTypography.bodySm),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 5: RIDE CARDS
  Widget _buildRideCardsTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('Campus Ride Cards', 'High-fidelity ride card matching Stitch designs'),
        const SizedBox(height: AppSpacing.sm),
        AppRideCard(
          driverName: 'Rohan Sharma',
          origin: 'Hostel Block 4, Main Gate',
          destination: 'Academic Complex / CS Dept',
          departureTime: '08:45 AM',
          availableSeats: 1,
          price: 20,
          vehicleType: 'Honda Activa 6G',
          driverRating: 4.9,
          matchPercentage: 96,
          status: RideStatusType.available,
          onTap: () {},
          onBookTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Booking seat with Rohan Sharma...')),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppRideCard(
          driverName: 'Priya Patel',
          origin: 'Metro Station Gate 2',
          destination: 'Library & Innovation Hub',
          departureTime: '09:15 AM',
          availableSeats: 3,
          price: 40,
          vehicleType: 'Tata Nexon EV',
          driverRating: 5.0,
          matchPercentage: 88,
          status: RideStatusType.available,
          bookButtonText: 'Join Pool',
          onTap: () {},
          onBookTap: () {},
        ),
        const SizedBox(height: AppSpacing.md),
        AppRideCard(
          driverName: 'Aditya Verma',
          origin: 'Campus South Exit',
          destination: 'City Center Bus Stop',
          departureTime: '05:30 PM',
          availableSeats: 0,
          price: 0,
          vehicleType: 'Royal Enfield 350',
          driverRating: 4.7,
          status: RideStatusType.completed,
          onTap: () {},
        ),
      ],
    );
  }

  // TAB 6: BANNERS & NAV
  Widget _buildBannersAndNavTab() {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _buildSectionHeader('In-App Notification Banners', 'Alert banners matching Stitch notifications'),
        const SizedBox(height: AppSpacing.sm),
        AppNotificationBanner(
          type: NotificationBannerType.info,
          title: 'Ride Request Accepted',
          message: 'Aarav confirmed your seat for the 5:30 PM trip to South Campus.',
          actionLabel: 'Track Ride',
          onAction: () {},
          onDismiss: () {},
        ),
        const SizedBox(height: AppSpacing.md),
        AppNotificationBanner(
          type: NotificationBannerType.success,
          title: 'Biker Arriving Soon',
          message: 'Rohan is 2 minutes away from Hostel Block 4 pickup spot.',
          actionLabel: 'View Live Route',
          onAction: () {},
          onDismiss: () {},
        ),
        const SizedBox(height: AppSpacing.md),
        AppNotificationBanner(
          type: NotificationBannerType.warning,
          title: 'Campus Traffic Alert',
          message: 'Heavy congestion near North Gate. Expect 5 min delay.',
          onDismiss: () {},
        ),
        const SizedBox(height: AppSpacing.md),
        AppNotificationBanner(
          type: NotificationBannerType.error,
          title: 'Ride Cancelled',
          message: 'The driver had an emergency. We found 2 alternative rides.',
          actionLabel: 'Find Alternatives',
          onAction: () {},
          onDismiss: () {},
        ),
      ],
    );
  }

  // Helper Widget for Section Headers
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // Helper Widget for Color Cards
  Widget _buildColorCard(String name, String hex, Color color, Color textColor, {bool hasBorder = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppSpacing.radiusLg,
        border: hasBorder ? Border.all(color: AppColors.border, width: 1.0) : null,
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: AppTypography.labelMd.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hex,
            style: AppTypography.caption.copyWith(
              color: textColor.withValues(alpha: 0.8),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

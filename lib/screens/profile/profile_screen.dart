import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../auth/login_screen.dart';
import '../reviews/review_history_screen.dart';
import 'edit_profile_screen.dart';

/// Student Profile & Account Settings Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.initialUser});

  final UserModel? initialUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  Future<void> _navigateToEditProfile() async {
    if (_user == null) return;
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
    );

    if (updated != null && mounted) {
      setState(() {
        _user = updated;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser ?? AuthService.cachedUser;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await AuthService.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // If we already have cached user, keep showing it without blocking error
        if (_user == null) {
          _errorMessage = e.toString();
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out from Campus Pool?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProfile,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading && _user == null)
                  const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  )
                else if (_errorMessage != null && _user == null)
                  _buildErrorState()
                else
                  ..._buildProfileContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Profile',
              style: AppTypography.headlineLgMobile.copyWith(
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage campus identity & preferences',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (_user != null)
              IconButton(
                tooltip: 'Edit Profile',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                onPressed: _navigateToEditProfile,
              ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Log Out',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              onPressed: _handleLogout,
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildProfileContent() {
    final user = _user;
    final name = user?.name ?? 'Alex Rider';
    final email = user?.email ?? 'student@campus.edu';
    final college = user?.college.isNotEmpty == true
        ? user!.college
        : 'Campus Institute of Technology';
    final rollNo = user?.rollNumber.isNotEmpty == true
        ? user!.rollNumber
        : '23BCE1024';
    final phone = user?.phone.isNotEmpty == true
        ? user!.phone
        : '+91 9876543210';
    final isDriver =
        user?.roles.contains('driver') == true ||
        user?.roles.contains('both') == true;
    final rating = user?.ratingAvg ?? 4.9;
    final vehicle = user?.vehicle;

    return [
      // ── Main User Card ──────────────────────────────────────────────────
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: AppTypography.headlineLg.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        college,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildBadge(
                            label: 'Verified Student',
                            color: AppColors.secondary,
                            backgroundColor: AppColors.secondaryTint,
                          ),
                          if (isDriver)
                            _buildBadge(
                              label: 'Campus Driver',
                              color: AppColors.primary,
                              backgroundColor: AppColors.primaryTint,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            // Quick Rating & Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.tertiary,
                  value: rating.toStringAsFixed(1),
                  label: 'Rating',
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                _buildStatItem(
                  icon: Icons.two_wheeler_rounded,
                  iconColor: AppColors.primary,
                  value: '18',
                  label: 'Rides Done',
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                _buildStatItem(
                  icon: Icons.eco_rounded,
                  iconColor: AppColors.secondary,
                  value: '12 kg',
                  label: 'CO₂ Saved',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppSecondaryButton(
              text: 'Edit Profile Information',
              icon: Icons.edit_outlined,
              variant: SecondaryButtonVariant.tinted,
              onPressed: _navigateToEditProfile,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              text: 'View My Reviews',
              icon: Icons.reviews_outlined,
              variant: SecondaryButtonVariant.outlined,
              onPressed: user == null || user.id.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewHistoryScreen(userId: user.id),
                      ),
                    ),
            ),
          ],
        ),
      ),

      const SizedBox(height: AppSpacing.lg),

      // ── Student Info Section ────────────────────────────────────────────
      _buildSectionHeader('Student Information'),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            _buildInfoTile(
              icon: Icons.badge_outlined,
              label: 'Roll / Registration Number',
              value: rollNo,
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.email_outlined,
              label: 'Campus Email',
              value: email,
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.phone_outlined,
              label: 'Contact Number',
              value: phone,
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.account_balance_outlined,
              label: 'Campus',
              value: college,
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.person_outline_rounded,
              label: 'Gender Identity',
              value: _formatGender(user?.gender),
            ),
          ],
        ),
      ),

      const SizedBox(height: AppSpacing.lg),

      // ── Emergency Contact Section ───────────────────────────────────────
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSectionHeader('Emergency Contact & Safety'),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
            ),
            icon: const Icon(
              Icons.edit_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            label: Text(
              'Edit',
              style: AppTypography.labelSm.copyWith(color: AppColors.primary),
            ),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            _buildInfoTile(
              icon: Icons.contact_emergency_outlined,
              label: 'Emergency Contact Person',
              value: user?.emergencyName?.isNotEmpty == true
                  ? user!.emergencyName!
                  : 'Not provided',
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.phone_in_talk_outlined,
              label: 'Emergency Contact Phone',
              value: user?.emergencyPhone?.isNotEmpty == true
                  ? user!.emergencyPhone!
                  : 'Not provided',
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildInfoTile(
              icon: Icons.family_restroom_outlined,
              label: 'Relationship to Student',
              value: user?.emergencyRelation?.isNotEmpty == true
                  ? user!.emergencyRelation!
                  : 'Not provided',
            ),
          ],
        ),
      ),

      const SizedBox(height: AppSpacing.lg),

      // ── Driver & Vehicle Information (If Available) ─────────────────────
      if (vehicle != null || isDriver) ...[
        _buildSectionHeader('Vehicle & Driver Details'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle?.model.isNotEmpty == true
                              ? vehicle!.model
                              : 'Registered Campus Vehicle',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          vehicle?.plateNumber.isNotEmpty == true
                              ? vehicle!.plateNumber
                              : 'Registration Pending',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${vehicle?.totalSeats ?? 1} Seat${(vehicle?.totalSeats ?? 1) > 1 ? 's' : ''}',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              if (vehicle?.helmetProvided == true) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pillion helmet provided for riders',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],

      // ── Safety & Community Section ──────────────────────────────────────
      _buildSectionHeader('Campus Safety & Support'),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            _buildActionTile(
              icon: Icons.security_rounded,
              iconColor: AppColors.secondary,
              title: 'Campus Emergency Helpline',
              subtitle: 'Quick access to campus security and guards',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Campus Security Hotline: +91 1800-CAMPUS'),
                  ),
                );
              },
            ),
            const Divider(color: AppColors.border, height: 1),
            _buildActionTile(
              icon: Icons.rule_rounded,
              iconColor: AppColors.primary,
              title: 'Community Guidelines',
              subtitle: 'Rules for respectful campus pooling',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Viewing Campus Pool Community Guidelines'),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      const SizedBox(height: AppSpacing.xl),

      // ── Log Out Button ──────────────────────────────────────────────────
      AppSecondaryButton(
        text: 'Log Out of Account',
        icon: Icons.logout_rounded,
        variant: SecondaryButtonVariant.outlined,
        onPressed: _handleLogout,
      ),

      const SizedBox(height: AppSpacing.xl),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.labelMd.copyWith(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
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
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unable to load profile',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(text: 'Retry', onPressed: _fetchProfile),
        ],
      ),
    );
  }

  String _formatGender(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      default:
        return 'Prefer not to say';
    }
  }
}

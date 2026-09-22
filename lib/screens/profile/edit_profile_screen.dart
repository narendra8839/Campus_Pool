import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Screen allowing students to edit their profile and emergency contact details
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _collegeController;
  late TextEditingController _rollNoController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationController;

  late String _selectedGender;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _genderOptions = [
    'prefer_not_to_say',
    'male',
    'female',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u.name);
    _phoneController = TextEditingController(text: u.phone);
    _collegeController = TextEditingController(text: u.college);
    _rollNoController = TextEditingController(text: u.rollNumber);
    _emergencyNameController =
        TextEditingController(text: u.emergencyName ?? '');
    _emergencyPhoneController =
        TextEditingController(text: u.emergencyPhone ?? '');
    _emergencyRelationController =
        TextEditingController(text: u.emergencyRelation ?? '');

    _selectedGender = _genderOptions.contains(u.gender.toLowerCase())
        ? u.gender.toLowerCase()
        : 'prefer_not_to_say';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _rollNoController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  String _formatGenderLabel(String gender) {
    switch (gender) {
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await AuthService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        college: _collegeController.text.trim(),
        rollNumber: _rollNoController.text.trim(),
        gender: _selectedGender,
        emergencyName: _emergencyNameController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim(),
        emergencyRelation: _emergencyRelationController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );

      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.lg,
            ),
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Section 1: Academic & Personal ─────────────────────────
              _buildSectionHeader(
                'Student Information',
                'Your verified campus identity',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hintText: 'Enter your full legal name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Campus Email',
                      initialValue: widget.user.email,
                      enabled: false,
                      prefixIcon: const Icon(Icons.email_outlined),
                      helperText: 'Institutional email address cannot be changed',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _rollNoController,
                      label: 'Roll / Registration Number',
                      hintText: 'e.g. 23BCE1024',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Roll number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _collegeController,
                      label: 'Campus / College',
                      hintText: 'e.g. VIT Pune',
                      prefixIcon: const Icon(Icons.account_balance_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'College name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hintText: '10-digit mobile number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        final cleaned = v.replaceAll(RegExp(r'\D'), '');
                        if (cleaned.length < 10) {
                          return 'Please enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Gender selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender Identity',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _genderOptions.map((g) {
                            final isSelected = _selectedGender == g;
                            return ChoiceChip(
                              label: Text(_formatGenderLabel(g)),
                              selected: isSelected,
                              selectedColor: AppColors.primaryContainer,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedGender = g);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Section 2: Emergency Contact ───────────────────────────
              _buildSectionHeader(
                'Emergency Contact',
                'Used for passenger safety verification and incident response',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _emergencyNameController,
                      label: 'Contact Person Name',
                      hintText: 'Parent / Guardian name',
                      prefixIcon: const Icon(Icons.contact_emergency_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _emergencyPhoneController,
                      label: 'Emergency Contact Phone',
                      hintText: '10-digit mobile number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final cleaned = v.replaceAll(RegExp(r'\D'), '');
                          if (cleaned.length < 10) {
                            return 'Enter a valid 10-digit emergency number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _emergencyRelationController,
                      label: 'Relationship',
                      hintText: 'e.g. Father, Mother, Guardian',
                      prefixIcon: const Icon(Icons.family_restroom_outlined),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Save & Cancel Actions ──────────────────────────────────
              AppPrimaryButton(
                text: 'Save Changes',
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                text: 'Discard Changes',
                variant: SecondaryButtonVariant.outlined,
                onPressed: () => Navigator.pop(context),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

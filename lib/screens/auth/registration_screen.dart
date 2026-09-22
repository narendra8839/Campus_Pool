import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../navigation/main_navigation_shell.dart';

/// CampusFlow Registration Screen for VIT Students
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Account Details
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _collegeController = TextEditingController(text: 'VIT Pune');
  final _rollNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Gender Selection for safety preferences
  String _selectedGender = 'prefer_not_to_say';

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _rollNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        college: _collegeController.text.trim(),
        rollNumber: _rollNumberController.text.trim(),
        gender: _selectedGender,
        roles: const ['rider', 'driver'], // Unified role for all campus students
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Account created successfully! Welcome, ${user.name}.'),
            backgroundColor: AppColors.secondary,
          ),
        );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationShell(initialIndex: 0),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.sm,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Header Section
                  Text(
                    'CampusFlow',
                    style: AppTypography.headlineLg.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Create your VIT student account to start pooling.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Registration Form Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name
                          AppTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hintText: 'Jane Doe',
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Campus Email (@vit.edu restriction)
                          AppTextField(
                            controller: _emailController,
                            label: 'VIT Campus Email',
                            hintText: 'firstname.lastname@vit.edu',
                            helperText: 'Only official @vit.edu emails are allowed',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your campus email';
                              }
                              final email = value.trim().toLowerCase();
                              if (!email.endsWith('@vit.edu')) {
                                return 'Only @vit.edu emails are allowed (e.g. name@vit.edu)';
                              }
                              if (email == '@vit.edu' || !email.contains(RegExp(r'^.+@vit\.edu$'))) {
                                return 'Please enter a valid @vit.edu email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Phone Number
                          AppTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hintText: '+91 98765 43210',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                                return 'Please enter a valid 10-digit phone number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // College & Roll Number
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _collegeController,
                                  label: 'College',
                                  hintText: 'VIT Pune',
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: const Icon(Icons.school_outlined),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppTextField(
                                  controller: _rollNumberController,
                                  label: 'PRN / Roll No',
                                  hintText: '12110001',
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Gender Selection
                          Text(
                            'Gender (for ride filter preferences)',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.radiusMd,
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppSpacing.radiusMd,
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppSpacing.radiusMd,
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGender = val);
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: AppSpacing.md),

                          // Password
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hintText: '••••••••',
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Confirm Password
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hintText: '••••••••',
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            onSubmitted: (_) => _handleRegister(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Create Account Button
                          AppPrimaryButton(
                            text: 'Create Account',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: _isLoading,
                            onPressed: _handleRegister,
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Back to Login Button
                          AppSecondaryButton(
                            text: 'Already have an account? Login',
                            variant: SecondaryButtonVariant.tinted,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

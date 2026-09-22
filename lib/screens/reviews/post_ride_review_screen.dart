import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../services/review_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class PostRideReviewScreen extends StatefulWidget {
  const PostRideReviewScreen({super.key, required this.rideId, required this.revieweeId, required this.revieweeName});
  final String rideId;
  final String revieweeId;
  final String revieweeName;

  @override
  State<PostRideReviewScreen> createState() => _PostRideReviewScreenState();
}

class _PostRideReviewScreenState extends State<PostRideReviewScreen> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ReviewService.submitReview(rideId: widget.rideId, revieweeId: widget.revieweeId, rating: _rating, comment: _comment.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit review: $error'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Rate your ride'), backgroundColor: AppColors.background),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Column(children: [
        const SizedBox(height: AppSpacing.lg),
        CircleAvatar(radius: 38, backgroundColor: AppColors.primaryContainer, child: Text(widget.revieweeName.isEmpty ? 'D' : widget.revieweeName[0].toUpperCase(), style: AppTypography.headlineLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: AppSpacing.md),
        Text('How was your ride with ${widget.revieweeName}?', style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text('Your feedback helps keep Campus Pool safe and reliable.', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        AppCard(child: Column(children: [
          Text(_rating == 5 ? 'Excellent' : _rating == 4 ? 'Good' : _rating == 3 ? 'Okay' : _rating == 2 ? 'Not great' : 'Poor', style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(tooltip: '${i + 1} stars', onPressed: () => setState(() => _rating = i + 1), iconSize: 42, icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.tertiaryLight)))),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _comment, label: 'Feedback (optional)', hintText: 'Tell us what went well or could improve', maxLines: 4),
        ])),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(text: 'Submit review', icon: Icons.send_rounded, isLoading: _submitting, onPressed: _submit),
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Maybe later')),
      ]),
    )),
  );
}

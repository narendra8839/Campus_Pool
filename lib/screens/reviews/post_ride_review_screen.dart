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
  bool _analyzing = false;
  String? _sentiment;
  String? _analysisError;
  int _analysisRequestId = 0;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  void _onCommentChanged(String _) {
    setState(() {
      if (_sentiment != null || _analysisError != null || _analyzing) {
        _analysisRequestId++;
        _analyzing = false;
        _sentiment = null;
        _analysisError = null;
      }
    });
  }

  Future<void> _analyzeComment() async {
    final text = _comment.text.trim();
    if (_analyzing || text.isEmpty || text.length > 5000) return;
    final requestId = ++_analysisRequestId;
    setState(() {
      _analyzing = true;
      _sentiment = null;
      _analysisError = null;
    });
    try {
      final result = await ReviewService.analyzeSentiment(text);
      if (!mounted || requestId != _analysisRequestId) return;
      setState(() {
        _sentiment = result.label;
        _analyzing = false;
      });
    } catch (error) {
      if (!mounted || requestId != _analysisRequestId) return;
      debugPrint('Could not analyze review sentiment: $error');
      setState(() {
        _analysisError = 'Could not analyze this comment. You can still submit your review.';
        _analyzing = false;
      });
    }
  }

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
          AppTextField(
            controller: _comment,
            label: 'Feedback (optional)',
            hintText: 'Tell us what went well or could improve',
            maxLines: 4,
            onChanged: _onCommentChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSecondaryButton(
              text: 'Analyze review',
              icon: Icons.auto_awesome_outlined,
              fullWidth: false,
              isLoading: _analyzing,
              onPressed: _comment.text.trim().isEmpty ||
                      _comment.text.trim().length > 5000 ||
                      _submitting
                  ? null
                  : _analyzeComment,
            ),
          ),
          if (_comment.text.trim().length > 5000) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Keep the comment under 5000 characters to analyze it.',
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ),
          ],
          if (_sentiment != null) ...[
            const SizedBox(height: AppSpacing.md),
            _SentimentResult(label: _sentiment!),
          ],
          if (_analysisError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _analysisError!,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Optional tone suggestion based on your comment. It does not affect your rating or review.',
              style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ])),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(text: 'Submit review', icon: Icons.send_rounded, isLoading: _submitting, onPressed: _submit),
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context), child: const Text('Maybe later')),
      ]),
    )),
  );
}

class _SentimentResult extends StatelessWidget {
  const _SentimentResult({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (label) {
      'positive' => (Icons.sentiment_satisfied_alt_rounded, AppColors.secondary),
      'negative' => (Icons.sentiment_dissatisfied_rounded, AppColors.error),
      _ => (Icons.sentiment_neutral_rounded, AppColors.tertiary),
    };
    final title = '${label[0].toUpperCase()}${label.substring(1)} tone';

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.labelMd.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

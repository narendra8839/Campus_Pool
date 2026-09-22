import 'package:flutter/material.dart';
import '../../components/components.dart';
import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({super.key, required this.userId});
  final String userId;
  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  late Future<List<ReviewModel>> _reviews;
  @override
  void initState() { super.initState(); _reviews = ReviewService.getUserReviews(widget.userId); }
  void _reload() => setState(() => _reviews = ReviewService.getUserReviews(widget.userId));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('My reviews'), backgroundColor: AppColors.background),
    body: FutureBuilder<List<ReviewModel>>(
      future: _reviews,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44), const SizedBox(height: AppSpacing.md), Text('Could not load your reviews', style: AppTypography.headlineSm), TextButton(onPressed: _reload, child: const Text('Try again'))])));
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.reviews_outlined, size: 52, color: AppColors.onSurfaceVariant), const SizedBox(height: AppSpacing.md), Text('No reviews yet', style: AppTypography.headlineSm), const SizedBox(height: AppSpacing.xs), Text('Feedback from completed rides will appear here.', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center)])));
        final average = reviews.fold<int>(0, (sum, review) => sum + review.rating) / reviews.length;
        return RefreshIndicator(onRefresh: () async => _reload(), child: ListView.separated(padding: const EdgeInsets.all(AppSpacing.marginMobile), itemCount: reviews.length + 1, separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm), itemBuilder: (context, index) {
          if (index == 0) return AppCard(backgroundColor: AppColors.primaryTint, child: Row(children: [const Icon(Icons.star_rounded, color: AppColors.tertiaryLight, size: 32), const SizedBox(width: AppSpacing.md), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(average.toStringAsFixed(1), style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w800)), Text('${reviews.length} review${reviews.length == 1 ? '' : 's'} received', style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant))])]));
          final review = reviews[index - 1];
          final name = review.reviewer?.name.isNotEmpty == true ? review.reviewer!.name : 'Campus Pool member';
          return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(child: Text(name[0].toUpperCase())), const SizedBox(width: AppSpacing.sm), Expanded(child: Text(name, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700))), ...List.generate(5, (star) => Icon(star < review.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.tertiaryLight, size: 16))]), if (review.comment?.trim().isNotEmpty == true) ...[const SizedBox(height: AppSpacing.sm), Text(review.comment!, style: AppTypography.bodyMd)], const SizedBox(height: AppSpacing.xs), Text('${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}', style: AppTypography.caption.copyWith(color: AppColors.onSurfaceVariant))]));
        }));
      },
    ),
  );
}

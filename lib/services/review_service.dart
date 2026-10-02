import '../models/review_model.dart';
import 'api_service.dart';

class ReviewSentiment {
  const ReviewSentiment({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

class ReviewService {
  static Future<ReviewSentiment> analyzeSentiment(String text) async {
    final response = await ApiService.post(
      '/reviews/sentiment',
      requiresAuth: true,
      body: {'text': text.trim()},
    );
    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      final label = data['sentiment'];
      final confidence = data['confidence'];
      if (label is String &&
          const {'negative', 'neutral', 'positive'}.contains(label) &&
          confidence is num &&
          confidence.isFinite &&
          confidence >= 0 &&
          confidence <= 1) {
        return ReviewSentiment(
          label: label,
          confidence: confidence.toDouble(),
        );
      }
    }
    throw ApiException('Unexpected sentiment response.');
  }

  static Future<ReviewModel> submitReview({
    required String rideId,
    required String revieweeId,
    required int rating,
    String comment = '',
  }) async {
    final response = await ApiService.post(
      '/reviews',
      requiresAuth: true,
      body: {
        'rideId': rideId,
        'revieweeId': revieweeId,
        'rating': rating,
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return ReviewModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw ApiException('Unexpected review response.');
  }

  static Future<List<ReviewModel>> getUserReviews(String userId) async {
    final response = await ApiService.get('/reviews/user/$userId');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ReviewModel.fromJson)
          .toList();
    }
    throw ApiException('Unexpected reviews response.');
  }
}

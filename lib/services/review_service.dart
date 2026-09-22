import '../models/review_model.dart';
import 'api_service.dart';

class ReviewService {
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

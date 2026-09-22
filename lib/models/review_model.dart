import 'user_model.dart';

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rideId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.reviewer,
  });

  final String id;
  final String rideId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final UserModel? reviewer;

  // Compatibility aliases for earlier ride-review payloads.
  String get riderId => reviewerId;
  String get driverId => revieweeId;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewerJson = json['reviewer'];
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      reviewerId: json['reviewerId']?.toString() ?? json['riderId']?.toString() ?? '',
      revieweeId: json['revieweeId']?.toString() ?? json['driverId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      reviewer: reviewerJson is Map<String, dynamic> ? UserModel.fromJson(reviewerJson) : null,
    );
  }
}

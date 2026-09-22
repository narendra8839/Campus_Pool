import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../models/review_model.dart';
import 'api_service.dart';

class RideService {
  /// Search for rides based on query parameters
  static Future<List<RideModel>> searchRides(
    Map<String, String> queryParams,
  ) async {
    final query = queryParams.isEmpty
        ? ''
        : '?${Uri(queryParameters: queryParams).query}';
    final response = await ApiService.get('/rides$query', requiresAuth: true);

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => RideModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get details of a specific ride by ID
  static Future<RideModel> getRideDetail(String rideId) async {
    final response = await ApiService.get('/rides/$rideId', requiresAuth: true);

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return RideModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Offer a new ride (create a ride)
  static Future<RideModel> offerRide(Map<String, dynamic> rideData) async {
    final response = await ApiService.post(
      '/rides',
      body: rideData,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return RideModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get rides for the current user
  static Future<List<RideModel>> getMyRides() async {
    final response = await ApiService.get(
      '/rides/my-rides',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => RideModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Update the status of a ride
  static Future<RideModel> updateRideStatus(
    String rideId,
    String status,
  ) async {
    final response = await ApiService.patch(
      '/rides/$rideId/status',
      body: {'status': status},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return RideModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Cancel a ride
  static Future<RideModel> cancelRide(String rideId) async {
    final response = await ApiService.delete(
      '/rides/$rideId',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return RideModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Book a ride (create a booking)
  static Future<BookingModel> bookRide(String rideId) async {
    final response = await ApiService.post(
      '/rides/$rideId/book',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return BookingModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get bookings for a ride (for drivers)
  static Future<List<BookingModel>> getRideBookings(String rideId) async {
    final response = await ApiService.get(
      '/rides/$rideId/bookings',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => BookingModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Create a review for a ride
  static Future<ReviewModel> createReview(
    String rideId,
    Map<String, dynamic> reviewData,
  ) async {
    final response = await ApiService.post(
      '/rides/$rideId/reviews',
      body: reviewData,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return ReviewModel.fromJson(response['data']);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get reviews for a ride
  static Future<List<ReviewModel>> getRideReviews(String rideId) async {
    final response = await ApiService.get(
      '/rides/$rideId/reviews',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }
}

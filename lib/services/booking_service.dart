import '../models/booking_model.dart';
import 'api_service.dart';

class BookingService {
  /// Request a booking for a ride (create a booking)
  static Future<BookingModel> requestBooking(String rideId) async {
    final response = await ApiService.post(
      '/rides/$rideId/book',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return BookingModel.fromJson(response);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// List bookings for the current user
  static Future<List<BookingModel>> listUserBookings() async {
    final response = await ApiService.get(
      '/bookings',
      requiresAuth: true,
    );

    if (response is List) {
      return response.map((json) => BookingModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get booking requests for rides offered by the current user (driver)
  static Future<List<BookingModel>> getDriverBookingRequests() async {
    final response = await ApiService.get(
      '/bookings?driver=true',
      requiresAuth: true,
    );

    if (response is List) {
      return response.map((json) => BookingModel.fromJson(json)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Respond to a booking request (accept or reject)
  static Future<BookingModel> respondToBookingRequest(
      String bookingId, String response) async {
    final responseData = await ApiService.patch(
      '/bookings/$bookingId/respond',
      body: {'response': response},
      requiresAuth: true,
    );

    if (responseData is Map<String, dynamic>) {
      return BookingModel.fromJson(responseData);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Cancel a booking
  static Future<BookingModel> cancelBooking(String bookingId) async {
    final response = await ApiService.patch(
      '/bookings/$bookingId/cancel',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return BookingModel.fromJson(response);
    } else {
      throw Exception('Unexpected response format');
    }
  }
}
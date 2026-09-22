import '../models/booking_model.dart';
import 'api_service.dart';

class BookingService {
  /// Request a booking for a ride (create a booking)
  static Future<BookingModel> requestBooking({
    required String rideId,
    required String pickupName,
    required String dropName,
    int seatsRequested = 1,
    String? passengerNote,
    double pickupLat = 0.0,
    double pickupLng = 0.0,
    double dropLat = 0.0,
    double dropLng = 0.0,
  }) async {
    final response = await ApiService.post(
      '/bookings',
      requiresAuth: true,
      body: {
        'rideId': rideId,
        'pickupName': pickupName,
        'dropName': dropName,
        'seatsRequested': seatsRequested,
        if (passengerNote != null && passengerNote.isNotEmpty) 'passengerNote': passengerNote,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropLat': dropLat,
        'dropLng': dropLng,
      },
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return BookingModel.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// List bookings for the current user (passenger)
  static Future<List<BookingModel>> listUserBookings() async {
    final response = await ApiService.get(
      '/bookings/my-bookings',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else if (response is List) {
      return response.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get all incoming booking requests across all rides for the driver
  static Future<List<BookingModel>> getDriverBookingRequests({
    String? status,
    String? rideId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (rideId != null && rideId.isNotEmpty) queryParams['rideId'] = rideId;

    final queryStr = queryParams.isNotEmpty
        ? '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    final response = await ApiService.get(
      '/bookings/driver-requests$queryStr',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else if (response is List) {
      return response.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Get booking requests for a specific ride offered by the current driver
  static Future<List<BookingModel>> getRideBookings(String rideId) async {
    final response = await ApiService.get(
      '/bookings/ride/$rideId',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final List<dynamic> data = response['data'];
      return data.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else if (response is List) {
      return response.map((json) => BookingModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Respond to a booking request (driver accepts or rejects: 'ACCEPTED' or 'REJECTED')
  static Future<BookingModel> respondToBookingRequest(
    String bookingId,
    String status, {
    String? driverResponseNote,
  }) async {
    final responseData = await ApiService.patch(
      '/bookings/$bookingId/respond',
      body: {
        'status': status,
        if (driverResponseNote != null && driverResponseNote.isNotEmpty)
          'driverResponseNote': driverResponseNote,
      },
      requiresAuth: true,
    );

    if (responseData is Map<String, dynamic> && responseData['data'] is Map<String, dynamic>) {
      return BookingModel.fromJson(responseData['data'] as Map<String, dynamic>);
    } else {
      throw Exception('Unexpected response format');
    }
  }

  /// Verify passenger boarding OTP
  static Future<dynamic> verifyBookingOtp(String bookingId, String otp) async {
    final response = await ApiService.post(
      '/bookings/$bookingId/verify-otp',
      body: {'otp': otp},
      requiresAuth: true,
    );

    return response;
  }

  /// Cancel a booking (passenger or driver)
  static Future<BookingModel> cancelBooking(String bookingId) async {
    final response = await ApiService.patch(
      '/bookings/$bookingId/cancel',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return BookingModel.fromJson(response['data'] as Map<String, dynamic>);
    } else {
      throw Exception('Unexpected response format');
    }
  }
}
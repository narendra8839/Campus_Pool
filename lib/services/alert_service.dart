import '../models/alert_model.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';
import 'booking_service.dart';
import 'ride_service.dart';

class AlertService {
  /// Builds the MVP activity feed from existing authenticated ride data.
  static Future<List<AlertModel>> loadActivity() async {
    final results = await Future.wait([
      BookingService.listUserBookings(),
      BookingService.getDriverBookingRequests(),
      RideService.getMyRides(),
    ]);
    final passengerBookings = results[0] as List<BookingModel>;
    final driverBookings = results[1] as List<BookingModel>;
    final rides = results[2] as List<RideModel>;
    final alerts = <AlertModel>[
      ...passengerBookings.map(_passengerBookingAlert),
      ...driverBookings.map(_driverBookingAlert),
      ...rides.where((ride) => ride.status == 'ONGOING' || ride.status == 'COMPLETED').map(_rideAlert),
    ];
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return alerts;
  }

  static AlertModel _passengerBookingAlert(BookingModel booking) {
    final driverName = booking.ride?.driver?.name ?? 'Your driver';
    final status = booking.status.toUpperCase();
    final config = switch (status) {
      'ACCEPTED' => ('Booking accepted', '$driverName accepted your booking. Your boarding OTP is ready.', AlertPriority.success),
      'REJECTED' => ('Booking update', '$driverName could not accept your booking.', AlertPriority.warning),
      'CANCELLED' => ('Booking cancelled', 'Your booking has been cancelled.', AlertPriority.warning),
      'COMPLETED' => ('Ride completed', 'Your ride with $driverName is complete. You can leave a review.', AlertPriority.success),
      _ => ('Booking requested', 'Your booking request is waiting for $driverName.', AlertPriority.info),
    };
    return AlertModel(id: 'passenger-${booking.id}', type: AlertType.bookingUpdate, priority: config.$3, title: config.$1, message: config.$2, createdAt: booking.updatedAt, rideId: booking.rideId, bookingId: booking.id);
  }

  static AlertModel _driverBookingAlert(BookingModel booking) {
    final passengerName = booking.passenger?.name ?? 'A passenger';
    final pending = booking.status == 'PENDING';
    return AlertModel(
      id: 'driver-${booking.id}', type: pending ? AlertType.bookingRequest : AlertType.bookingUpdate,
      priority: pending ? AlertPriority.urgent : AlertPriority.info,
      title: pending ? 'New booking request' : 'Passenger booking ${booking.status.toLowerCase()}',
      message: pending ? '$passengerName requested ${booking.seatsRequested} seat${booking.seatsRequested == 1 ? '' : 's'} for your ride.' : '$passengerName’s booking is ${booking.status.toLowerCase()}.',
      createdAt: booking.updatedAt, rideId: booking.rideId, bookingId: booking.id,
    );
  }

  static AlertModel _rideAlert(RideModel ride) => AlertModel(
    id: 'ride-${ride.id}-${ride.status}', type: AlertType.rideUpdate,
    priority: ride.status == 'COMPLETED' ? AlertPriority.success : AlertPriority.info,
    title: ride.status == 'COMPLETED' ? 'Ride completed' : 'Ride is ongoing',
    message: '${ride.originName} to ${ride.destName} is ${ride.status.toLowerCase()}.',
    createdAt: ride.updatedAt, rideId: ride.id,
  );
}

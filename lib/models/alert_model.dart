enum AlertType { bookingRequest, bookingUpdate, rideUpdate, system }

enum AlertPriority { info, success, warning, urgent }

/// A small, client-side activity record for the MVP.
///
/// Alerts are derived from the user's booking and ride data until a dedicated
/// notifications API is introduced.
class AlertModel {
  const AlertModel({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.rideId,
    this.bookingId,
  });

  final String id;
  final AlertType type;
  final AlertPriority priority;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? rideId;
  final String? bookingId;

  AlertModel copyWith({bool? isRead}) => AlertModel(
        id: id,
        type: type,
        priority: priority,
        title: title,
        message: message,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        rideId: rideId,
        bookingId: bookingId,
      );
}

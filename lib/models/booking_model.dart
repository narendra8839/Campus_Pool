import 'ride_model.dart';
import 'user_model.dart';

class BookingModel {
  final String id;
  final String rideId;
  final String passengerId;
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String dropName;
  final double dropLat;
  final double dropLng;
  final int seatsRequested;
  final String status;
  final String passengerNote;
  final String driverResponseNote;
  final double fareAmount;
  final String verificationOtp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? passenger;
  final RideModel? ride;

  BookingModel({
    required this.id,
    required this.rideId,
    required this.passengerId,
    this.pickupName = '',
    this.pickupLat = 0.0,
    this.pickupLng = 0.0,
    this.dropName = '',
    this.dropLat = 0.0,
    this.dropLng = 0.0,
    this.seatsRequested = 1,
    required this.status,
    this.passengerNote = '',
    this.driverResponseNote = '',
    this.fareAmount = 0.0,
    this.verificationOtp = '',
    required this.createdAt,
    required this.updatedAt,
    this.passenger,
    this.ride,
  });

  // Backwards compatibility getters
  String get userId => passengerId;
  DateTime get bookingTime => createdAt;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    UserModel? parsedPassenger;
    if (json['passenger'] is Map<String, dynamic>) {
      parsedPassenger = UserModel.fromJson(json['passenger']);
    }

    RideModel? parsedRide;
    if (json['ride'] is Map<String, dynamic>) {
      parsedRide = RideModel.fromJson(json['ride']);
    }

    final passId = _parseString(
      json,
      'passengerId',
      defaultValue: _parseString(json, 'userId', defaultValue: ''),
    );
    final created =
        _parseDateTime(json, 'createdAt') ??
        _parseDateTime(json, 'bookingTime') ??
        DateTime.now();
    final updated = _parseDateTime(json, 'updatedAt') ?? created;

    return BookingModel(
      id: _parseString(json, 'id', defaultValue: _generateDefaultId()),
      rideId: _parseString(json, 'rideId', defaultValue: ''),
      passengerId: passId,
      pickupName: _parseString(json, 'pickupName'),
      pickupLat: _parseDouble(json, 'pickupLat') ?? 0.0,
      pickupLng: _parseDouble(json, 'pickupLng') ?? 0.0,
      dropName: _parseString(json, 'dropName'),
      dropLat: _parseDouble(json, 'dropLat') ?? 0.0,
      dropLng: _parseDouble(json, 'dropLng') ?? 0.0,
      seatsRequested: _parseInt(json, 'seatsRequested') ?? 1,
      status: _parseString(json, 'status', defaultValue: 'PENDING'),
      passengerNote: _parseString(json, 'passengerNote'),
      driverResponseNote: _parseString(json, 'driverResponseNote'),
      fareAmount: _parseDouble(json, 'fareAmount') ?? 0.0,
      verificationOtp: _parseString(json, 'verificationOtp'),
      createdAt: created,
      updatedAt: updated,
      passenger: parsedPassenger,
      ride: parsedRide,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'passengerId': passengerId,
      'pickupName': pickupName,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropName': dropName,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'seatsRequested': seatsRequested,
      'status': status,
      'passengerNote': passengerNote,
      'driverResponseNote': driverResponseNote,
      'fareAmount': fareAmount,
      'verificationOtp': verificationOtp,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'passenger': passenger?.toJson(),
      'ride': ride?.toJson(),
    };
  }

  static String _parseString(
    Map<String, dynamic> json,
    String key, {
    String defaultValue = '',
  }) {
    if (json[key] is String) {
      return json[key] as String;
    }
    return defaultValue;
  }

  static double? _parseDouble(Map<String, dynamic> json, String key) {
    final val = json[key];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static int? _parseInt(Map<String, dynamic> json, String key) {
    final val = json[key];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  static DateTime? _parseDateTime(Map<String, dynamic> json, String key) {
    final val = json[key];
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    return null;
  }

  static String _generateDefaultId() {
    return 'booking_${DateTime.now().millisecondsSinceEpoch}';
  }
}

import 'booking_model.dart';
import 'user_model.dart';
import 'corridor_model.dart';

class RideModel {
  final String id;
  final String driverId;
  final String? corridorId;
  final HubModel? originHub;
  final HubModel? destinationHub;
  final UserModel? driver;
  final String originName;
  final String originAddress;
  final double originLat;
  final double originLng;
  final String destName;
  final String destAddress;
  final double destLat;
  final double destLng;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;
  final String vehicleType;
  final bool helmetProvided;
  final double contribution;
  final double? matchAcceptanceProbability;
  final String notes;
  final String status;
  final List<BookingModel> bookings;
  final DateTime createdAt;
  final DateTime updatedAt;

  RideModel({
    required this.id,
    required this.driverId,
    this.corridorId,
    this.originHub,
    this.destinationHub,
    this.driver,
    required this.originName,
    this.originAddress = '',
    this.originLat = 0.0,
    this.originLng = 0.0,
    required this.destName,
    this.destAddress = '',
    this.destLat = 0.0,
    this.destLng = 0.0,
    required this.departureTime,
    this.totalSeats = 1,
    this.availableSeats = 1,
    this.vehicleType = 'bike',
    this.helmetProvided = true,
    this.contribution = 0.0,
    this.matchAcceptanceProbability,
    this.notes = '',
    this.status = 'SCHEDULED',
    this.bookings = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Backwards compatibility getters
  String get startLocation => originName;
  String get endLocation => destName;
  DateTime get startTime => departureTime;
  DateTime? get endTime => null;
  double? get fare => contribution;
  int? get seatsAvailable => availableSeats;
  String get riderId => driverId;

  factory RideModel.fromJson(Map<String, dynamic> json) {
    UserModel? parsedDriver;
    if (json['driver'] is Map<String, dynamic>) {
      parsedDriver = UserModel.fromJson(json['driver']);
    }

    List<BookingModel> parsedBookings = [];
    if (json['bookings'] is List) {
      parsedBookings = (json['bookings'] as List)
          .whereType<Map<String, dynamic>>()
          .map((b) => BookingModel.fromJson(b))
          .toList();
    }

    final origin = json['originName'] ?? json['startLocation'] ?? '';
    final dest = json['destName'] ?? json['endLocation'] ?? '';
    final depTime =
        _parseDateTime(json, 'departureTime') ??
        _parseDateTime(json, 'startTime') ??
        DateTime.now();

    final seats =
        _parseInt(json, 'availableSeats') ??
        _parseInt(json, 'seatsAvailable') ??
        _parseInt(json, 'totalSeats') ??
        1;
    final total = _parseInt(json, 'totalSeats') ?? seats;

    final fareVal =
        _parseDouble(json, 'contribution') ?? _parseDouble(json, 'fare') ?? 0.0;

    return RideModel(
      id: _parseString(json, 'id', defaultValue: _generateDefaultId()),
      driverId: _parseString(
        json,
        'driverId',
        defaultValue: _parseString(json, 'riderId', defaultValue: ''),
      ),
      corridorId: _parseString(json, 'corridorId', defaultValue: ''),
      originHub: json['originHub'] is Map<String, dynamic>
          ? HubModel.fromJson(json['originHub'] as Map<String, dynamic>)
          : null,
      destinationHub: json['destinationHub'] is Map<String, dynamic>
          ? HubModel.fromJson(json['destinationHub'] as Map<String, dynamic>)
          : null,
      driver: parsedDriver,
      originName: origin,
      originAddress: _parseString(json, 'originAddress'),
      originLat: _parseDouble(json, 'originLat') ?? 0.0,
      originLng: _parseDouble(json, 'originLng') ?? 0.0,
      destName: dest,
      destAddress: _parseString(json, 'destAddress'),
      destLat: _parseDouble(json, 'destLat') ?? 0.0,
      destLng: _parseDouble(json, 'destLng') ?? 0.0,
      departureTime: depTime,
      totalSeats: total,
      availableSeats: seats,
      vehicleType: _parseString(json, 'vehicleType', defaultValue: 'bike'),
      helmetProvided: json['helmetProvided'] is bool
          ? json['helmetProvided']
          : true,
      contribution: fareVal,
      matchAcceptanceProbability: _parseDouble(
        json,
        'matchAcceptanceProbability',
      ),
      notes: _parseString(json, 'notes'),
      status: _parseString(json, 'status', defaultValue: 'SCHEDULED'),
      bookings: parsedBookings,
      createdAt: _parseDateTime(json, 'createdAt') ?? DateTime.now(),
      updatedAt: _parseDateTime(json, 'updatedAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'corridorId': corridorId,
      'originHub': originHub == null
          ? null
          : {
              'id': originHub!.id,
              'name': originHub!.name,
              'normalizedName': originHub!.normalizedName,
              'latitude': originHub!.latitude,
              'longitude': originHub!.longitude,
              'sequence': originHub!.sequence,
            },
      'destinationHub': destinationHub == null
          ? null
          : {
              'id': destinationHub!.id,
              'name': destinationHub!.name,
              'normalizedName': destinationHub!.normalizedName,
              'latitude': destinationHub!.latitude,
              'longitude': destinationHub!.longitude,
              'sequence': destinationHub!.sequence,
            },
      'driver': driver?.toJson(),
      'originName': originName,
      'originAddress': originAddress,
      'originLat': originLat,
      'originLng': originLng,
      'destName': destName,
      'destAddress': destAddress,
      'destLat': destLat,
      'destLng': destLng,
      'departureTime': departureTime.toIso8601String(),
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'vehicleType': vehicleType,
      'helmetProvided': helmetProvided,
      'contribution': contribution,
      'matchAcceptanceProbability': matchAcceptanceProbability,
      'notes': notes,
      'status': status,
      'bookings': bookings.map((b) => b.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
    return 'ride_${DateTime.now().millisecondsSinceEpoch}';
  }
}

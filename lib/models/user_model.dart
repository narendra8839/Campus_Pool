class VehicleModel {
  final String type;
  final String model;
  final String plateNumber;
  final String color;
  final bool helmetProvided;
  final int totalSeats;

  VehicleModel({
    this.type = 'bike',
    this.model = '',
    this.plateNumber = '',
    this.color = '',
    this.helmetProvided = true,
    this.totalSeats = 1,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      type: json['type'] ?? json['vehicleType'] ?? 'bike',
      model: json['model'] ?? json['vehicleModel'] ?? '',
      plateNumber: json['plateNumber'] ?? json['vehiclePlate'] ?? '',
      color: json['color'] ?? json['vehicleColor'] ?? '',
      helmetProvided: json['helmetProvided'] ?? true,
      totalSeats: json['totalSeats'] ?? json['vehicleSeats'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'model': model,
      'plateNumber': plateNumber,
      'color': color,
      'helmetProvided': helmetProvided,
      'totalSeats': totalSeats,
    };
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String college;
  final String rollNumber;
  final String gender;
  final String? avatar;
  final List<String> roles;
  final VehicleModel? vehicle;
  final double ratingAvg;
  final int ratingCount;
  final bool isVerified;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;
  final String? token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.college = '',
    this.rollNumber = '',
    this.gender = 'prefer_not_to_say',
    this.avatar,
    this.roles = const ['rider'],
    this.vehicle,
    this.ratingAvg = 5.0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.token,
  });

  bool get isDriver => roles.contains('driver');
  bool get isRider => roles.contains('rider');
  String get vehicleModel => vehicle?.model ?? '';
  String get vehiclePlate => vehicle?.plateNumber ?? '';

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    List<String> parsedRoles = ['rider'];
    if (json['roles'] is List) {
      parsedRoles = (json['roles'] as List).map((e) => e.toString()).toList();
    }

    VehicleModel? parsedVehicle;
    if (json['vehicle'] is Map<String, dynamic>) {
      parsedVehicle = VehicleModel.fromJson(json['vehicle']);
    } else if (json['vehicleType'] != null || json['vehiclePlate'] != null) {
      parsedVehicle = VehicleModel.fromJson(json);
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      college: json['college'] ?? '',
      rollNumber: json['rollNumber'] ?? '',
      gender: json['gender'] ?? 'prefer_not_to_say',
      avatar: json['avatar'],
      roles: parsedRoles,
      vehicle: parsedVehicle,
      ratingAvg: (json['ratingAvg'] is num) ? (json['ratingAvg'] as num).toDouble() : 5.0,
      ratingCount: json['ratingCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      emergencyName: json['emergencyName']?.toString(),
      emergencyPhone: json['emergencyPhone']?.toString(),
      emergencyRelation: json['emergencyRelation']?.toString(),
      token: token ?? json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'college': college,
      'rollNumber': rollNumber,
      'gender': gender,
      'avatar': avatar,
      'roles': roles,
      'vehicle': vehicle?.toJson(),
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'isVerified': isVerified,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
      'emergencyRelation': emergencyRelation,
      'token': token,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? college,
    String? rollNumber,
    String? gender,
    String? avatar,
    List<String>? roles,
    VehicleModel? vehicle,
    double? ratingAvg,
    int? ratingCount,
    bool? isVerified,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelation,
    String? token,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      college: college ?? this.college,
      rollNumber: rollNumber ?? this.rollNumber,
      gender: gender ?? this.gender,
      avatar: avatar ?? this.avatar,
      roles: roles ?? this.roles,
      vehicle: vehicle ?? this.vehicle,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      isVerified: isVerified ?? this.isVerified,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyRelation: emergencyRelation ?? this.emergencyRelation,
      token: token ?? this.token,
    );
  }
}

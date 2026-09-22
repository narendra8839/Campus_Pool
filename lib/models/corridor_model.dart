class HubModel {
  final String id;
  final String name;
  final String normalizedName;
  final double latitude;
  final double longitude;
  final int sequence;

  const HubModel({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  factory HubModel.fromJson(Map<String, dynamic> json, {int? sequence}) {
    final hub = json['hub'] is Map<String, dynamic>
        ? json['hub'] as Map<String, dynamic>
        : json;
    return HubModel(
      id: hub['id']?.toString() ?? '',
      name: hub['name']?.toString() ?? '',
      normalizedName: hub['normalizedName']?.toString() ?? '',
      latitude: (hub['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (hub['longitude'] as num?)?.toDouble() ?? 0,
      sequence: sequence ?? (json['sequence'] as num?)?.toInt() ?? 0,
    );
  }
}

class CorridorModel {
  final String id;
  final String name;
  final String originName;
  final String destinationName;
  final List<HubModel> hubs;

  const CorridorModel({
    required this.id,
    required this.name,
    required this.originName,
    required this.destinationName,
    required this.hubs,
  });

  factory CorridorModel.fromJson(Map<String, dynamic> json) {
    final rawHubs = json['hubs'] is List ? json['hubs'] as List : const [];
    return CorridorModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      originName: json['originName']?.toString() ?? '',
      destinationName: json['destinationName']?.toString() ?? 'VIT College',
      hubs:
          rawHubs
              .whereType<Map<String, dynamic>>()
              .map((hub) => HubModel.fromJson(hub))
              .toList()
            ..sort((a, b) => a.sequence.compareTo(b.sequence)),
    );
  }

  HubModel? get vitHub {
    for (final hub in hubs) {
      if (hub.name.toLowerCase() == destinationName.toLowerCase()) return hub;
    }
    return null;
  }
}

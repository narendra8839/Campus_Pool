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
  final List<List<double>> geometryCoordinates;

  const CorridorModel({
    required this.id,
    required this.name,
    required this.originName,
    required this.destinationName,
    required this.hubs,
    required this.geometryCoordinates,
  });

  factory CorridorModel.fromJson(Map<String, dynamic> json) {
    final rawHubs = json['hubs'] is List ? json['hubs'] as List : const [];
    final routeData = json['routeData'] is Map<String, dynamic>
        ? json['routeData'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final geometry = routeData['geometry'] is Map<String, dynamic>
        ? routeData['geometry'] as Map<String, dynamic>
        : routeData['routes'] is List &&
              (routeData['routes'] as List).isNotEmpty &&
              (routeData['routes'].first is Map<String, dynamic>)
        ? ((routeData['routes'].first as Map<String, dynamic>)['geometry']
                  is Map<String, dynamic>
              ? (routeData['routes'].first as Map<String, dynamic>)['geometry']
                    as Map<String, dynamic>
              : const <String, dynamic>{})
        : const <String, dynamic>{};
    final rawCoordinates = geometry['coordinates'] is List
        ? geometry['coordinates'] as List
        : const [];
    final coordinates = rawCoordinates
        .whereType<List>()
        .where(
          (point) => point.length >= 2 && point[0] is num && point[1] is num,
        )
        .map(
          (point) => [
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ],
        )
        .toList();
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
      geometryCoordinates: coordinates,
    );
  }

  HubModel? get vitHub {
    for (final hub in hubs) {
      if (hub.name.toLowerCase() == destinationName.toLowerCase()) return hub;
    }
    return null;
  }
}

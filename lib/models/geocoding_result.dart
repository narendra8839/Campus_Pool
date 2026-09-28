class GeocodingResult {
  final String placeId;
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  const GeocodingResult({
    required this.placeId,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final latitudeValue = json['latitude'];
    final longitudeValue = json['longitude'];
    final latitude = latitudeValue is num
        ? latitudeValue.toDouble()
        : double.tryParse(latitudeValue?.toString() ?? '');
    final longitude = longitudeValue is num
        ? longitudeValue.toDouble()
        : double.tryParse(longitudeValue?.toString() ?? '');
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid coordinates in geocoding result.');
    }

    return GeocodingResult(
      placeId: json['placeId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      type: json['type']?.toString() ?? '',
    );
  }
}

class RouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<List<double>> coordinates;

  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.coordinates,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final distance = (json['distanceMeters'] as num?)?.toDouble();
    final duration = (json['durationSeconds'] as num?)?.toDouble();
    final rawCoordinates = json['coordinates'];
    if (distance == null ||
        duration == null ||
        distance < 0 ||
        duration < 0 ||
        rawCoordinates is! List) {
      throw const FormatException('Invalid route result from backend.');
    }

    final coordinates = <List<double>>[];
    for (final rawPoint in rawCoordinates) {
      if (rawPoint is! List || rawPoint.length < 2) {
        throw const FormatException('Invalid route geometry from backend.');
      }
      final longitude = (rawPoint[0] as num?)?.toDouble();
      final latitude = (rawPoint[1] as num?)?.toDouble();
      if (longitude == null ||
          latitude == null ||
          longitude < -180 ||
          longitude > 180 ||
          latitude < -90 ||
          latitude > 90) {
        throw const FormatException('Invalid route coordinate from backend.');
      }
      coordinates.add([longitude, latitude]);
    }
    if (coordinates.length < 2) {
      throw const FormatException(
        'Route geometry must contain at least two points.',
      );
    }

    return RouteResult(
      distanceMeters: distance,
      durationSeconds: duration,
      coordinates: coordinates,
    );
  }

  String get formattedDistance {
    final kilometres = distanceMeters / 1000;
    return kilometres < 1
        ? '${distanceMeters.round()} m'
        : '${kilometres.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }
}

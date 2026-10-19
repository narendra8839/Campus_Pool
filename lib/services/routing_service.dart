import '../models/route_result.dart';
import 'api_service.dart';

class RoutingService {
  static Future<List<RouteResult>> getDrivingRoutes({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    double? viaLatitude,
    double? viaLongitude,
  }) async {
    if ((viaLatitude == null) != (viaLongitude == null)) {
      throw ArgumentError('Both via coordinates must be provided together.');
    }
    final query = <String, String>{
      'originLat': originLatitude.toString(),
      'originLon': originLongitude.toString(),
      'destinationLat': destinationLatitude.toString(),
      'destinationLon': destinationLongitude.toString(),
      if (viaLatitude != null) 'viaLat': viaLatitude.toString(),
      if (viaLongitude != null) 'viaLon': viaLongitude.toString(),
    };
    final response = await ApiService.get(
      '/routing/route?${Uri(queryParameters: query).query}',
    );
    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      final rawRoutes = data['routes'];
      if (rawRoutes is List && rawRoutes.isNotEmpty) {
        return rawRoutes
            .whereType<Map<String, dynamic>>()
            .map(RouteResult.fromJson)
            .toList();
      }
      return [RouteResult.fromJson(data)];
    }
    throw const FormatException('Unexpected routing response format.');
  }

  static Future<RouteResult> getDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final routes = await getDrivingRoutes(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );
    return routes.first;
  }
}

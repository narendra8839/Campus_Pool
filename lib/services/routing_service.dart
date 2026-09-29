import '../models/route_result.dart';
import 'api_service.dart';

class RoutingService {
  static Future<RouteResult> getDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final query = <String, String>{
      'originLat': originLatitude.toString(),
      'originLon': originLongitude.toString(),
      'destinationLat': destinationLatitude.toString(),
      'destinationLon': destinationLongitude.toString(),
    };
    final response = await ApiService.get(
      '/routing/route?${Uri(queryParameters: query).query}',
    );
    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return RouteResult.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw const FormatException('Unexpected routing response format.');
  }
}

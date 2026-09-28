import '../models/geocoding_result.dart';
import 'api_service.dart';

class GeocodingService {
  static Future<List<GeocodingResult>> search(String query) async {
    final response = await ApiService.get(
      '/geocoding/search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(GeocodingResult.fromJson)
          .toList();
    }
    throw const FormatException('Unexpected place search response format.');
  }

  static Future<GeocodingResult> reverse({
    required double latitude,
    required double longitude,
  }) async {
    final response = await ApiService.get(
      '/geocoding/reverse?lat=$latitude&lon=$longitude',
    );
    if (response is Map<String, dynamic> &&
        response['data'] is Map<String, dynamic>) {
      return GeocodingResult.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw const FormatException(
      'Unexpected reverse geocoding response format.',
    );
  }
}

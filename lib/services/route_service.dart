import '../models/corridor_model.dart';
import 'api_service.dart';

class RouteService {
  static Future<List<CorridorModel>> listCorridors() async {
    final response = await ApiService.get('/routes/corridors');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(CorridorModel.fromJson)
          .toList();
    }
    throw Exception('Unexpected corridor response format');
  }
}

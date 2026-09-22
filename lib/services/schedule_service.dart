import '../models/student_schedule_model.dart';
import 'api_service.dart';

class ScheduleService {
  static Future<List<StudentScheduleModel>> getMySchedule() async {
    final response = await ApiService.get(
      '/users/me/schedule',
      requiresAuth: true,
    );
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(StudentScheduleModel.fromJson)
          .toList();
    }
    throw ApiException('Unexpected schedule response.');
  }

  static Future<List<StudentScheduleModel>> saveMySchedule(
    List<StudentScheduleModel> schedules,
  ) async {
    final response = await ApiService.put(
      '/users/me/schedule',
      body: {
        'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
      },
      requiresAuth: true,
    );
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(StudentScheduleModel.fromJson)
          .toList();
    }
    throw ApiException('Unexpected schedule response.');
  }
}

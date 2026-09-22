class StudentScheduleModel {
  final String id;
  final String userId;
  final int dayOfWeek;
  final String dayName;
  final bool hasClass;
  final String? collegeStartTime;
  final String? collegeEndTime;
  final String campusName;

  const StudentScheduleModel({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.dayName,
    required this.hasClass,
    this.collegeStartTime,
    this.collegeEndTime,
    required this.campusName,
  });

  factory StudentScheduleModel.fromJson(Map<String, dynamic> json) {
    return StudentScheduleModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      dayName: json['dayName']?.toString() ?? '',
      hasClass: json['hasClass'] == true,
      collegeStartTime: json['collegeStartTime']?.toString(),
      collegeEndTime: json['collegeEndTime']?.toString(),
      campusName: json['campusName']?.toString() ?? 'VIT College',
    );
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'dayName': dayName,
    'hasClass': hasClass,
    'collegeStartTime': collegeStartTime,
    'collegeEndTime': collegeEndTime,
    'campusName': campusName,
  };
}

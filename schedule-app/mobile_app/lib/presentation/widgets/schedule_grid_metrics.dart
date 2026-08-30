class ScheduleGridMetrics {
  static const int sectionCount = 12;
  static const double timeColumnWidth = 42;
  static const double minCourseHeight = 32;
  static const double horizontalPadding = 8;
  static const double dayGap = 2.5;

  /// 西工大常规作息时间表（长安/友谊校区参考）
  static const List<Map<String, String>> sectionTimes = [
    {'start': '08:30', 'end': '09:15'},
    {'start': '09:25', 'end': '10:10'},
    {'start': '10:30', 'end': '11:15'},
    {'start': '11:25', 'end': '12:10'},
    {'start': '14:00', 'end': '14:45'},
    {'start': '14:55', 'end': '15:40'},
    {'start': '16:00', 'end': '16:45'},
    {'start': '16:55', 'end': '17:40'},
    {'start': '19:00', 'end': '19:45'},
    {'start': '19:55', 'end': '20:40'},
    {'start': '20:50', 'end': '21:35'},
    {'start': '21:45', 'end': '22:30'},
  ];

  const ScheduleGridMetrics._();
}

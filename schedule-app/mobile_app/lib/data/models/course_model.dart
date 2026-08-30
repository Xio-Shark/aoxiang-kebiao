import '../../domain/entities/course.dart';

/// 课程持久化模型。
///
/// 兼容 camelCase、snake_case 与旧 Android 字段名。
class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.name,
    super.teacher,
    super.classroom,
    super.campus,
    required super.weekday,
    required super.startSection,
    super.sectionCount,
    required super.startWeek,
    required super.endWeek,
    super.weekPattern,
    super.customWeeks,
    super.color,
    super.note,
  });

  factory CourseModel.fromEntity(Course course) {
    return CourseModel(
      id: course.id,
      name: course.name,
      teacher: course.teacher,
      classroom: course.classroom,
      campus: course.campus,
      weekday: course.weekday,
      startSection: course.startSection,
      sectionCount: course.sectionCount,
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      weekPattern: course.weekPattern,
      customWeeks: course.customWeeks,
      color: course.color,
      note: course.note,
    );
  }

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final startWeek = _readInt(json, ['startWeek', 'start_week'], fallback: 1);

    return CourseModel(
      id: _readString(json, ['id']),
      name: _readString(json, ['name', 'courseName', 'course_name', 'title']),
      teacher: _readString(json, ['teacher', 'teach']),
      classroom: _readString(json, ['classroom', 'room', 'place']),
      campus: _readString(json, ['campus']),
      weekday: _readInt(json, ['weekday', 'day'], fallback: 1),
      startSection: _readInt(json, ['startSection', 'start_section', 'start']),
      sectionCount: _readInt(json, ['sectionCount', 'section_count', 'step']),
      startWeek: startWeek,
      endWeek: _readInt(json, ['endWeek', 'end_week'], fallback: startWeek),
      weekPattern: _readWeekPattern(json),
      customWeeks: _readIntList(json, ['customWeeks', 'custom_weeks']),
      color: _readColor(json),
      note: _readString(json, ['note', 'remark']),
    );
  }

  factory CourseModel.fromLegacyJson(Map<String, dynamic> json) {
    return CourseModel.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'classroom': classroom,
      'campus': campus,
      'weekday': weekday,
      'startSection': startSection,
      'sectionCount': sectionCount,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'weekPattern': weekPattern.name,
      'customWeeks': customWeeks,
      'color': color,
      'note': note,
    };
  }

  Course toEntity() {
    return Course(
      id: id,
      name: name,
      teacher: teacher,
      classroom: classroom,
      campus: campus,
      weekday: weekday,
      startSection: startSection,
      sectionCount: sectionCount,
      startWeek: startWeek,
      endWeek: endWeek,
      weekPattern: weekPattern,
      customWeeks: customWeeks,
      color: color,
      note: note,
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _firstValue(json, keys);
    return value == null ? fallback : value.toString().trim();
  }

  static int _readInt(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 2,
  }) {
    final value = _firstValue(json, keys);
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _readColor(Map<String, dynamic> json) {
    final value = _firstValue(json, ['color']);
    if (value is int) {
      return value;
    }
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return 0xFF4F779A;
    }
    final normalized = text.replaceFirst('#', '').replaceFirst('0x', '');
    if (normalized.isEmpty) {
      return 0xFF4F779A;
    }
    if (normalized.length == 6) {
      return int.tryParse('FF$normalized', radix: 16) ?? 0xFF4F779A;
    }
    return int.tryParse(normalized, radix: 16) ?? 0xFF4F779A;
  }

  static List<int> _readIntList(Map<String, dynamic> json, List<String> keys) {
    final value = _firstValue(json, keys);
    if (value is List) {
      final result = <int>[];
      for (final item in value) {
        final parsed = _parseIntValue(item);
        if (parsed != null) {
          result.add(parsed);
        }
      }
      return result;
    }
    return const [];
  }

  static int? _parseIntValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static WeekPattern _readWeekPattern(Map<String, dynamic> json) {
    final value = _firstValue(json, ['weekPattern', 'week_pattern']);
    final text = value?.toString().toLowerCase().trim();
    return switch (text) {
      'odd' || 'single' || '单' => WeekPattern.odd,
      'even' || 'double' || '双' => WeekPattern.even,
      'custom' => WeekPattern.custom,
      _ => WeekPattern.all,
    };
  }

  static Object? _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        return json[key];
      }
    }
    return null;
  }
}

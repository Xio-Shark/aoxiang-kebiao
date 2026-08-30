/// 课程重叠检测与分组算法
import '../../domain/entities/course.dart';

class CourseCluster {
  final List<Course> courses;

  const CourseCluster({required this.courses});

  int get startSection => courses.map((c) => c.startSection).reduce((a, b) => a < b ? a : b);
  int get endSection => courses.map((c) => c.endSection).reduce((a, b) => a > b ? a : b);
  int get sectionCount => endSection - startSection + 1;
  bool get hasConflict => courses.length > 1;
}

class CourseOverlapResolver {
  const CourseOverlapResolver._();

  /// 检测并为单日的课程计算重叠关系
  static Map<String, List<Course>> resolveConflicts(List<Course> dayCourses) {
    final conflictMap = <String, List<Course>>{};

    for (final course in dayCourses) {
      final overlapping = dayCourses.where((other) {
        return _isOverlap(course, other);
      }).toList();
      conflictMap[course.id] = overlapping;
    }

    return conflictMap;
  }

  static bool _isOverlap(Course a, Course b) {
    final start = a.startSection > b.startSection ? a.startSection : b.startSection;
    final end = a.endSection < b.endSection ? a.endSection : b.endSection;
    return start <= end;
  }
}

import 'package:aoxiang_schedule/data/models/course_model.dart';
import 'package:aoxiang_schedule/domain/entities/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseModel.fromJson 字段兼容', () {
    test('支持 snake_case 字段', () {
      final model = CourseModel.fromJson({
        'id': 's1',
        'name': '高等数学',
        'weekday': 3,
        'start_section': 1,
        'section_count': 2,
        'start_week': 2,
        'end_week': 18,
        'week_pattern': 'odd',
        'custom_weeks': [3, 5],
      });

      expect(model.startSection, 1);
      expect(model.sectionCount, 2);
      expect(model.startWeek, 2);
      expect(model.endWeek, 18);
      expect(model.weekPattern, WeekPattern.odd);
      expect(model.customWeeks, [3, 5]);
    });

    test('支持 wrapped courses 里的对象字段', () {
      final model = CourseModel.fromJson({
        'id': 's2',
        'name': '大学物理',
        'weekday': 5,
        'startSection': 3,
        'section_count': 3,
        'start_week': 1,
        'endWeek': 16,
      });

      expect(model.startSection, 3);
      expect(model.sectionCount, 3);
      expect(model.startWeek, 1);
      expect(model.endWeek, 16);
    });

    test('缺少结束周时回退到开始周', () {
      final model = CourseModel.fromJson({
        'id': 's3',
        'name': '线性代数',
        'weekday': 2,
        'startSection': 5,
        'sectionCount': 2,
        'startWeek': 10,
      });

      expect(model.startWeek, 10);
      expect(model.endWeek, 10);
    });
  });
}

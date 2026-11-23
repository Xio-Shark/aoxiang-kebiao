import 'package:aoxiang_schedule/data/datasources/parsers/json_schedule_parser.dart';
import 'package:aoxiang_schedule/data/services/course_reminder_service.dart';
import 'package:aoxiang_schedule/domain/entities/course.dart';
import 'package:aoxiang_schedule/domain/entities/section_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionTimeTable 西工大 13 节作息与时间映射', () {
    test('西工大长安校区 14:00-15:40 正确映射为第 7-8 节，19:00-21:35 映射为 11-13 节', () {
      const table = SectionTimeTable.nwpuChangan;
      expect(table.sectionCount, 13);
      expect(table.formatCourseClockRange(1, 2), '08:30-10:10');
      expect(table.formatCourseClockRange(7, 2), '14:00-15:40');
      expect(table.formatCourseClockRange(11, 3), '19:00-21:35');

      final afternoon = table.mapMinutesToSections(14 * 60, 15 * 60 + 40);
      expect(afternoon, (7, 8));

      final evening3 = table.mapMinutesToSections(19 * 60, 21 * 60 + 35);
      expect(evening3, (11, 13));
    });

    test('支持从树维接口 courseUnitList 自动提取上下课作息时间表', () {
      final decoded = {
        'timeTableLayout': {
          'courseUnitList': [
            {'indexNo': 1, 'startTime': 830, 'endTime': 915},
            {'indexNo': 2, 'startTime': 925, 'endTime': 1010},
            {'indexNo': 3, 'startTime': 1030, 'endTime': 1115},
            {'indexNo': 4, 'startTime': 1125, 'endTime': 1210},
            {'indexNo': 5, 'startTime': 1220, 'endTime': 1305},
            {'indexNo': 6, 'startTime': 1305, 'endTime': 1350},
            {'indexNo': 7, 'startTime': 1400, 'endTime': 1445},
            {'indexNo': 8, 'startTime': 1455, 'endTime': 1540},
          ],
        },
      };

      final table = JsonScheduleParser.extractSectionTimeTable(decoded);
      expect(table, isNotNull);
      expect(table!.sectionCount, 8);
      expect(table.slotFor(7)!.rangeText, '14:00-14:45');
    });
  });

  group('CourseReminderService 系统级课前提醒排程', () {
    test('按作息表、周次与提前分钟数准确生成未来提醒条目', () {
      final termStart = DateTime(2026, 9, 7); // 第 1 周周一
      final now = DateTime(2026, 9, 7, 8, 0); // 周一 08:00
      final courses = [
        const Course(
          id: 'c1',
          name: '高等数学',
          classroom: '教西D101',
          teacher: '张老师',
          weekday: 1,
          startSection: 1, // 08:30-10:10
          sectionCount: 2,
          startWeek: 1,
          endWeek: 16,
        ),
        const Course(
          id: 'c2',
          name: '实验课',
          classroom: '启真楼202',
          weekday: 1,
          startSection: 7, // 14:00-15:40
          sectionCount: 2,
          startWeek: 1,
          endWeek: 16,
          weekPattern: WeekPattern.even, // 第1周不上，第2周上
        ),
      ];

      final entries = CourseReminderService.buildUpcomingReminderEntries(
        courses: courses,
        termStartDate: termStart,
        timeTable: SectionTimeTable.nwpuChangan,
        settings: const CourseReminderSettings(
          enabled: true,
          leadMinutes: 15,
        ),
        now: now,
        horizonDays: 10,
      );

      // 第1周周一只有高等数学，第2周周一有高等数学+双周实验课 -> 共 3 条
      expect(entries, hasLength(3));
      expect(entries.first.course.name, '高等数学');
      expect(entries.first.triggerAt, DateTime(2026, 9, 7, 8, 15));
      expect(entries.first.body, contains('08:30-10:10'));
      expect(entries.last.course.name, '实验课');
      expect(entries.last.triggerAt, DateTime(2026, 9, 14, 13, 45));
    });
  });
}

import 'dart:convert';

import 'package:aoxiang_schedule/data/datasources/aoxiang_jiaowu_adapter.dart';
import 'package:aoxiang_schedule/domain/entities/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AoxiangJiaowuAdapter', () {
    test('支持西工大树维 EAMS5 studentTableVm.activities 结构与开学日期提取', () {
      final adapter = AoxiangJiaowuAdapter();
      final payload = jsonEncode({
        'kind': 'nwpu_api',
        'url': '/student/for-std/course-table/semester/241/print-data/10001',
        'payload': jsonEncode({
          'semester': {
            'startDate': '2026-09-07',
          },
          'studentTableVm': {
            'activities': [
              {
                'courseName': '计算机组成原理',
                'teachers': [
                  {'nameZh': '张明'},
                ],
                'room': {'nameZh': '教西D103'},
                'campus': {'nameZh': '长安校区'},
                'weekday': 1,
                'startUnit': 1,
                'endUnit': 2,
                'weekIndexes': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                'lessonCode': 'CS2041.01',
                'credits': 3.5,
              },
              {
                'courseName': '航空航天概论',
                'teachers': ['李华'],
                'room': '教东A201',
                'weekday': 3,
                'startUnit': 5,
                'endUnit': 6,
                'weekIndexes': [1, 3, 5, 7, 9, 11],
              },
              {
                'courseName': '创新实践课',
                'teachers': ['王芳'],
                'room': '启真楼302',
                'weekday': 5,
                'startUnit': 9,
                'endUnit': 10,
                'weekIndexes': [2, 5, 9, 13],
              },
            ],
          },
        }),
      });

      final result = adapter.parseExtractedPayload(payload);
      expect(result.sourceLabel, '西工大教务 API');
      expect(result.semesterStartDate, DateTime(2026, 9, 7));
      expect(result.courses, hasLength(3));

      final first = result.courses[0];
      expect(first.name, '计算机组成原理');
      expect(first.teacher, '张明');
      expect(first.classroom, '教西D103');
      expect(first.campus, '长安校区');
      expect(first.weekday, 1);
      expect(first.startSection, 1);
      expect(first.sectionCount, 2);
      expect(first.startWeek, 1);
      expect(first.endWeek, 12);
      expect(first.weekPattern, WeekPattern.all);

      final second = result.courses[1];
      expect(second.weekPattern, WeekPattern.odd);
      expect(second.startWeek, 1);
      expect(second.endWeek, 11);

      final third = result.courses[2];
      expect(third.weekPattern, WeekPattern.custom);
      expect(third.customWeeks, [2, 5, 9, 13]);
    });

    test('支持正方教务 kbList 结构解析', () {
      final adapter = AoxiangJiaowuAdapter();
      final courses = adapter.parseJiaowuResponse({
        'kbList': [
          {
            'kcmc': '机器学习',
            'xm': '刘洋',
            'cdmc': '启翔楼208',
            'xqmc': '长安校区',
            'xqj': '4',
            'jcs': '3-4',
            'zcd': '1-16周',
          },
        ],
      });

      expect(courses, hasLength(1));
      expect(courses.first.name, '机器学习');
      expect(courses.first.weekday, 4);
      expect(courses.first.startSection, 3);
      expect(courses.first.sectionCount, 2);
      expect(courses.first.startWeek, 1);
      expect(courses.first.endWeek, 16);
    });

    test('支持 HTML 表格 colspan/rowspan 与单格多课程拆分', () {
      final adapter = AoxiangJiaowuAdapter();
      const html = '''
<table>
  <tr>
    <th colspan="2">节次</th>
    <th>星期一</th>
    <th>星期二</th>
    <th>星期三</th>
    <th>星期四</th>
    <th>星期五</th>
  </tr>
  <tr>
    <td rowspan="2">上午</td>
    <td>1-2节</td>
    <td>线性代数<br/>1-8周<br/>教西D101<br/>陈老师<br/><br/>概率论<br/>9-16周<br/>教西D102<br/>赵老师</td>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>3-4节</td>
    <td></td>
    <td>大学英语<br/>1-16周<br/>教东B204<br/>周老师</td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
</table>
''';

      final courses = adapter.parseHtmlSchedule(html);
      expect(courses, hasLength(3));
      expect(courses.map((c) => c.name), containsAll(['线性代数', '概率论', '大学英语']));
    });
  });
}

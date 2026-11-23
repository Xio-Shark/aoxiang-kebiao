import 'dart:convert';

import 'package:aoxiang_schedule/data/datasources/course_file_import_data_source.dart';
import 'package:aoxiang_schedule/data/datasources/parsers/pdf_schedule_parser.dart';
import 'package:aoxiang_schedule/domain/entities/course.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalCourseFileImportDataSource', () {
    test('支持 JSON 字节流导入', () async {
      final source = LocalCourseFileImportDataSource();
      final bytes = utf8.encode(
        jsonEncode([
          {
            'id': 'c1',
            'name': '高等数学',
            'weekday': 1,
            'startSection': 1,
            'sectionCount': 2,
            'startWeek': 1,
            'endWeek': 16,
          },
        ]),
      );

      final result = await source.parseCourses(
        fileName: 'courses.json',
        bytes: bytes,
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          expect(courses.first.name, '高等数学');
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 DOCX 表格导入', () async {
      final source = LocalCourseFileImportDataSource();
      const xml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>课程名称</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>节次</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>周次</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>教室</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>教师</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>大学物理</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>周三</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>3-4节</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>1-16周</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>教A101</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>张老师</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
''';
      final xmlBytes = utf8.encode(xml);
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final bytes = ZipEncoder().encode(archive)!;

      final result = await source.parseCourses(
        fileName: 'courses.docx',
        bytes: bytes,
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          final course = courses.first;
          expect(course.name, '大学物理');
          expect(course.weekday, 3);
          expect(course.startSection, 3);
          expect(course.sectionCount, 2);
          expect(course.startWeek, 1);
          expect(course.endWeek, 16);
          expect(course.weekPattern, WeekPattern.all);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 DOCX 矩阵课表导入', () async {
      final source = LocalCourseFileImportDataSource();
      const xml = '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期一</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期二</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期三</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期四</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期五</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期六</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>星期日</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>上午</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>3</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>物联网技术学科前沿I 01(9周) (3-4节) 教西C3-104 王柱(10周) (3-4节) 教西C3-104 刘佳琪</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
''';
      final xmlBytes = utf8.encode(xml);
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final bytes = ZipEncoder().encode(archive)!;

      final result = await source.parseCourses(
        fileName: 'matrix.docx',
        bytes: bytes,
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(2));
          expect(courses.first.weekday, 2);
          expect(courses.first.startSection, 3);
          expect(courses.first.sectionCount, 2);
          expect(courses.first.startWeek, 9);
          expect(courses[1].startWeek, 10);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 CSV 列表式与 WakeUp 风格导入', () async {
      final source = LocalCourseFileImportDataSource();
      const csv = '''
课程名称,星期,开始节次,结束节次,老师,地点,周数
数据结构,星期二,1,2,李老师,教西D201,1-16周
操作系统,周四,5,6,王老师,教东B102,1-15单周
''';
      final result = await source.parseCourses(
        fileName: 'schedule.csv',
        bytes: utf8.encode(csv),
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(2));
          expect(courses[0].name, '数据结构');
          expect(courses[0].weekday, 2);
          expect(courses[0].startSection, 1);
          expect(courses[0].sectionCount, 2);
          expect(courses[1].name, '操作系统');
          expect(courses[1].weekday, 4);
          expect(courses[1].weekPattern, WeekPattern.odd);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 CSV 二维矩阵课表导入', () async {
      final source = LocalCourseFileImportDataSource();
      const csv = '''
节次,星期一,星期二,星期三,星期四,星期五,星期六,星期日
1-2节,"编译原理
1-16周
教西A201
陈老师","","","","","",""
''';
      final result = await source.parseCourses(
        fileName: 'matrix.csv',
        bytes: utf8.encode(csv),
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          expect(courses.first.name, '编译原理');
          expect(courses.first.weekday, 1);
          expect(courses.first.startSection, 1);
          expect(courses.first.sectionCount, 2);
          expect(courses.first.classroom, '教西A201');
          expect(courses.first.teacher, '陈老师');
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 XLSX 二维矩阵且按单元格列坐标精准对齐', () async {
      final source = LocalCourseFileImportDataSource();
      const sst = '''
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>节次</t></si>
  <si><t>星期一</t></si>
  <si><t>星期二</t></si>
  <si><t>星期三</t></si>
  <si><t>星期四</t></si>
  <si><t>星期五</t></si>
  <si><t>3-4节</t></si>
  <si><t>计算机网络
1-12周
教西D105
赵老师</t></si>
</sst>
''';
      const sheet = '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
      <c r="E1" t="s"><v>4</v></c>
      <c r="F1" t="s"><v>5</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>6</v></c>
      <c r="E2" t="s"><v>7</v></c>
    </row>
  </sheetData>
</worksheet>
''';
      final sstBytes = utf8.encode(sst);
      final sheetBytes = utf8.encode(sheet);
      final archive = Archive()
        ..addFile(ArchiveFile('xl/sharedStrings.xml', sstBytes.length, sstBytes))
        ..addFile(
          ArchiveFile(
            'xl/worksheets/sheet1.xml',
            sheetBytes.length,
            sheetBytes,
          ),
        );
      final bytes = ZipEncoder().encode(archive)!;

      final result = await source.parseCourses(
        fileName: 'timetable.xlsx',
        bytes: bytes,
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          expect(courses.first.name, '计算机网络');
          // E 列对应星期四
          expect(courses.first.weekday, 4);
          expect(courses.first.startSection, 3);
          expect(courses.first.sectionCount, 2);
          expect(courses.first.endWeek, 12);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持伪 .doc（HTML 表格内容嗅探）', () async {
      final source = LocalCourseFileImportDataSource();
      const fakeDocHtml = '''
<html><body>
<table>
  <tr><th>节次</th><th>星期一</th><th>星期二</th><th>星期三</th><th>星期四</th><th>星期五</th></tr>
  <tr><td>5-6节</td><td></td><td>软件工程<br/>1-16周<br/>教西C101<br/>刘老师</td><td></td><td></td><td></td></tr>
</table>
</body></html>
''';
      final result = await source.parseCourses(
        fileName: 'exported.doc',
        bytes: utf8.encode(fakeDocHtml),
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          expect(courses.first.name, '软件工程');
          expect(courses.first.weekday, 2);
          expect(courses.first.startSection, 5);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 ICS 时间段映射节次与 RRULE 单双周解析', () async {
      final source = LocalCourseFileImportDataSource();
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:人工智能导论
LOCATION:长安校区教西D301
DESCRIPTION:任课教师: 孙老师
DTSTART:20260902T140000
DTEND:20260902T154000
RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=8
END:VEVENT
END:VCALENDAR
''';
      final result = await source.parseCourses(
        fileName: 'calendar.ics',
        bytes: utf8.encode(ics),
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          final c = courses.first;
          expect(c.name, '人工智能导论');
          expect(c.weekday, 3); // 2026-09-02 为周三
          expect(c.startSection, 7); // 西工大长安校区 14:00 -> 第7节
          expect(c.sectionCount, 2); // 14:00-15:40 -> 7-8节
          expect(c.weekPattern, WeekPattern.odd);
          expect(c.teacher, '孙老师');
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });

    test('支持 PDF 坐标聚类二维课表解析', () {
      const positioned = [
        PdfPositionedLine(pageIndex: 0, text: '星期一', left: 100, top: 40, width: 60, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '星期二', left: 180, top: 40, width: 60, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '星期三', left: 260, top: 40, width: 60, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '星期四', left: 340, top: 40, width: 60, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '星期五', left: 420, top: 40, width: 60, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '1-2节', left: 20, top: 90, width: 50, height: 14),
        PdfPositionedLine(pageIndex: 0, text: '离散数学', left: 185, top: 82, width: 55, height: 12),
        PdfPositionedLine(pageIndex: 0, text: '1-16周', left: 185, top: 96, width: 55, height: 12),
        PdfPositionedLine(pageIndex: 0, text: '教西D108', left: 185, top: 110, width: 55, height: 12),
      ];

      final courses = PdfScheduleParser.parsePositionedLines(positioned);
      expect(courses, hasLength(1));
      expect(courses.first.name, '离散数学');
      expect(courses.first.weekday, 2);
      expect(courses.first.startSection, 1);
      expect(courses.first.classroom, '教西D108');
    });

    test('支持剪贴板/粘贴自由文本智能识别', () async {
      final source = LocalCourseFileImportDataSource();
      final result = await source.parseRawText(
        '概率论与数理统计, 周五, 3-4节, 2-16双周, 教西B203, 周老师',
      );

      result.when(
        success: (courses) {
          expect(courses, hasLength(1));
          expect(courses.first.name, '概率论与数理统计');
          expect(courses.first.weekday, 5);
          expect(courses.first.startSection, 3);
          expect(courses.first.weekPattern, WeekPattern.even);
        },
        failure: (failure) => fail('不应失败: ${failure.message}'),
      );
    });
  });
}

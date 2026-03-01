import 'dart:convert';
import 'dart:io';

import 'package:aoxiang_schedule/data/datasources/course_file_import_data_source.dart';
import 'package:aoxiang_schedule/domain/entities/course.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalCourseFileImportDataSource', () {
    test('支持 JSON 字节流导入', () async {
      final source = LocalCourseFileImportDataSource();
      final bytes = utf8.encode(jsonEncode([
        {
          'id': 'c1',
          'name': '高等数学',
          'weekday': 1,
          'startSection': 1,
          'sectionCount': 2,
          'startWeek': 1,
          'endWeek': 16,
        }
      ]));

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
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', xml.length, utf8.encode(xml)));
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
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', xml.length, utf8.encode(xml)));
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

    test('可解析真实课表 DOCX（我的课表）', () async {
      final source = LocalCourseFileImportDataSource();
      final file = File('test/fixtures/my_schedule.docx');
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();

      final result = await source.parseCourses(
        fileName: 'my_schedule.docx',
        bytes: bytes,
      );

      result.when(
        success: (courses) {
          final names = courses.map((e) => e.name).toSet();
          expect(courses.length, greaterThanOrEqualTo(15));
          expect(names.any((n) => n.contains('计算机组成与系统结构')), isTrue);
          expect(names.any((n) => n.contains('离散数学')), isTrue);
          expect(names.any((n) => n.contains('数字图像处理')), isTrue);
          expect(names.any((n) => n.contains('物联网技术学科前沿')), isTrue);
          expect(names.any((n) => n.contains('数据结构实验')), isTrue);
        },
        failure: (failure) => fail('真实 DOCX 不应失败: ${failure.message}'),
      );
    });
  });
}

/// 文件导入数据源

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/course.dart';
import '../models/course_model.dart';

abstract class CourseFileImportDataSource {
  Future<Result<List<Course>>> parseCourses({
    String? filePath,
    String? fileName,
    List<int>? bytes,
  });
}

class LocalCourseFileImportDataSource implements CourseFileImportDataSource {
  @override
  Future<Result<List<Course>>> parseCourses({
    String? filePath,
    String? fileName,
    List<int>? bytes,
  }) async {
    try {
      final resolvedName = _resolveFileName(filePath, fileName);
      final resolvedBytes =
          await _resolveFileBytes(filePath: filePath, bytes: bytes);
      final ext = p.extension(resolvedName).toLowerCase();

      final courses = switch (ext) {
        '.json' => _parseJSON(resolvedBytes),
        '.docx' => _parseDOCX(resolvedBytes),
        _ => throw const FormatException('不支持的文件类型，仅支持 JSON 和 DOCX'),
      };

      if (courses.isEmpty) {
        return Result.failure(
          Failure.validation(message: '导入文件中未解析到课程数据'),
        );
      }

      final baseId = DateTime.now().millisecondsSinceEpoch;
      final normalized = <Course>[];
      for (var i = 0; i < courses.length; i++) {
        final model = CourseModel.fromEntity(courses[i]);
        final id = model.id.trim().isEmpty ? 'import-$baseId-$i' : model.id;
        normalized.add(model.toEntity().copyWith(id: id.trim()));
      }
      return Result.success(normalized);
    } on FormatException catch (e) {
      return Result.failure(
        Failure.parse(message: e.message, cause: e),
      );
    } catch (e) {
      return Result.failure(
        Failure.parse(message: '解析导入文件失败: $e', cause: e),
      );
    }
  }

  List<Course> _parseJSON(List<int> bytes) {
    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);
    final maps = _extractCourseMaps(decoded);
    return maps.map((item) => CourseModel.fromJson(item).toEntity()).toList();
  }

  List<Course> _parseDOCX(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw const FormatException('DOCX 内容缺少 word/document.xml');
    }

    final xmlBytes = _toBytes(docFile.content);
    final document = XmlDocument.parse(utf8.decode(xmlBytes));
    final matrixCourses = _parseMatrixSchedule(document);
    if (matrixCourses.isNotEmpty) {
      return matrixCourses;
    }

    final tableCourses = _parseDocxTables(document);
    if (tableCourses.isNotEmpty) {
      return tableCourses;
    }

    final textCourses = _parseDocxText(document);
    if (textCourses.isNotEmpty) {
      return textCourses;
    }

    throw const FormatException('DOCX 中未识别到可导入的课程表结构');
  }

  List<Course> _parseMatrixSchedule(XmlDocument document) {
    final tables = _findElements(document, 'tbl').toList();
    if (tables.isEmpty) {
      return const [];
    }

    final rows = _findElements(tables.first, 'tr')
        .map((row) => _findElements(row, 'tc')
            .map((cell) => _cellText(cell).replaceAll(RegExp(r'\s+'), ' ').trim())
            .toList())
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();
    if (rows.length < 2) {
      return const [];
    }

    final courses = <Course>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.length < 3) {
        continue;
      }

      final section = int.tryParse(RegExp(r'\d+').stringMatch(row[1]) ?? '');
      if (section == null || section <= 0) {
        continue;
      }

      final dayStartIndex = row.length - 7;
      if (dayStartIndex < 2) {
        continue;
      }

      for (var d = 0; d < 7; d++) {
        final col = dayStartIndex + d;
        if (col >= row.length) {
          continue;
        }
        final cellText = row[col];
        if (cellText.isEmpty) {
          continue;
        }
        final weekday = d + 1;
        final parsed = _parseMatrixCell(
          text: cellText,
          weekday: weekday,
          fallbackSection: section,
          rowIndex: rowIndex,
          colIndex: col,
        );
        courses.addAll(parsed);
      }
    }

    final deduped = <String, Course>{};
    for (final course in courses) {
      final key =
          '${course.name}|${course.weekday}|${course.startSection}|${course.sectionCount}|${course.startWeek}|${course.endWeek}|${course.weekPattern.name}|${course.teacher}|${course.classroom}|${course.customWeeks.join(",")}';
      deduped[key] = course;
    }
    return deduped.values.toList();
  }

  List<Course> _parseMatrixCell({
    required String text,
    required int weekday,
    required int fallbackSection,
    required int rowIndex,
    required int colIndex,
  }) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final matches = RegExp(r'\(([^()]*周[^()]*)\)\s*\((\d+(?:[-~]\d+)?节)\)')
        .allMatches(normalized)
        .toList();
    if (matches.isEmpty) {
      return const [];
    }

    final firstWeekStart = matches.first.start;
    var courseName = normalized.substring(0, firstWeekStart).trim();
    courseName = courseName.replaceAll(RegExp(r'\s{2,}'), ' ');
    if (courseName.isEmpty) {
      return const [];
    }

    final courses = <Course>[];
    for (var i = 0; i < matches.length; i++) {
      final current = matches[i];
      final nextStart = i + 1 < matches.length ? matches[i + 1].start : normalized.length;
      final weekText = current.group(1) ?? '';
      final sectionText = current.group(2) ?? '';
      final section = _parseSection(sectionText) ??
          _SectionRange(start: fallbackSection, end: fallbackSection);
      final weekSpec = _parseWeekSpec(weekText);
      if (weekSpec == null) {
        continue;
      }

      final tail = normalized.substring(current.end, nextStart).trim();
      final info = _extractClassroomAndTeacher(tail);
      courses.add(
        Course(
          id: 'docx-m-$rowIndex-$colIndex-$i',
          name: courseName,
          teacher: info.teacher,
          classroom: info.classroom,
          weekday: weekday,
          startSection: section.start,
          sectionCount: section.end - section.start + 1,
          startWeek: weekSpec.start,
          endWeek: weekSpec.end,
          weekPattern: weekSpec.pattern,
          customWeeks: weekSpec.customWeeks,
        ),
      );
    }

    return courses;
  }

  _ClassroomTeacher _extractClassroomAndTeacher(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const _ClassroomTeacher(classroom: '', teacher: '');
    }

    final allTeacherMatches = RegExp(r'[\u4e00-\u9fa5A-Za-z·]{2,10}(?=\d|全校|本科|$)')
        .allMatches(normalized)
        .toList();
    if (allTeacherMatches.isEmpty) {
      return _ClassroomTeacher(classroom: normalized, teacher: '');
    }

    final teacherMatch = allTeacherMatches.last;
    final teacher = teacherMatch.group(0)?.trim() ?? '';
    final classroom = normalized.substring(0, teacherMatch.start).trim();
    return _ClassroomTeacher(classroom: classroom, teacher: teacher);
  }

  List<int> _toBytes(dynamic content) {
    if (content is List<int>) {
      return content;
    }
    if (content is String) {
      return utf8.encode(content);
    }
    throw const FormatException('DOCX 内容读取失败');
  }

  List<Course> _parseDocxTables(XmlDocument document) {
    final rows = _findElements(document, 'tr')
        .map((row) => _findElements(row, 'tc')
            .map((cell) => _cellText(cell).trim())
            .toList())
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    if (rows.length < 2) {
      return const [];
    }

    final header = _detectHeader(rows);
    if (header == null) {
      return const [];
    }

    final courses = <Course>[];
    for (var i = header.rowIndex + 1; i < rows.length; i++) {
      final parsed = _rowToCourse(rows[i], header.map, i);
      if (parsed != null) {
        courses.add(parsed);
      }
    }
    return courses;
  }

  List<Course> _parseDocxText(XmlDocument document) {
    final lines = _findElements(document, 'p')
        .map((pNode) => _findElements(pNode, 't').map((e) => e.innerText).join())
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final courses = <Course>[];
    for (var i = 0; i < lines.length; i++) {
      final course = _lineToCourse(lines[i], i);
      if (course != null) {
        courses.add(course);
      }
    }
    return courses;
  }

  Course? _lineToCourse(String line, int index) {
    final parts = line.split(RegExp(r'[,，\t]')).map((e) => e.trim()).toList();
    if (parts.length < 4) {
      return null;
    }

    final weekday = _parseWeekday(parts[1]);
    final section = _parseSection(parts[2]);
    final week = _parseWeekSpec(parts[3]);
    if (weekday == null || section == null || week == null || parts[0].isEmpty) {
      return null;
    }

    return Course(
      id: 'docx-line-$index',
      name: parts[0],
      classroom: parts.length > 4 ? parts[4] : '',
      teacher: parts.length > 5 ? parts[5] : '',
      weekday: weekday,
      startSection: section.start,
      sectionCount: section.end - section.start + 1,
      startWeek: week.start,
      endWeek: week.end,
      weekPattern: week.pattern,
      customWeeks: week.customWeeks,
    );
  }

  _HeaderDetection? _detectHeader(List<List<String>> rows) {
    final aliasMap = _headerAliases;
    var bestScore = 0;
    _HeaderDetection? best;

    for (var i = 0; i < rows.length; i++) {
      final map = <String, int>{};
      var score = 0;
      for (var c = 0; c < rows[i].length; c++) {
        final cell = rows[i][c].replaceAll(' ', '');
        for (final entry in aliasMap.entries) {
          if (map.containsKey(entry.key)) {
            continue;
          }
          if (entry.value.any((alias) => cell.contains(alias))) {
            map[entry.key] = c;
            score++;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = _HeaderDetection(rowIndex: i, map: map);
      }
    }

    if (bestScore < 4 || best == null) {
      return null;
    }
    if (!best.map.containsKey('name') ||
        !best.map.containsKey('weekday') ||
        !best.map.containsKey('section')) {
      return null;
    }
    return best;
  }

  Course? _rowToCourse(List<String> row, Map<String, int> map, int index) {
    final name = _cellValue(row, map['name']);
    if (name.isEmpty) {
      return null;
    }

    final weekday = _parseWeekday(_cellValue(row, map['weekday']));
    final section = _parseSection(_cellValue(row, map['section']));
    final week = _parseWeekSpec(_cellValue(row, map['week']));
    if (weekday == null || section == null || week == null) {
      return null;
    }

    return Course(
      id: 'docx-row-$index',
      name: name,
      teacher: _cellValue(row, map['teacher']),
      classroom: _cellValue(row, map['classroom']),
      campus: _cellValue(row, map['campus']),
      weekday: weekday,
      startSection: section.start,
      sectionCount: section.end - section.start + 1,
      startWeek: week.start,
      endWeek: week.end,
      weekPattern: week.pattern,
      customWeeks: week.customWeeks,
    );
  }

  String _cellValue(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  String _cellText(XmlElement cell) {
    return _findElements(cell, 't').map((e) => e.innerText).join();
  }

  Iterable<XmlElement> _findElements(XmlNode root, String localName) {
    return root.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == localName);
  }

  int? _parseWeekday(String text) {
    final normalized = text.replaceAll('星期', '周').replaceAll('周天', '周日');
    const map = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
      '周七': 7,
    };
    for (final entry in map.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    final num = int.tryParse(RegExp(r'\d').stringMatch(normalized) ?? '');
    if (num != null && num >= 1 && num <= 7) {
      return num;
    }
    return null;
  }

  _SectionRange? _parseSection(String text) {
    final numbers = RegExp(r'\d+').allMatches(text).map((m) {
      return int.parse(m.group(0)!);
    }).toList();
    if (numbers.isEmpty) {
      return null;
    }

    final start = numbers.first;
    final end = numbers.length > 1 ? numbers[1] : start;
    final min = start < end ? start : end;
    final max = start < end ? end : start;
    if (min < 1) {
      return null;
    }
    return _SectionRange(start: min, end: max);
  }

  _WeekSpec? _parseWeekSpec(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return const _WeekSpec(
        start: 1,
        end: 25,
        pattern: WeekPattern.all,
        customWeeks: [],
      );
    }

    final cleaned = raw.replaceAll('周', '');
    final tokens = cleaned
        .split(RegExp(r'[，,、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasMultiToken = tokens.length > 1;

    final expandedWeeks = <int>{};
    for (final token in tokens) {
      final range = RegExp(r'^(\d+)\s*[-~]\s*(\d+)$').firstMatch(token);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        final start = a < b ? a : b;
        final end = a < b ? b : a;
        for (var i = start; i <= end; i++) {
          if (i > 0) {
            expandedWeeks.add(i);
          }
        }
        continue;
      }
      final single = int.tryParse(RegExp(r'\d+').stringMatch(token) ?? '');
      if (single != null && single > 0) {
        expandedWeeks.add(single);
      }
    }

    if (expandedWeeks.isEmpty) {
      return null;
    }

    final weeks = expandedWeeks.toList()..sort();
    final min = weeks.first;
    final max = weeks.last;

    var pattern = WeekPattern.all;
    if (raw.contains('单')) {
      pattern = WeekPattern.odd;
    } else if (raw.contains('双')) {
      pattern = WeekPattern.even;
    } else if (hasMultiToken && (cleaned.contains(',') || cleaned.contains('，') || cleaned.contains('、') || tokens.length > 1)) {
      pattern = WeekPattern.custom;
    } else if (tokens.length > 1) {
      pattern = WeekPattern.custom;
    }

    final customWeeks = pattern == WeekPattern.custom ? weeks : const <int>[];
    return _WeekSpec(
      start: min,
      end: max,
      pattern: pattern,
      customWeeks: customWeeks,
    );
  }

  String _resolveFileName(String? filePath, String? fileName) {
    final normalizedName = (fileName ?? '').trim();
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedPath = (filePath ?? '').trim();
    if (normalizedPath.isNotEmpty) {
      return p.basename(normalizedPath);
    }

    throw const FormatException('缺少导入文件名');
  }

  Future<List<int>> _resolveFileBytes({
    String? filePath,
    List<int>? bytes,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    final normalizedPath = (filePath ?? '').trim();
    if (normalizedPath.isEmpty) {
      throw const FormatException('未获取到导入文件内容');
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw FormatException('导入文件不存在: $normalizedPath');
    }

    return file.readAsBytes();
  }

  List<Map<String, dynamic>> _extractCourseMaps(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      final payload = Map<String, dynamic>.from(decoded);
      final coursesField = payload['courses'];
      if (coursesField is List) {
        return coursesField
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [payload];
    }

    return const [];
  }
}

const Map<String, List<String>> _headerAliases = {
  'name': ['课程', '课程名', '课程名称'],
  'teacher': ['教师', '老师', '任课教师'],
  'classroom': ['教室', '地点', '上课地点'],
  'weekday': ['星期', '周几', '周次日'],
  'section': ['节次', '节', '时间', '上课时间'],
  'week': ['周次', '起止周', '上课周', '教学周'],
  'campus': ['校区'],
};

class _HeaderDetection {
  final int rowIndex;
  final Map<String, int> map;

  const _HeaderDetection({
    required this.rowIndex,
    required this.map,
  });
}

class _SectionRange {
  final int start;
  final int end;

  const _SectionRange({
    required this.start,
    required this.end,
  });
}

class _WeekSpec {
  final int start;
  final int end;
  final WeekPattern pattern;
  final List<int> customWeeks;

  const _WeekSpec({
    required this.start,
    required this.end,
    required this.pattern,
    required this.customWeeks,
  });
}

class _ClassroomTeacher {
  final String classroom;
  final String teacher;

  const _ClassroomTeacher({
    required this.classroom,
    required this.teacher,
  });
}

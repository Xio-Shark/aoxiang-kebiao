/// 西工大翱翔教务同步适配器
/// 负责对接西工大翱翔教务接口及数据清洗转换

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../core/constants/course_color_palette.dart';
import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/course.dart';

class AoxiangJiaowuAdapter {
  final Dio _dio;

  AoxiangJiaowuAdapter({Dio? dio}) : _dio = dio ?? Dio();

  /// 从网页 HTML 内容或包含 JSON 的响应中解析课程
  List<Course> parseRawContent(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return [];

    // 1. 尝试作为 JSON 数据解析
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = json.decode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return parseJiaowuResponse(decoded);
        } else if (decoded is List) {
          return parseJiaowuResponse({'kbList': decoded});
        }
      } catch (_) {}
    }

    // 2. 如果包含嵌入的 JSON（常见于教务系统的内嵌 script 标签中）
    final jsonMatch = RegExp(r'kbList\s*[:=]\s*(\[.*?\]);?', dotAll: true).firstMatch(trimmed);
    if (jsonMatch != null) {
      try {
        final decoded = json.decode(jsonMatch.group(1)!);
        if (decoded is List) {
          return parseJiaowuResponse({'kbList': decoded});
        }
      } catch (_) {}
    }

    // 3. 尝试解析 HTML 课表
    return parseHtmlSchedule(trimmed);
  }

  /// 从西工大翱翔教务接口 JSON 响应结构中转换课程列表
  /// 支持翱翔教务导出的特定结构与通用教务课表接口
  List<Course> parseJiaowuResponse(Map<String, dynamic> jsonResponse) {
    final list = <Course>[];
    final kbList = jsonResponse['kbList'] ?? jsonResponse['data'] ?? jsonResponse['courses'];
    if (kbList is! List) {
      return list;
    }

    var counter = 1;
    for (final item in kbList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final name = (map['kcmc'] ?? map['courseName'] ?? map['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final teacher = (map['xm'] ?? map['teacher'] ?? map['teacherName'] ?? '').toString().trim();
      final classroom = (map['cdmc'] ?? map['classroom'] ?? map['room'] ?? '').toString().trim();
      final campus = (map['xqmc'] ?? map['campus'] ?? '长安校区').toString().trim();

      final weekday = int.tryParse((map['skxq'] ?? map['dayOfWeek'] ?? map['weekday'] ?? '1').toString()) ?? 1;
      final startSection = int.tryParse((map['ksjc'] ?? map['startSection'] ?? '1').toString()) ?? 1;
      final endSection = int.tryParse((map['jsjc'] ?? map['endSection'] ?? '$startSection').toString()) ?? startSection;
      final sectionCount = (endSection - startSection + 1).clamp(1, 12);

      // 解析周次如 "1-16周" 或 "1-8周(单)"
      final zc = (map['zcs'] ?? map['weeks'] ?? '1-20周').toString();
      final weekSpec = _parseWeekString(zc);

      list.add(Course(
        id: 'nwpu-${counter++}',
        name: name,
        teacher: teacher,
        classroom: classroom,
        campus: campus,
        weekday: weekday.clamp(1, 7),
        startSection: startSection.clamp(1, 12),
        sectionCount: sectionCount,
        startWeek: weekSpec.start,
        endWeek: weekSpec.end,
        weekPattern: weekSpec.pattern,
        customWeeks: weekSpec.customWeeks,
        color: CourseColorPalette.getColorForName(name),
      ));
    }

    return list;
  }

  /// 从标准 HTML 课表格子中智能提取课程（多行多列二维矩阵解析）
  List<Course> parseHtmlSchedule(String html) {
    final list = <Course>[];
    try {
      final doc = html_parser.parse(html);
      final tables = doc.querySelectorAll('table');
      if (tables.isEmpty) return list;

      dom.Element? scheduleTable;
      for (final table in tables) {
        final rows = table.querySelectorAll('tr');
        if (rows.length >= 4) {
          scheduleTable = table;
          break;
        }
      }
      scheduleTable ??= tables.first;

      final rows = scheduleTable.querySelectorAll('tr');
      if (rows.length < 2) return list;

      // 提取表头星期映射
      final headerRow = rows.first;
      final headerCells = headerRow.querySelectorAll('th, td');
      final dayColMap = <int, int>{};

      for (var col = 0; col < headerCells.length; col++) {
        final txt = headerCells[col].text.trim();
        if (txt.contains('一')) {
          dayColMap[col] = 1;
        } else if (txt.contains('二')) {
          dayColMap[col] = 2;
        } else if (txt.contains('三')) {
          dayColMap[col] = 3;
        } else if (txt.contains('四')) {
          dayColMap[col] = 4;
        } else if (txt.contains('五')) {
          dayColMap[col] = 5;
        } else if (txt.contains('六')) {
          dayColMap[col] = 6;
        } else if (txt.contains('日') || txt.contains('天') || txt.contains('七')) {
          dayColMap[col] = 7;
        }
      }

      var counter = 1;
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final cells = row.querySelectorAll('td, th');
        if (cells.isEmpty) continue;

        // 获取当前行的默认节次估算
        final firstCellText = cells.first.text.trim();
        final secMatch = RegExp(r'\d+').firstMatch(firstCellText);
        final rowSection = secMatch != null ? int.tryParse(secMatch.group(0)!) ?? rowIndex : rowIndex;

        for (var colIndex = 0; colIndex < cells.length; colIndex++) {
          final weekday = dayColMap[colIndex] ?? (colIndex > 0 && colIndex <= 7 ? colIndex : null);
          if (weekday == null) continue;

          final cell = cells[colIndex];
          final text = cell.text.trim();
          if (text.isEmpty || text.length < 2) continue;

          final lines = cell.innerHtml
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          if (lines.isEmpty) continue;
          final name = lines.first;
          if (name.length < 2 || name.contains('星期') || name.contains('节次')) continue;

          var teacher = '';
          var classroom = '';
          var weeksStr = '1-18周';
          var customStartSection = rowSection;
          var customSectionCount = 2;

          for (var i = 1; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('周')) {
              weeksStr = line;
            } else if (line.contains('节')) {
              final secNums = RegExp(r'\d+').allMatches(line).map((m) => int.parse(m.group(0)!)).toList();
              if (secNums.isNotEmpty) {
                customStartSection = secNums.first;
                if (secNums.length > 1) {
                  customSectionCount = (secNums.last - secNums.first + 1).clamp(1, 4);
                }
              }
            } else if (line.contains('教') || line.contains('楼') || line.contains('室') || line.contains('区') || line.contains('馆')) {
              classroom = line;
            } else if (teacher.isEmpty && line.length <= 6) {
              teacher = line;
            }
          }

          final weekSpec = _parseWeekString(weeksStr);
          list.add(Course(
            id: 'nwpu-html-${counter++}',
            name: name,
            teacher: teacher,
            classroom: classroom,
            campus: '长安校区',
            weekday: weekday.clamp(1, 7),
            startSection: customStartSection.clamp(1, 12),
            sectionCount: customSectionCount.clamp(1, 4),
            startWeek: weekSpec.start,
            endWeek: weekSpec.end,
            weekPattern: weekSpec.pattern,
            customWeeks: weekSpec.customWeeks,
            color: CourseColorPalette.getColorForName(name),
          ));
        }
      }
    } catch (_) {}

    return list;
  }

  _ParsedWeek _parseWeekString(String text) {
    final raw = text.replaceAll('周', '').trim();
    var pattern = WeekPattern.all;
    if (text.contains('单')) {
      pattern = WeekPattern.odd;
    } else if (text.contains('双')) {
      pattern = WeekPattern.even;
    }

    final match = RegExp(r'(\d+)\s*[-~]\s*(\d+)').firstMatch(raw);
    if (match != null) {
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);
      final start = a < b ? a : b;
      final end = a < b ? b : a;
      return _ParsedWeek(start: start, end: end, pattern: pattern, customWeeks: []);
    }

    final digits = RegExp(r'\d+').allMatches(raw).map((m) => int.parse(m.group(0)!)).toList();
    if (digits.isNotEmpty) {
      digits.sort();
      return _ParsedWeek(
        start: digits.first,
        end: digits.last,
        pattern: digits.length > 2 ? WeekPattern.custom : pattern,
        customWeeks: digits.length > 2 ? digits : [],
      );
    }

    return const _ParsedWeek(start: 1, end: 20, pattern: WeekPattern.all, customWeeks: []);
  }
}

class _ParsedWeek {
  final int start;
  final int end;
  final WeekPattern pattern;
  final List<int> customWeeks;

  const _ParsedWeek({
    required this.start,
    required this.end,
    required this.pattern,
    required this.customWeeks,
  });
}

/// 西工大翱翔教务同步适配器
/// 负责对接西工大翱翔教务接口及数据清洗转换

import 'dart:convert';
import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/course.dart';

class AoxiangJiaowuAdapter {
  final Dio _dio;

  AoxiangJiaowuAdapter({Dio? dio}) : _dio = dio ?? Dio();

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
      ));
    }

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

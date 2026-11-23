import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/course_color_palette.dart';
import '../../../domain/entities/course.dart';
import '../../../domain/entities/section_time.dart';

/// 节次范围
class SectionRange {
  const SectionRange({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;

  int get count => (end - start + 1).clamp(1, AppConstants.sectionCount);
}

/// 周次解析结果
class WeekSpec {
  const WeekSpec({
    required this.start,
    required this.end,
    required this.pattern,
    required this.customWeeks,
  });

  final int start;
  final int end;
  final WeekPattern pattern;
  final List<int> customWeeks;
}

/// 列表表头映射
class TableHeaderMatch {
  const TableHeaderMatch({
    required this.rowIndex,
    required this.columnMap,
  });

  final int rowIndex;
  final Map<String, int> columnMap;
}

/// 教室与教师拆分结果
class ClassroomTeacherPair {
  const ClassroomTeacherPair({
    required this.classroom,
    required this.teacher,
  });

  final String classroom;
  final String teacher;
}

/// 多教务系统通用文本/表格解析工具集
class ScheduleTextUtils {
  const ScheduleTextUtils._();

  static SectionTimeTable activeTimeTable = SectionTimeTable.nwpuChangan;

  static const Map<String, List<String>> headerAliases = {
    'name': [
      '课程名称',
      '课程名',
      '课程',
      '科目',
      'course',
      'coursename',
      'title',
      'subject',
    ],
    'teacher': [
      '任课教师',
      '授课教师',
      '主讲教师',
      '教师',
      '老师',
      'teacher',
      'instructor',
    ],
    'classroom': [
      '上课地点',
      '上课教室',
      '教学场地',
      '教室',
      '地点',
      '场地',
      'classroom',
      'location',
      'room',
    ],
    'weekday': [
      '星期',
      '周几',
      '周次日',
      '上课星期',
      'weekday',
      'dayofweek',
      'day',
    ],
    'startSection': ['开始节次', '起始节次', '开始节', 'startsection', 'start'],
    'endSection': ['结束节次', '终止节次', '结束节', 'endsection', 'end'],
    'sectionCount': ['节数', '持续节数', '节次数', 'sectioncount', 'step'],
    'section': ['上课节次', '节次', '上课时间', '时间段', '节', 'section', 'period'],
    'week': ['上课周次', '教学周', '起止周', '上课周', '周次', '周数', 'weeks', 'week'],
    'campus': ['校区', 'campus'],
    'note': ['备注', '说明', '教学班', '学分', 'note', 'remark'],
  };

  /// 容错解码文本字节（处理 UTF-8 BOM、UTF-8、UTF-16LE/BE 与 Latin1 回退）
  static String decodeBytesFlexible(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    // UTF-16 LE BOM
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final codeUnits = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return String.fromCharCodes(codeUnits);
    }
    // UTF-16 BE BOM
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final codeUnits = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(codeUnits);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 解析星期（1-7）
  static int? parseWeekday(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll('星期', '周')
        .replaceAll('礼拜', '周')
        .replaceAll('周天', '周日');

    const cnMap = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
      '周七': 7,
    };
    for (final entry in cnMap.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    const enMap = {
      'monday': 1,
      'mon': 1,
      'tuesday': 2,
      'tue': 2,
      'tues': 2,
      'wednesday': 3,
      'wed': 3,
      'thursday': 4,
      'thu': 4,
      'thur': 4,
      'friday': 5,
      'fri': 5,
      'saturday': 6,
      'sat': 6,
      'sunday': 7,
      'sun': 7,
    };
    for (final entry in enMap.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(normalized)) {
        return entry.value;
      }
    }

    if (normalized.length <= 2) {
      const singleCn = {
        '一': 1,
        '二': 2,
        '三': 3,
        '四': 4,
        '五': 5,
        '六': 6,
        '日': 7,
        '天': 7,
        '七': 7,
      };
      if (singleCn.containsKey(normalized)) {
        return singleCn[normalized];
      }
    }

    final numMatch = RegExp(r'(?:^|\D)([1-7])(?:\D|$)').firstMatch(normalized);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(1)!);
    }
    return null;
  }

  /// 解析节次范围，兼容 "1-2节"、"第7,8节"、"14:00-15:40"、"11~13"、"5"
  static SectionRange? parseSection(
    String text, {
    SectionTimeTable? timeTable,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // 1. 优先识别显式带「节」字：避免行头同时有「第7节 14:00-14:45」时被时间段干扰
    final explicitSection = RegExp(
      r'第?\s*(\d{1,2})(?:\s*[-~至到,，、]\s*(\d{1,2}))*\s*节',
    ).firstMatch(trimmed);
    if (explicitSection != null) {
      final nums = RegExp(r'\d+')
          .allMatches(explicitSection.group(0)!)
          .map((m) => int.parse(m.group(0)!))
          .where((n) => n >= 1 && n <= AppConstants.sectionCount)
          .toList();
      if (nums.isNotEmpty) {
        nums.sort();
        return SectionRange(start: nums.first, end: nums.last);
      }
    }

    // 2. 时间段形式：08:30-10:10 或 14:00~15:40，按作息表精准反推第几节
    final clockMatch = RegExp(
      r'(\d{1,2})[:：](\d{2})\s*[-~至到]\s*(\d{1,2})[:：](\d{2})',
    ).firstMatch(trimmed);
    if (clockMatch != null) {
      final startMin =
          int.parse(clockMatch.group(1)!) * 60 + int.parse(clockMatch.group(2)!);
      final endMin =
          int.parse(clockMatch.group(3)!) * 60 + int.parse(clockMatch.group(4)!);
      return mapMinutesToSectionRange(
        startMin,
        endMin,
        timeTable: timeTable,
      );
    }

    // 3. 单个时间点（如行头仅写 "14:00"）：映射到最接近的单个节次
    final singleClock = RegExp(r'(?:^|\s)(\d{1,2})[:：](\d{2})(?:\s|$)').firstMatch(trimmed);
    if (singleClock != null) {
      final startMin =
          int.parse(singleClock.group(1)!) * 60 + int.parse(singleClock.group(2)!);
      return mapMinutesToSectionRange(
        startMin,
        startMin,
        timeTable: timeTable,
      );
    }

    // 4. 纯数字或范围：如 "7-8"、"11,12,13"、"5"
    final numbers = RegExp(r'\d+')
        .allMatches(trimmed)
        .map((m) => int.parse(m.group(0)!))
        .where((n) => n >= 1 && n <= AppConstants.sectionCount)
        .toList();
    if (numbers.isEmpty) {
      return null;
    }

    final start = numbers.first;
    final end = numbers.length > 1 ? numbers.last : start;
    final minVal = start < end ? start : end;
    final maxVal = start < end ? end : start;
    return SectionRange(start: minVal, end: maxVal);
  }

  /// 将一天中的开始/结束分钟数映射到节次范围（统一委托 SectionTimeTable）
  static SectionRange mapMinutesToSectionRange(
    int startMinutes,
    int endMinutes, {
    SectionTimeTable? timeTable,
  }) {
    final table = timeTable ?? activeTimeTable;
    final (startSec, endSec) = table.mapMinutesToSections(startMinutes, endMinutes);
    return SectionRange(start: startSec, end: endSec);
  }

  /// 从整数周次数组构建 WeekSpec（自动识别全周、单周、双周或自定义周）
  static WeekSpec? buildWeekSpecFromList(List<int> rawWeeks) {
    final cleaned = rawWeeks
        .where((w) => w >= AppConstants.minWeek && w <= AppConstants.maxWeek)
        .toSet()
        .toList()
      ..sort();
    if (cleaned.isEmpty) {
      return null;
    }

    final minW = cleaned.first;
    final maxW = cleaned.last;
    if (cleaned.length == 1) {
      return WeekSpec(
        start: minW,
        end: maxW,
        pattern: WeekPattern.all,
        customWeeks: const [],
      );
    }

    final isAll = cleaned.length == (maxW - minW + 1);
    if (isAll) {
      return WeekSpec(
        start: minW,
        end: maxW,
        pattern: WeekPattern.all,
        customWeeks: const [],
      );
    }

    final expectedOdd = [
      for (var w = minW; w <= maxW; w++)
        if (w.isOdd) w,
    ];
    if (_sameInts(cleaned, expectedOdd)) {
      return WeekSpec(
        start: minW,
        end: maxW,
        pattern: WeekPattern.odd,
        customWeeks: const [],
      );
    }

    final expectedEven = [
      for (var w = minW; w <= maxW; w++)
        if (w.isEven) w,
    ];
    if (_sameInts(cleaned, expectedEven)) {
      return WeekSpec(
        start: minW,
        end: maxW,
        pattern: WeekPattern.even,
        customWeeks: const [],
      );
    }

    return WeekSpec(
      start: minW,
      end: maxW,
      pattern: WeekPattern.custom,
      customWeeks: cleaned,
    );
  }

  /// 解析复杂周次文本（兼容 "1-16周"、"1-16(单)"、"1-8周,10-16周"、"1,3,5-9双" 等）
  static WeekSpec? parseWeekSpec(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return const WeekSpec(
        start: 1,
        end: 18,
        pattern: WeekPattern.all,
        customWeeks: [],
      );
    }

    final normalized = raw
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll('第', '')
        .replaceAll('至', '-')
        .replaceAll('到', '-')
        .replaceAll('~', '-');

    // 全局单双周标记（若整个串只有一段区间且含单/双）
    final tokens = normalized
        .split(RegExp(r'[，,、;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final expanded = <int>{};
    for (final token in tokens) {
      final tokenOdd = token.contains('单');
      final tokenEven = token.contains('双');

      final rangeMatch = RegExp(r'(\d{1,2})\s*-\s*(\d{1,2})').firstMatch(token);
      if (rangeMatch != null) {
        final a = int.parse(rangeMatch.group(1)!);
        final b = int.parse(rangeMatch.group(2)!);
        final start = a < b ? a : b;
        final end = a < b ? b : a;
        for (var w = start; w <= end; w++) {
          if (w < AppConstants.minWeek || w > AppConstants.maxWeek) {
            continue;
          }
          if (tokenOdd && !w.isOdd) continue;
          if (tokenEven && !w.isEven) continue;
          expanded.add(w);
        }
        continue;
      }

      for (final m in RegExp(r'\d{1,2}').allMatches(token)) {
        final w = int.parse(m.group(0)!);
        if (w >= AppConstants.minWeek && w <= AppConstants.maxWeek) {
          expanded.add(w);
        }
      }
    }

    if (expanded.isEmpty) {
      return null;
    }

    // 如果全局带单/双周标记但被空格隔开（如 "1-16周 单"）
    final sorted = expanded.toList()..sort();
    final hasGlobalOdd = raw.contains('单') && !raw.contains('双');
    final hasGlobalEven = raw.contains('双') && !raw.contains('单');
    if (hasGlobalOdd) {
      final filtered = sorted.where((w) => w.isOdd).toList();
      if (filtered.isNotEmpty) {
        return buildWeekSpecFromList(filtered);
      }
    } else if (hasGlobalEven) {
      final filtered = sorted.where((w) => w.isEven).toList();
      if (filtered.isNotEmpty) {
        return buildWeekSpecFromList(filtered);
      }
    }

    return buildWeekSpecFromList(sorted);
  }

  /// 检测列表式表格的表头行与列映射
  static TableHeaderMatch? detectListHeader(List<List<String>> rows) {
    var bestScore = 0;
    TableHeaderMatch? best;

    final scanLimit = rows.length < 15 ? rows.length : 15;
    for (var i = 0; i < scanLimit; i++) {
      final map = <String, int>{};
      var score = 0;
      for (var c = 0; c < rows[i].length; c++) {
        final cell = rows[i][c]
            .replaceAll(RegExp(r'[\s_\-*（）()]+'), '')
            .toLowerCase();
        if (cell.isEmpty) continue;

        for (final entry in headerAliases.entries) {
          if (map.containsKey(entry.key)) continue;
          if (entry.value.any((alias) => cell == alias || cell.contains(alias))) {
            map[entry.key] = c;
            score++;
            break;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = TableHeaderMatch(rowIndex: i, columnMap: map);
      }
    }

    if (best == null || bestScore < 3) {
      return null;
    }
    final hasName = best.columnMap.containsKey('name');
    final hasWeekday = best.columnMap.containsKey('weekday');
    final hasSection = best.columnMap.containsKey('section') ||
        best.columnMap.containsKey('startSection');
    if (!hasName || !hasWeekday || !hasSection) {
      return null;
    }
    return best;
  }

  /// 将列表式表格的一行转换为 Course
  static Course? listRowToCourse(
    List<String> row,
    Map<String, int> columnMap, {
    required String idPrefix,
    required int rowIndex,
  }) {
    String cell(String key) {
      final idx = columnMap[key];
      if (idx == null || idx < 0 || idx >= row.length) {
        return '';
      }
      return row[idx].trim();
    }

    final name = cell('name');
    if (name.isEmpty || name == '课程名称' || name == '课程名') {
      return null;
    }

    final weekday = parseWeekday(cell('weekday'));
    if (weekday == null) {
      return null;
    }

    SectionRange? section;
    final startSecStr = cell('startSection');
    final endSecStr = cell('endSection');
    final countStr = cell('sectionCount');
    if (startSecStr.isNotEmpty) {
      final start = int.tryParse(RegExp(r'\d+').stringMatch(startSecStr) ?? '');
      if (start != null && start >= 1 && start <= AppConstants.sectionCount) {
        final end = int.tryParse(RegExp(r'\d+').stringMatch(endSecStr) ?? '');
        final cnt = int.tryParse(RegExp(r'\d+').stringMatch(countStr) ?? '');
        final resolvedEnd = end ?? (cnt != null ? start + cnt - 1 : start + 1);
        section = SectionRange(
          start: start,
          end: resolvedEnd.clamp(start, AppConstants.sectionCount),
        );
      }
    }
    section ??= parseSection(cell('section'));
    if (section == null) {
      return null;
    }

    final weekText = cell('week');
    final weekSpec = parseWeekSpec(weekText) ??
        const WeekSpec(
          start: 1,
          end: 18,
          pattern: WeekPattern.all,
          customWeeks: [],
        );

    return Course(
      id: '$idPrefix-$rowIndex',
      name: name,
      teacher: cell('teacher'),
      classroom: cell('classroom'),
      campus: cell('campus'),
      weekday: weekday,
      startSection: section.start,
      sectionCount: section.count,
      startWeek: weekSpec.start,
      endWeek: weekSpec.end,
      weekPattern: weekSpec.pattern,
      customWeeks: weekSpec.customWeeks,
      color: CourseColorPalette.getColorForName(name),
      note: cell('note'),
    );
  }

  /// 检测二维矩阵表格（表头包含星期一~星期日）并解析为课程列表
  static List<Course> parseMatrixRows(
    List<List<String>> rows, {
    required String idPrefix,
  }) {
    if (rows.length < 2) {
      return const [];
    }

    // 寻找包含星期列头的行
    var headerRowIdx = -1;
    Map<int, int> dayColMap = const {};
    final scanLimit = rows.length < 8 ? rows.length : 8;

    for (var r = 0; r < scanLimit; r++) {
      final candidate = <int, int>{};
      for (var c = 0; c < rows[r].length; c++) {
        final text = rows[r][c].trim();
        if (text.isEmpty || text.length > 16) continue;
        // 避免把纯数字行误判成星期表头
        if (RegExp(r'^\d+$').hasMatch(text)) continue;
        final wd = parseWeekday(text);
        if (wd != null && !candidate.values.contains(wd)) {
          candidate[c] = wd;
        }
      }
      if (candidate.length >= 5) {
        headerRowIdx = r;
        dayColMap = candidate;
        break;
      }
    }

    if (headerRowIdx < 0 || dayColMap.isEmpty) {
      return const [];
    }

    final headerColCount = rows[headerRowIdx].length;
    final courses = <Course>[];
    var rollingSection = 1;

    for (var r = headerRowIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.trim().isEmpty)) {
        continue;
      }

      // 估算本行的起始节次（优先看前两列）
      SectionRange? rowSectionRange;
      final prefixCols = row.length < 3 ? row.length : 3;
      for (var c = 0; c < prefixCols; c++) {
        if (dayColMap.containsKey(c)) break;
        final text = row[c].trim();
        if (text.isEmpty) continue;
        if (text.contains('上午') ||
            text.contains('下午') ||
            text.contains('晚上') ||
            text.contains('节次') ||
            text.contains('时间')) {
          final parsed = parseSection(text);
          if (parsed != null) {
            rowSectionRange = parsed;
            break;
          }
          continue;
        }
        final parsed = parseSection(text);
        if (parsed != null) {
          rowSectionRange = parsed;
          break;
        }
      }

      final fallbackStart = rowSectionRange?.start ?? rollingSection;
      final fallbackCount = rowSectionRange?.count ?? 2;

      // 当合并单元格导致当前行比表头列数少或多了「上午/下午」列时，自动对齐偏移
      final colShift = row.length - headerColCount;

      for (final entry in dayColMap.entries) {
        final targetCol = entry.key + (colShift.abs() <= 2 ? colShift : 0);
        if (targetCol < 0 || targetCol >= row.length) {
          continue;
        }
        final cellText = row[targetCol].trim();
        if (cellText.isEmpty || cellText.length < 2) {
          continue;
        }

        final cellCourses = parseMatrixCell(
          cellText: cellText,
          weekday: entry.value,
          fallbackStartSection: fallbackStart,
          fallbackSectionCount: fallbackCount,
          idPrefix: '$idPrefix-r$r-c$targetCol',
        );
        courses.addAll(cellCourses);
      }

      rollingSection = (fallbackStart + (rowSectionRange == null ? 1 : rowSectionRange.count))
          .clamp(1, AppConstants.sectionCount);
    }

    return dedupeAndMergeCourses(courses);
  }

  /// 解析二维课表单个单元格内容（支持一个格子里多门课、多教务系统格式）
  static List<Course> parseMatrixCell({
    required String cellText,
    required int weekday,
    required int fallbackStartSection,
    int fallbackSectionCount = 2,
    required String idPrefix,
  }) {
    final cleaned = cellText.replaceAll('\r\n', '\n').trim();
    if (cleaned.isEmpty || cleaned.length < 2) {
      return const [];
    }

    // 1. 优先识别西工大 Word/打印课表紧凑型格式：
    // 例：「物联网技术学科前沿I 01(9周) (3-4节) 教西C3-104 王柱(10周) (3-4节) 教西C3-104 刘佳琪」
    final compactNormalized = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    final compactMatches = RegExp(
      r'[(（]([^()（）]*周[^()（）]*)[)）]\s*[(（](\d{1,2}(?:\s*[-~]\s*\d{1,2})?\s*节)[)）]',
    ).allMatches(compactNormalized).toList();

    if (compactMatches.isNotEmpty) {
      final result = <Course>[];
      var currentCourseName =
          compactNormalized.substring(0, compactMatches.first.start).trim();

      for (var i = 0; i < compactMatches.length; i++) {
        final current = compactMatches[i];
        final nextStart = i + 1 < compactMatches.length
            ? compactMatches[i + 1].start
            : compactNormalized.length;
        final weekSpec = parseWeekSpec(current.group(1) ?? '');
        final section = parseSection(current.group(2) ?? '') ??
            SectionRange(
              start: fallbackStartSection,
              end: (fallbackStartSection + fallbackSectionCount - 1)
                  .clamp(1, AppConstants.sectionCount),
            );
        if (weekSpec == null || currentCourseName.isEmpty) {
          continue;
        }

        final tail = compactNormalized.substring(current.end, nextStart).trim();
        final info = extractClassroomAndTeacher(tail);

        result.add(
          Course(
            id: '$idPrefix-$i',
            name: _cleanCourseName(currentCourseName),
            teacher: info.teacher,
            classroom: info.classroom,
            weekday: weekday,
            startSection: section.start,
            sectionCount: section.count,
            startWeek: weekSpec.start,
            endWeek: weekSpec.end,
            weekPattern: weekSpec.pattern,
            customWeeks: weekSpec.customWeeks,
            color: CourseColorPalette.getColorForName(
              _cleanCourseName(currentCourseName),
            ),
          ),
        );
      }
      if (result.isNotEmpty) {
        return result;
      }
    }

    // 2. 多行/多块通用教务单元格解析（适配树维、正方、强智、青果、PDF 导出表格）
    // 先按常见课程块分隔符切分（空行、横线、星号、◆、◇ 等）
    final rawBlocks = cleaned
        .split(RegExp(r'\n\s*\n|[-─━]{3,}|[◆◇★●]'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final parsedCourses = <Course>[];
    var seq = 0;

    for (final block in rawBlocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      // 检查块内是否紧贴着多门课程（以多个含「周」的行作为锚点拆分）
      final subBlocks = _splitTightlyPackedCourseLines(lines);
      for (final subLines in subBlocks) {
        final course = _parseSingleCourseLines(
          lines: subLines,
          weekday: weekday,
          fallbackStartSection: fallbackStartSection,
          fallbackSectionCount: fallbackSectionCount,
          id: '$idPrefix-${seq++}',
        );
        if (course != null) {
          parsedCourses.add(course);
        }
      }
    }

    return parsedCourses;
  }

  /// 将紧贴在一起的多门课程行拆成多个子块
  static List<List<String>> _splitTightlyPackedCourseLines(List<String> lines) {
    if (lines.length <= 3) {
      return [lines];
    }

    final weekLineIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_looksLikeWeekLine(lines[i])) {
        weekLineIndices.add(i);
      }
    }
    if (weekLineIndices.length <= 1) {
      return [lines];
    }

    // 每遇到新的课程名（通常在下一个周次行之前 1~2 行），切分新块
    final chunks = <List<String>>[];
    var start = 0;
    for (var idx = 1; idx < weekLineIndices.length; idx++) {
      final prevWeek = weekLineIndices[idx - 1];
      final currWeek = weekLineIndices[idx];
      if (currWeek - prevWeek >= 2) {
        final splitAt = currWeek - 1;
        if (splitAt > start) {
          chunks.add(lines.sublist(start, splitAt));
          start = splitAt;
        }
      }
    }
    if (start < lines.length) {
      chunks.add(lines.sublist(start));
    }
    return chunks.isEmpty ? [lines] : chunks;
  }

  static Course? _parseSingleCourseLines({
    required List<String> lines,
    required int weekday,
    required int fallbackStartSection,
    required int fallbackSectionCount,
    required String id,
  }) {
    if (lines.isEmpty) return null;

    var name = '';
    var teacher = '';
    var classroom = '';
    var campus = '';
    WeekSpec? weekSpec;
    SectionRange? sectionRange;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line == '星期' || line == '节次' || line == '时间') {
        continue;
      }

      // 第一行通常为课程名（去掉末尾可能附带的 [必修]/(1-16周) 等）
      if (name.isEmpty && !_looksLikeWeekLine(line) && !_looksLikePureSectionLine(line)) {
        // 如果第一行同时包含课程名和括号里的周次/节次
        final inlineWeek = RegExp(r'[(（\[]([^()（）\[\]]*周[^()（）\[\]]*)[)）\]]')
            .firstMatch(line);
        if (inlineWeek != null) {
          weekSpec ??= parseWeekSpec(inlineWeek.group(1)!);
          name = _cleanCourseName(line.substring(0, inlineWeek.start));
          final rest = line.substring(inlineWeek.end).trim();
          if (rest.isNotEmpty) {
            final sec = parseSection(rest);
            if (sec != null && rest.contains('节')) {
              sectionRange ??= sec;
            } else {
              final pair = extractClassroomAndTeacher(rest);
              if (classroom.isEmpty) classroom = pair.classroom;
              if (teacher.isEmpty) teacher = pair.teacher;
            }
          }
        } else {
          name = _cleanCourseName(line);
        }
        continue;
      }

      // 检测校区
      for (final c in const ['长安校区', '友谊校区', '太仓校区', '太仓智汇港']) {
        if (line.contains(c) && campus.isEmpty) {
          campus = c;
        }
      }

      // 检测周次
      if (_looksLikeWeekLine(line)) {
        final extractedWeek = _extractWeekSnippet(line);
        weekSpec ??= parseWeekSpec(extractedWeek);
      }

      // 检测节次
      if (line.contains('节') || RegExp(r'\d{1,2}:\d{2}\s*[-~]\s*\d{1,2}:\d{2}').hasMatch(line)) {
        final sec = parseSection(line);
        if (sec != null) {
          sectionRange ??= sec;
        }
      }

      // 如果该行主要是周次/节次但末尾跟了教室或老师
      if (_looksLikeWeekLine(line) || _looksLikePureSectionLine(line)) {
        final stripped = line
            .replaceAll(RegExp(r'[(（\[][^()（）\[\]]*[周节][^()（）\[\]]*[)）\]]'), '')
            .replaceAll(RegExp(r'第?\d{1,2}(?:\s*[-~,，、]\s*\d{1,2})*\s*周(?:\s*[(（]?[单双][)）]?)?'), '')
            .replaceAll(RegExp(r'第?\d{1,2}(?:\s*[-~,，、]\s*\d{1,2})*\s*节'), '')
            .trim();
        if (stripped.isNotEmpty) {
          if (_looksLikeClassroom(stripped) && classroom.isEmpty) {
            classroom = stripped;
          } else if (teacher.isEmpty && _looksLikeTeacher(stripped)) {
            teacher = stripped;
          }
        }
        continue;
      }

      // 检测教室
      if (_looksLikeClassroom(line)) {
        if (classroom.isEmpty) {
          classroom = line.replaceAll(RegExp(r'^(教室|地点)[:：]\s*'), '').trim();
        }
        continue;
      }

      // 检测教师
      if (line.startsWith('教师') || line.startsWith('老师')) {
        teacher = line.replaceAll(RegExp(r'^(教师|老师)[:：]\s*'), '').trim();
        continue;
      }
      if (teacher.isEmpty && _looksLikeTeacher(line)) {
        teacher = line;
        continue;
      }

      if (classroom.isEmpty && line.length <= 24) {
        classroom = line;
      }
    }

    if (name.isEmpty || name.length < 2) {
      return null;
    }

    final resolvedSection = sectionRange ??
        SectionRange(
          start: fallbackStartSection.clamp(1, AppConstants.sectionCount),
          end: (fallbackStartSection + fallbackSectionCount - 1)
              .clamp(1, AppConstants.sectionCount),
        );
    final resolvedWeek = weekSpec ??
        const WeekSpec(
          start: 1,
          end: 18,
          pattern: WeekPattern.all,
          customWeeks: [],
        );

    return Course(
      id: id,
      name: name,
      teacher: teacher,
      classroom: classroom,
      campus: campus,
      weekday: weekday.clamp(1, AppConstants.weekdayCount),
      startSection: resolvedSection.start,
      sectionCount: resolvedSection.count,
      startWeek: resolvedWeek.start,
      endWeek: resolvedWeek.end,
      weekPattern: resolvedWeek.pattern,
      customWeeks: resolvedWeek.customWeeks,
      color: CourseColorPalette.getColorForName(name),
    );
  }

  /// 解析分隔符或自然语言单行课程文本
  static Course? parseFreeformLine(String line, int index, {String idPrefix = 'text'}) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.length < 4) {
      return null;
    }

    // 1. 分隔符行：课程名, 周三, 3-4节, 1-16周, 教室, 教师
    final parts = trimmed
        .split(RegExp(r'[,，\t|｜]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 4) {
      final weekday = parseWeekday(parts[1]);
      final section = parseSection(parts[2]);
      final week = parseWeekSpec(parts[3]);
      if (weekday != null && section != null && week != null && parts[0].isNotEmpty) {
        final name = _cleanCourseName(parts[0]);
        return Course(
          id: '$idPrefix-$index',
          name: name,
          classroom: parts.length > 4 ? parts[4] : '',
          teacher: parts.length > 5 ? parts[5] : '',
          campus: parts.length > 6 ? parts[6] : '',
          weekday: weekday,
          startSection: section.start,
          sectionCount: section.count,
          startWeek: week.start,
          endWeek: week.end,
          weekPattern: week.pattern,
          customWeeks: week.customWeeks,
          color: CourseColorPalette.getColorForName(name),
        );
      }
    }

    // 2. 空格混合格式：高等数学 星期一 第1-2节 1-16周 教西D102 张三
    final weekdayMatch =
        RegExp(r'(?:星期|周)[一二三四五六日天七]').firstMatch(trimmed);
    final sectionMatch =
        RegExp(r'第?\d{1,2}(?:[-~至,，]\d{1,2})?节').firstMatch(trimmed);
    final weekMatch =
        RegExp(r'第?\d{1,2}(?:[-~,，、]\d{1,2})*周(?:\s*[(（]?[单双][)）]?)?')
            .firstMatch(trimmed);

    if (weekdayMatch != null && sectionMatch != null) {
      final firstMetaStart = [
        weekdayMatch.start,
        sectionMatch.start,
        if (weekMatch != null) weekMatch.start,
      ].reduce((a, b) => a < b ? a : b);

      final name = _cleanCourseName(trimmed.substring(0, firstMetaStart));
      final weekday = parseWeekday(weekdayMatch.group(0)!);
      final section = parseSection(sectionMatch.group(0)!);
      final week = weekMatch != null
          ? parseWeekSpec(weekMatch.group(0)!)
          : const WeekSpec(
              start: 1,
              end: 18,
              pattern: WeekPattern.all,
              customWeeks: [],
            );

      if (name.isNotEmpty && weekday != null && section != null && week != null) {
        final tailStart = [
          weekdayMatch.end,
          sectionMatch.end,
          if (weekMatch != null) weekMatch.end,
        ].reduce((a, b) => a > b ? a : b);
        final tail = trimmed.substring(tailStart).trim();
        final info = extractClassroomAndTeacher(tail);

        return Course(
          id: '$idPrefix-$index',
          name: name,
          teacher: info.teacher,
          classroom: info.classroom,
          weekday: weekday,
          startSection: section.start,
          sectionCount: section.count,
          startWeek: week.start,
          endWeek: week.end,
          weekPattern: week.pattern,
          customWeeks: week.customWeeks,
          color: CourseColorPalette.getColorForName(name),
        );
      }
    }

    return null;
  }

  /// 拆分尾部文本里的教室和教师
  static ClassroomTeacherPair extractClassroomAndTeacher(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const ClassroomTeacherPair(classroom: '', teacher: '');
    }

    final parts = normalized.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 2) {
      if (_looksLikeClassroom(parts[0]) && !_looksLikeClassroom(parts[1])) {
        return ClassroomTeacherPair(classroom: parts[0], teacher: parts[1]);
      }
      if (_looksLikeClassroom(parts[1]) && !_looksLikeClassroom(parts[0])) {
        return ClassroomTeacherPair(classroom: parts[1], teacher: parts[0]);
      }
    }

    final allTeacherMatches =
        RegExp(r'[\u4e00-\u9fa5A-Za-z·]{2,10}(?=\d|全校|本科|$)')
            .allMatches(normalized)
            .toList();
    if (allTeacherMatches.isEmpty) {
      return ClassroomTeacherPair(classroom: normalized, teacher: '');
    }

    final teacherMatch = allTeacherMatches.last;
    final teacher = teacherMatch.group(0)?.trim() ?? '';
    final classroom = normalized.substring(0, teacherMatch.start).trim();
    if (classroom.isEmpty && _looksLikeClassroom(teacher)) {
      return ClassroomTeacherPair(classroom: teacher, teacher: '');
    }
    return ClassroomTeacherPair(classroom: classroom, teacher: teacher);
  }

  /// 对解析出的课程去重、合并连续同课节次并补全默认莫兰迪颜色
  static List<Course> dedupeAndMergeCourses(List<Course> rawCourses) {
    final deduped = <String, Course>{};
    for (final raw in rawCourses) {
      final name = raw.name.trim();
      if (name.isEmpty) continue;

      final startSection = raw.startSection.clamp(1, AppConstants.sectionCount);
      final maxCount = AppConstants.sectionCount - startSection + 1;
      final sectionCount = raw.sectionCount.clamp(1, maxCount);
      final startWeek = raw.startWeek.clamp(AppConstants.minWeek, AppConstants.maxWeek);
      final endWeek = raw.endWeek.clamp(startWeek, AppConstants.maxWeek);
      final weekday = raw.weekday.clamp(1, AppConstants.weekdayCount);

      final course = raw.copyWith(
        name: name,
        weekday: weekday,
        startSection: startSection,
        sectionCount: sectionCount,
        startWeek: startWeek,
        endWeek: endWeek,
        color: raw.color == 0xFF4F779A
            ? CourseColorPalette.getColorForName(name)
            : raw.color,
      );

      final key =
          '${course.name}|${course.weekday}|${course.startSection}|${course.sectionCount}|${course.startWeek}|${course.endWeek}|${course.weekPattern.name}|${course.customWeeks.join(",")}|${course.classroom}|${course.teacher}';
      deduped[key] = course;
    }

    final sorted = deduped.values.toList()
      ..sort((a, b) {
        final w = a.weekday.compareTo(b.weekday);
        if (w != 0) return w;
        final s = a.startSection.compareTo(b.startSection);
        if (s != 0) return s;
        return a.name.compareTo(b.name);
      });

    // 合并相邻节次的完全同课程
    final merged = <Course>[];
    for (final course in sorted) {
      var didMerge = false;
      for (var i = 0; i < merged.length; i++) {
        if (merged[i].canMergeWith(course) &&
            _sameInts(merged[i].customWeeks, course.customWeeks)) {
          merged[i] = merged[i].mergeWith(course);
          didMerge = true;
          break;
        }
      }
      if (!didMerge) {
        merged.add(course);
      }
    }

    return merged;
  }

  static bool _looksLikeWeekLine(String line) {
    return RegExp(r'\d+\s*[-~,，、]?\s*\d*\s*周').hasMatch(line) ||
        line.contains('单周') ||
        line.contains('双周');
  }

  static bool _looksLikePureSectionLine(String line) {
    return RegExp(r'^[(（\[]?第?\d{1,2}(?:\s*[-~,，]\s*\d{1,2})*\s*节[)）\]]?$')
        .hasMatch(line.trim());
  }

  static String _extractWeekSnippet(String line) {
    final match = RegExp(
      r'第?\d{1,2}(?:\s*[-~至到,，、]\s*\d{1,2})*\s*周(?:\s*[(（]?[单双][)）]?)?',
    ).firstMatch(line);
    return match?.group(0) ?? line;
  }

  static bool _looksLikeClassroom(String text) {
    return RegExp(
      r'(教[东西南北中]?|教学楼|实验楼|楼|室|馆|场|区|厅|中心|机房|阶梯|[A-Za-z]\d{2,4}|\d{3,4})',
    ).hasMatch(text);
  }

  static bool _looksLikeTeacher(String text) {
    if (text.length < 2 || text.length > 18) return false;
    if (RegExp(r'\d').hasMatch(text)) return false;
    return RegExp(r'^[\u4e00-\u9fa5A-Za-z·,，、\s]+$').hasMatch(text);
  }

  static String _cleanCourseName(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\[\(（【]+|[\]\)）】]+$'), '')
        .trim();
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

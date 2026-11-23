import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/course_color_palette.dart';
import '../../../domain/entities/course.dart';
import '../../../domain/entities/section_time.dart';
import '../../models/course_model.dart';
import 'schedule_text_utils.dart';

/// 通用 JSON 课表解析器
/// 支持：
/// 1. 西工大翱翔教务 / 树维 EAMS5（studentTableVm.activities / studentTableVms / arrangedLessonSearchVms）
/// 2. 正方教务（kbList：kcmc / xm / cdmc / xqj / jcs / zcd）
/// 3. 强智教务（kcmc / jsxm / jsmc / xq / ksjc / jsjc / zc）
/// 4. WakeUp 课程表导出文件（单 JSON 或多行分段 JSON）
/// 5. 本应用标准 JSON（camelCase / snake_case / {courses: [...]})
class JsonScheduleParser {
  const JsonScheduleParser._();

  static List<Course> parseBytes(List<int> bytes) {
    final content = ScheduleTextUtils.decodeBytesFlexible(bytes);
    return parseString(content);
  }

  static List<Course> parseString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    // 1. 尝试整体 JSON 解码
    try {
      final decoded = jsonDecode(trimmed);
      final parsed = parseDecoded(decoded);
      if (parsed.isNotEmpty) {
        return ScheduleTextUtils.dedupeAndMergeCourses(parsed);
      }
    } catch (_) {
      // 尝试 WakeUp 多行 JSON（每行一段 JSON，常见于 .wakeup_schedule 文件）
      final multiLine = _tryParseWakeUpMultiLineJson(trimmed);
      if (multiLine.isNotEmpty) {
        return ScheduleTextUtils.dedupeAndMergeCourses(multiLine);
      }
    }

    return const [];
  }

  static List<Course> parseDecoded(
    dynamic decoded, {
    SectionTimeTable? timeTable,
  }) {
    final resolvedTable = extractSectionTimeTable(decoded) ?? timeTable;

    // 1. 优先尝试树维 EAMS5 / 西工大翱翔教务结构
    final eamsCourses = _tryParseEamsTree(decoded, timeTable: resolvedTable);
    if (eamsCourses.isNotEmpty) {
      return eamsCourses;
    }

    // 2. 尝试正方 / 强智 / 通用教务字段结构
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final listField = map['kbList'] ??
          map['lessonList'] ??
          map['activities'] ??
          map['data'] ??
          map['list'] ??
          map['rows'] ??
          map['courses'];
      if (listField is List) {
        final jiaowu = _parseGenericCourseMaps(listField, timeTable: resolvedTable);
        if (jiaowu.isNotEmpty) {
          return jiaowu;
        }
      }
      if (listField is Map) {
        final nested = parseDecoded(listField, timeTable: resolvedTable);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      // 单个课程对象
      final single = _parseSingleCourseMap(map, 1, timeTable: resolvedTable);
      if (single != null) {
        return [single];
      }
    } else if (decoded is List) {
      return _parseGenericCourseMaps(decoded, timeTable: resolvedTable);
    }

    return const [];
  }

  /// 从树维 EAMS5 / 西工大教务 JSON 中提取真实的上下课作息时间表（courseUnitList / units）
  static SectionTimeTable? extractSectionTimeTable(dynamic node) {
    List<dynamic>? rawUnits;

    void scan(dynamic current) {
      if (rawUnits != null) return;
      if (current is Map) {
        for (final key in const ['courseUnitList', 'units', 'timeSlots']) {
          final v = current[key];
          if (v is List && v.length >= 8 && v.first is Map) {
            rawUnits = v;
            return;
          }
        }
        for (final key in const [
          'timeTableLayout',
          'studentTableVm',
          'datum',
          'data',
        ]) {
          if (current[key] != null) {
            scan(current[key]);
            if (rawUnits != null) return;
          }
        }
      } else if (current is List) {
        for (final item in current) {
          scan(item);
          if (rawUnits != null) return;
        }
      }
    }

    scan(node);
    if (rawUnits == null) return null;

    final slots = <SectionTimeSlot>[];
    for (var i = 0; i < rawUnits!.length; i++) {
      final item = rawUnits![i];
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final sec = _toInt(m['indexNo'] ?? m['index'] ?? m['section'] ?? m['node']) ??
          (i + 1);
      final start = SectionTimeSlot.parseHourMinute(
        m['startTime'] ?? m['start'] ?? m['beginTime'],
      );
      final end = SectionTimeSlot.parseHourMinute(
        m['endTime'] ?? m['end'] ?? m['finishTime'],
      );
      if (start == null || end == null) continue;
      if (sec < 1 || sec > AppConstants.sectionCount) continue;

      slots.add(
        SectionTimeSlot(
          section: sec,
          startHour: start.$1,
          startMinute: start.$2,
          endHour: end.$1,
          endMinute: end.$2,
        ),
      );
    }

    if (slots.length < 8) return null;
    slots.sort((a, b) => a.section.compareTo(b.section));
    return SectionTimeTable(
      presetId: 'jiaowu_synced',
      presetName: '教务同步作息 (${slots.length}节)',
      slots: slots,
    );
  }

  /// 递归查找树维 EAMS5 的 studentTableVm / studentTableVms / activities 结构
  static List<Course> _tryParseEamsTree(
    dynamic node, {
    SectionTimeTable? timeTable,
  }) {
    final collected = <Map<String, dynamic>>[];

    void visit(dynamic current) {
      if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        if (map['activities'] is List) {
          for (final item in map['activities'] as List) {
            if (item is Map) {
              collected.add(Map<String, dynamic>.from(item));
            }
          }
        }
        if (map['studentTableVm'] != null) {
          visit(map['studentTableVm']);
        }
        if (map['studentTableVms'] is List) {
          for (final vm in map['studentTableVms'] as List) {
            visit(vm);
          }
        }
        if (map['arrangedLessonSearchVms'] is List) {
          for (final vm in map['arrangedLessonSearchVms'] as List) {
            visit(vm);
          }
        }
        if (map['datum'] != null) {
          visit(map['datum']);
        }
        if (map['data'] is Map) {
          visit(map['data']);
        }
      } else if (current is List) {
        for (final item in current) {
          if (item is Map &&
              (item.containsKey('activities') ||
                  item.containsKey('studentTableVm') ||
                  item.containsKey('weekIndexes') ||
                  item.containsKey('startUnit'))) {
            if (item.containsKey('startUnit') || item.containsKey('weekIndexes')) {
              collected.add(Map<String, dynamic>.from(item));
            } else {
              visit(item);
            }
          }
        }
      }
    }

    visit(node);
    if (collected.isEmpty) {
      return const [];
    }

    final courses = <Course>[];
    var counter = 1;
    for (final act in collected) {
      final parsed = _parseEamsActivity(act, counter++, timeTable: timeTable);
      if (parsed != null) {
        courses.add(parsed);
      }
    }
    return courses;
  }

  /// 解析单条树维 EAMS5 activity 对象
  static Course? _parseEamsActivity(
    Map<String, dynamic> act,
    int index, {
    SectionTimeTable? timeTable,
  }) {
    final name = _readLocalizedName(
      act['courseName'] ??
          act['lessonName'] ??
          act['name'] ??
          (act['course'] is Map ? (act['course'] as Map)['nameZh'] : null) ??
          act['kcmc'],
    );
    if (name.isEmpty) return null;

    // 教师：可能是 List<String>、List<Map{nameZh/name}> 或 String
    final teacher = _readTeachers(
      act['teachers'] ??
          act['teacherNames'] ??
          act['teacherName'] ??
          act['teacher'] ??
          act['xm'],
    );

    // 教室：可能是 String、Map{nameZh/name} 或 customPlace
    var classroom = _readLocalizedName(
      act['room'] ??
          act['roomName'] ??
          act['classroom'] ??
          act['customPlace'] ??
          act['cdmc'],
    );
    if (classroom.isEmpty && act['building'] != null) {
      classroom = _readLocalizedName(act['building']);
    }

    final campus = _readLocalizedName(
      act['campus'] ?? act['campusName'] ?? act['xqmc'],
    );

    final weekdayRaw =
        act['weekday'] ?? act['dayOfWeek'] ?? act['day'] ?? act['xqj'] ?? act['skxq'];
    final weekday = _toInt(weekdayRaw) ??
        ScheduleTextUtils.parseWeekday(weekdayRaw?.toString() ?? '') ??
        1;

    final startUnit = _toInt(
      act['startUnit'] ??
          act['startSection'] ??
          act['start_section'] ??
          act['ksjc'] ??
          act['start'],
    );
    final endUnit = _toInt(
      act['endUnit'] ??
          act['endSection'] ??
          act['end_section'] ??
          act['jsjc'] ??
          act['end'],
    );

    SectionRange section;
    if (startUnit != null) {
      final resolvedEnd = endUnit ?? startUnit;
      section = SectionRange(
        start: startUnit.clamp(1, AppConstants.sectionCount),
        end: resolvedEnd.clamp(startUnit, AppConstants.sectionCount),
      );
    } else if (act['startTime'] != null && act['endTime'] != null) {
      final sPair = SectionTimeSlot.parseHourMinute(act['startTime']);
      final ePair = SectionTimeSlot.parseHourMinute(act['endTime']);
      section = (sPair != null && ePair != null)
          ? ScheduleTextUtils.mapMinutesToSectionRange(
              sPair.$1 * 60 + sPair.$2,
              ePair.$1 * 60 + ePair.$2,
              timeTable: timeTable,
            )
          : const SectionRange(start: 1, end: 2);
    } else {
      section = ScheduleTextUtils.parseSection(
            (act['jcs'] ?? act['section'] ?? '').toString(),
            timeTable: timeTable,
          ) ??
          const SectionRange(start: 1, end: 2);
    }

    // 周次：优先使用 weekIndexes 整数数组，次选 weeksStr / weeks
    WeekSpec? weekSpec;
    if (act['weekIndexes'] is List) {
      final nums = (act['weekIndexes'] as List)
          .map(_toInt)
          .whereType<int>()
          .toList();
      weekSpec = ScheduleTextUtils.buildWeekSpecFromList(nums);
    }
    weekSpec ??= ScheduleTextUtils.parseWeekSpec(
      (act['weeksStr'] ?? act['weeks'] ?? act['zcd'] ?? act['zcs'] ?? '')
          .toString(),
    );
    weekSpec ??= const WeekSpec(
      start: 1,
      end: 18,
      pattern: WeekPattern.all,
      customWeeks: [],
    );

    final noteParts = <String>[];
    final code = (act['lessonCode'] ?? act['courseCode'] ?? '').toString().trim();
    if (code.isNotEmpty) noteParts.add('课号: $code');
    final credits = act['credits'] ?? act['credit'];
    if (credits != null && credits.toString().trim().isNotEmpty) {
      noteParts.add('学分: $credits');
    }

    return Course(
      id: 'nwpu-eams-$index',
      name: name,
      teacher: teacher,
      classroom: classroom,
      campus: campus.isEmpty ? '长安校区' : campus,
      weekday: weekday.clamp(1, AppConstants.weekdayCount),
      startSection: section.start,
      sectionCount: section.count,
      startWeek: weekSpec.start,
      endWeek: weekSpec.end,
      weekPattern: weekSpec.pattern,
      customWeeks: weekSpec.customWeeks,
      color: CourseColorPalette.getColorForName(name),
      note: noteParts.join(' · '),
    );
  }

  static List<Course> _parseGenericCourseMaps(
    List<dynamic> list, {
    SectionTimeTable? timeTable,
  }) {
    final courses = <Course>[];
    var counter = 1;
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final parsed = _parseSingleCourseMap(map, counter++, timeTable: timeTable);
      if (parsed != null) {
        courses.add(parsed);
      }
    }
    return courses;
  }

  static Course? _parseSingleCourseMap(
    Map<String, dynamic> map,
    int index, {
    SectionTimeTable? timeTable,
  }) {
    // 若包含正方/强智/树维特有字段，走教务字段适配
    final isJiaowuShape = map.containsKey('kcmc') ||
        map.containsKey('xqj') ||
        map.containsKey('skxq') ||
        map.containsKey('jcs') ||
        map.containsKey('zcd') ||
        map.containsKey('zcs') ||
        map.containsKey('startUnit') ||
        map.containsKey('weekIndexes');

    if (isJiaowuShape) {
      if (map.containsKey('startUnit') || map.containsKey('weekIndexes')) {
        return _parseEamsActivity(map, index, timeTable: timeTable);
      }
      final name =
          (map['kcmc'] ?? map['courseName'] ?? map['name'] ?? '').toString().trim();
      if (name.isEmpty) return null;

      final teacher = (map['xm'] ??
              map['jsxm'] ??
              map['teacher'] ??
              map['teacherName'] ??
              '')
          .toString()
          .trim();
      final classroom = (map['cdmc'] ??
              map['jsmc'] ??
              map['classroom'] ??
              map['room'] ??
              '')
          .toString()
          .trim();
      final campus = (map['xqmc'] ?? map['campus'] ?? '').toString().trim();

      final weekdayRaw =
          map['xqj'] ?? map['skxq'] ?? map['xq'] ?? map['dayOfWeek'] ?? map['weekday'];
      final weekday = _toInt(weekdayRaw) ??
          ScheduleTextUtils.parseWeekday(weekdayRaw?.toString() ?? '') ??
          1;

      SectionRange? section;
      if (map['jcs'] != null) {
        section = ScheduleTextUtils.parseSection(
          map['jcs'].toString(),
          timeTable: timeTable,
        );
      }
      if (section == null) {
        final s = _toInt(map['ksjc'] ?? map['startSection'] ?? map['start']) ?? 1;
        final e = _toInt(map['jsjc'] ?? map['endSection'] ?? map['end']) ?? s;
        section = SectionRange(
          start: s.clamp(1, AppConstants.sectionCount),
          end: e.clamp(s, AppConstants.sectionCount),
        );
      }

      final weekSpec = ScheduleTextUtils.parseWeekSpec(
            (map['zcd'] ?? map['zcs'] ?? map['zc'] ?? map['weeks'] ?? '')
                .toString(),
          ) ??
          const WeekSpec(
            start: 1,
            end: 18,
            pattern: WeekPattern.all,
            customWeeks: [],
          );

      return Course(
        id: 'jiaowu-$index',
        name: name,
        teacher: teacher,
        classroom: classroom,
        campus: campus,
        weekday: weekday.clamp(1, AppConstants.weekdayCount),
        startSection: section.start,
        sectionCount: section.count,
        startWeek: weekSpec.start,
        endWeek: weekSpec.end,
        weekPattern: weekSpec.pattern,
        customWeeks: weekSpec.customWeeks,
        color: CourseColorPalette.getColorForName(name),
      );
    }

    // 否则按本应用标准 CourseModel 解析
    final model = CourseModel.fromJson(map);
    if (model.name.trim().isEmpty) {
      return null;
    }
    return model.toEntity();
  }

  /// 兼容 WakeUp 课程表导出的 5 行 JSON 文本格式
  static List<Course> _tryParseWakeUpMultiLineJson(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 4) return const [];

    try {
      // WakeUp 格式通常第 4 行是课程基本信息数组，第 5 行是排课时间节点数组
      List<dynamic>? courseDefs;
      List<dynamic>? courseNodes;

      for (final line in lines) {
        if (!line.startsWith('[')) continue;
        final arr = jsonDecode(line);
        if (arr is! List || arr.isEmpty || arr.first is! Map) continue;
        final sample = arr.first as Map;
        if (sample.containsKey('courseName') && sample.containsKey('id')) {
          courseDefs = arr;
        } else if (sample.containsKey('day') &&
            sample.containsKey('startNode') &&
            sample.containsKey('startWeek')) {
          courseNodes = arr;
        }
      }

      if (courseDefs == null || courseNodes == null) {
        return const [];
      }

      final defById = <dynamic, Map<String, dynamic>>{};
      for (final item in courseDefs) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          defById[m['id']] = m;
        }
      }

      final courses = <Course>[];
      var idx = 1;
      for (final node in courseNodes) {
        if (node is! Map) continue;
        final m = Map<String, dynamic>.from(node);
        final def = defById[m['id']];
        final name = (def?['courseName'] ?? m['courseName'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final weekday = (_toInt(m['day']) ?? 1).clamp(1, 7);
        final startNode =
            (_toInt(m['startNode']) ?? 1).clamp(1, AppConstants.sectionCount);
        final step = (_toInt(m['step']) ?? 2)
            .clamp(1, AppConstants.sectionCount - startNode + 1);
        final startWeek = (_toInt(m['startWeek']) ?? 1).clamp(1, 25);
        final endWeek = (_toInt(m['endWeek']) ?? startWeek).clamp(startWeek, 25);
        final type = _toInt(m['type']) ?? 0;
        final pattern = switch (type) {
          1 => WeekPattern.odd,
          2 => WeekPattern.even,
          _ => WeekPattern.all,
        };

        courses.add(
          Course(
            id: 'wakeup-${idx++}',
            name: name,
            teacher: (m['teacher'] ?? '').toString().trim(),
            classroom: (m['room'] ?? '').toString().trim(),
            weekday: weekday,
            startSection: startNode,
            sectionCount: step,
            startWeek: startWeek,
            endWeek: endWeek,
            weekPattern: pattern,
            color: CourseColorPalette.getColorForName(name),
          ),
        );
      }
      return courses;
    } catch (_) {
      return const [];
    }
  }

  static String _readLocalizedName(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      return (value['nameZh'] ??
              value['name'] ??
              value['title'] ??
              value['nameEn'] ??
              '')
          .toString()
          .trim();
    }
    return value.toString().trim();
  }

  static String _readTeachers(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      final names = value
          .map(_readLocalizedName)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      return names.join('、');
    }
    return _readLocalizedName(value);
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }
}

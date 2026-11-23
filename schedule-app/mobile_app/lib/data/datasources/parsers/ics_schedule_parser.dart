import '../../../core/constants/app_constants.dart';
import '../../../core/constants/course_color_palette.dart';
import '../../../domain/entities/course.dart';
import 'schedule_text_utils.dart';

/// iCalendar (.ics) 课表解析器
/// 支持 RFC 5545 折行展开、时间段映射节次、RRULE 重复规则推算周次、多条同名事件聚合
class IcsScheduleParser {
  const IcsScheduleParser._();

  static List<Course> parseBytes(List<int> bytes) {
    final text = ScheduleTextUtils.decodeBytesFlexible(bytes);
    return parseString(text);
  }

  static List<Course> parseString(String content) {
    // 1. RFC 5545 折行展开（换行后跟单个空格或 Tab 视为续行）
    final unfolded = content.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));

    final rawEvents = <Map<String, String>>[];
    Map<String, String>? current;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VEVENT') {
        current = <String, String>{};
      } else if (line == 'END:VEVENT') {
        if (current != null && current.isNotEmpty) {
          rawEvents.add(current);
        }
        current = null;
      } else if (current != null) {
        final colon = line.indexOf(':');
        if (colon > 0) {
          final key = line.substring(0, colon).split(';').first.toUpperCase();
          final value = _unescapeIcsValue(line.substring(colon + 1));
          current[key] = value;
        }
      }
    }

    if (rawEvents.isEmpty) {
      return const [];
    }

    // 2. 找出所有事件中最早的周一作为学期第 1 周基准，用于从日期聚合成周次
    final parsedEvents = <_ParsedIcsEvent>[];
    DateTime? earliestDate;

    for (final event in rawEvents) {
      final summary = (event['SUMMARY'] ?? '').trim();
      if (summary.isEmpty) continue;

      final startDt = _parseIcsDateTime(event['DTSTART'] ?? '');
      if (startDt == null) continue;
      final endDt = _parseIcsDateTime(event['DTEND'] ?? '');

      if (earliestDate == null || startDt.isBefore(earliestDate)) {
        earliestDate = startDt;
      }

      final startMin = startDt.hour * 60 + startDt.minute;
      final endMin = endDt != null
          ? endDt.hour * 60 + endDt.minute
          : startMin + 95;
      final section = ScheduleTextUtils.mapMinutesToSectionRange(
        startMin,
        endMin,
      );

      final location = (event['LOCATION'] ?? '').trim();
      final description = (event['DESCRIPTION'] ?? '').trim();
      final rrule = (event['RRULE'] ?? '').trim();

      parsedEvents.add(
        _ParsedIcsEvent(
          name: summary,
          location: location,
          description: description,
          startDt: startDt,
          weekday: startDt.weekday,
          section: section,
          rrule: rrule,
        ),
      );
    }

    if (parsedEvents.isEmpty || earliestDate == null) {
      return const [];
    }

    final anchorMonday = DateTime(
      earliestDate.year,
      earliestDate.month,
      earliestDate.day,
    ).subtract(Duration(days: earliestDate.weekday - 1));

    // 3. 将同名、同星期、同节次、同地点的离散事件聚合为带周次的课程
    final grouped = <String, List<_ParsedIcsEvent>>{};
    for (final e in parsedEvents) {
      final key =
          '${e.name}|${e.weekday}|${e.section.start}|${e.section.end}|${e.location}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final courses = <Course>[];
    var idx = 1;
    for (final group in grouped.values) {
      final first = group.first;
      final weeks = <int>{};

      for (final ev in group) {
        final evDate = DateTime(ev.startDt.year, ev.startDt.month, ev.startDt.day);
        final baseWeek = (evDate.difference(anchorMonday).inDays ~/ 7) + 1;
        if (baseWeek >= AppConstants.minWeek && baseWeek <= AppConstants.maxWeek) {
          weeks.add(baseWeek);
        }

        // 解析 RRULE（如 FREQ=WEEKLY;INTERVAL=2;COUNT=8 或 UNTIL=...）
        if (ev.rrule.isNotEmpty) {
          final ruleMap = _parseRRule(ev.rrule);
          final interval = int.tryParse(ruleMap['INTERVAL'] ?? '1') ?? 1;
          final count = int.tryParse(ruleMap['COUNT'] ?? '');
          final untilDt = ruleMap['UNTIL'] != null
              ? _parseIcsDateTime(ruleMap['UNTIL']!)
              : null;

          if (count != null && count > 1) {
            for (var step = 0; step < count; step++) {
              final w = baseWeek + step * interval;
              if (w >= AppConstants.minWeek && w <= AppConstants.maxWeek) {
                weeks.add(w);
              }
            }
          } else if (untilDt != null) {
            var cursor = evDate;
            var guard = 0;
            while (!cursor.isAfter(untilDt) && guard < 30) {
              final w = (cursor.difference(anchorMonday).inDays ~/ 7) + 1;
              if (w >= AppConstants.minWeek && w <= AppConstants.maxWeek) {
                weeks.add(w);
              }
              cursor = cursor.add(Duration(days: 7 * interval));
              guard++;
            }
          }
        }
      }

      // 优先检查描述中是否有明确周次说明
      WeekSpec? weekSpec;
      if (first.description.contains('周')) {
        weekSpec = ScheduleTextUtils.parseWeekSpec(first.description);
      }
      weekSpec ??= ScheduleTextUtils.buildWeekSpecFromList(weeks.toList()) ??
          const WeekSpec(
            start: 1,
            end: 18,
            pattern: WeekPattern.all,
            customWeeks: [],
          );

      final teacher = _extractTeacherFromDescription(first.description);

      courses.add(
        Course(
          id: 'ics-${idx++}',
          name: first.name,
          teacher: teacher,
          classroom: first.location,
          weekday: first.weekday,
          startSection: first.section.start,
          sectionCount: first.section.count,
          startWeek: weekSpec.start,
          endWeek: weekSpec.end,
          weekPattern: weekSpec.pattern,
          customWeeks: weekSpec.customWeeks,
          color: CourseColorPalette.getColorForName(first.name),
          note: teacher.isEmpty ? first.description : '',
        ),
      );
    }

    return ScheduleTextUtils.dedupeAndMergeCourses(courses);
  }

  static DateTime? _parseIcsDateTime(String raw) {
    final cleaned = raw.trim();
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?',
    ).firstMatch(cleaned);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = match.group(4) != null ? int.parse(match.group(4)!) : 8;
    final minute = match.group(5) != null ? int.parse(match.group(5)!) : 30;
    final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
    final isUtc = match.group(7) == 'Z';

    if (isUtc) {
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    }
    return DateTime(year, month, day, hour, minute, second);
  }

  static Map<String, String> _parseRRule(String rrule) {
    final map = <String, String>{};
    for (final part in rrule.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        map[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
      }
    }
    return map;
  }

  static String _extractTeacherFromDescription(String desc) {
    if (desc.isEmpty) return '';
    final match =
        RegExp(r'(?:教师|老师|任课教师|主讲)[:：\s]*([^\n,，;；]+)').firstMatch(desc);
    if (match != null) {
      return match.group(1)!.trim();
    }
    if (desc.length <= 12 && !desc.contains('\n')) {
      return desc;
    }
    return '';
  }

  static String _unescapeIcsValue(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\')
        .trim();
  }
}

class _ParsedIcsEvent {
  const _ParsedIcsEvent({
    required this.name,
    required this.location,
    required this.description,
    required this.startDt,
    required this.weekday,
    required this.section,
    required this.rrule,
  });

  final String name;
  final String location;
  final String description;
  final DateTime startDt;
  final int weekday;
  final SectionRange section;
  final String rrule;
}

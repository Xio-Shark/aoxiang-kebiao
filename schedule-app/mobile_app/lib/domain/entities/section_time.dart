import 'dart:convert';

import '../../core/constants/app_constants.dart';

/// 单节课的上下课时间槽
class SectionTimeSlot {
  const SectionTimeSlot({
    required this.section,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int section;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  int get startTotalMinutes => startHour * 60 + startMinute;
  int get endTotalMinutes => endHour * 60 + endMinute;

  String get startText =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  String get endText =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  String get rangeText => '$startText-$endText';

  SectionTimeSlot copyWith({
    int? section,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return SectionTimeSlot(
      section: section ?? this.section,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'section': section,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  factory SectionTimeSlot.fromJson(Map<String, dynamic> json) {
    return SectionTimeSlot(
      section: (json['section'] as num?)?.toInt() ?? 1,
      startHour: (json['startHour'] as num?)?.toInt() ?? 8,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 30,
      endHour: (json['endHour'] as num?)?.toInt() ?? 9,
      endMinute: (json['endMinute'] as num?)?.toInt() ?? 15,
    );
  }

  /// 从 "08:30" 或整数 830 / 1400 解析时分
  static (int, int)? parseHourMinute(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      final h = raw ~/ 100;
      final m = raw % 100;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return (h, m);
      }
      return null;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final colonMatch = RegExp(r'^(\d{1,2})[:：](\d{2})').firstMatch(text);
    if (colonMatch != null) {
      final h = int.parse(colonMatch.group(1)!);
      final m = int.parse(colonMatch.group(2)!);
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return (h, m);
      }
    }

    final compactInt = int.tryParse(text);
    if (compactInt != null && compactInt >= 100 && compactInt <= 2359) {
      final h = compactInt ~/ 100;
      final m = compactInt % 100;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return (h, m);
      }
    }
    return null;
  }
}

/// 整套作息时间表（节次与上下课时间的单一真相源）
class SectionTimeTable {
  const SectionTimeTable({
    required this.presetId,
    required this.presetName,
    required this.slots,
  });

  final String presetId;
  final String presetName;
  final List<SectionTimeSlot> slots;

  int get sectionCount => slots.length;

  /// 西工大长安校区作息（13 节制：上午 1-4，中午 5-6，下午 7-10，晚上 11-13）
  static const SectionTimeTable nwpuChangan = SectionTimeTable(
    presetId: 'nwpu_changan',
    presetName: '西工大长安校区 (13节)',
    slots: [
      SectionTimeSlot(section: 1, startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
      SectionTimeSlot(section: 2, startHour: 9, startMinute: 25, endHour: 10, endMinute: 10),
      SectionTimeSlot(section: 3, startHour: 10, startMinute: 30, endHour: 11, endMinute: 15),
      SectionTimeSlot(section: 4, startHour: 11, startMinute: 25, endHour: 12, endMinute: 10),
      SectionTimeSlot(section: 5, startHour: 12, startMinute: 20, endHour: 13, endMinute: 5),
      SectionTimeSlot(section: 6, startHour: 13, startMinute: 5, endHour: 13, endMinute: 50),
      SectionTimeSlot(section: 7, startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),
      SectionTimeSlot(section: 8, startHour: 14, startMinute: 55, endHour: 15, endMinute: 40),
      SectionTimeSlot(section: 9, startHour: 16, startMinute: 0, endHour: 16, endMinute: 45),
      SectionTimeSlot(section: 10, startHour: 16, startMinute: 55, endHour: 17, endMinute: 40),
      SectionTimeSlot(section: 11, startHour: 19, startMinute: 0, endHour: 19, endMinute: 45),
      SectionTimeSlot(section: 12, startHour: 19, startMinute: 55, endHour: 20, endMinute: 40),
      SectionTimeSlot(section: 13, startHour: 20, startMinute: 50, endHour: 21, endMinute: 35),
    ],
  );

  /// 西工大友谊校区冬季作息（10月1日 - 次年4月30日，13 节制）
  static const SectionTimeTable nwpuYouyiWinter = SectionTimeTable(
    presetId: 'nwpu_youyi_winter',
    presetName: '西工大友谊校区·冬季 (13节)',
    slots: [
      SectionTimeSlot(section: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
      SectionTimeSlot(section: 2, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
      SectionTimeSlot(section: 3, startHour: 10, startMinute: 10, endHour: 11, endMinute: 0),
      SectionTimeSlot(section: 4, startHour: 11, startMinute: 10, endHour: 12, endMinute: 0),
      SectionTimeSlot(section: 5, startHour: 12, startMinute: 20, endHour: 13, endMinute: 5),
      SectionTimeSlot(section: 6, startHour: 13, startMinute: 5, endHour: 13, endMinute: 50),
      SectionTimeSlot(section: 7, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
      SectionTimeSlot(section: 8, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
      SectionTimeSlot(section: 9, startHour: 16, startMinute: 10, endHour: 17, endMinute: 0),
      SectionTimeSlot(section: 10, startHour: 17, startMinute: 10, endHour: 18, endMinute: 0),
      SectionTimeSlot(section: 11, startHour: 19, startMinute: 0, endHour: 19, endMinute: 50),
      SectionTimeSlot(section: 12, startHour: 20, startMinute: 0, endHour: 20, endMinute: 50),
      SectionTimeSlot(section: 13, startHour: 20, startMinute: 55, endHour: 21, endMinute: 40),
    ],
  );

  /// 西工大友谊校区夏季作息（5月1日 - 9月30日，13 节制）
  static const SectionTimeTable nwpuYouyiSummer = SectionTimeTable(
    presetId: 'nwpu_youyi_summer',
    presetName: '西工大友谊校区·夏季 (13节)',
    slots: [
      SectionTimeSlot(section: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
      SectionTimeSlot(section: 2, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
      SectionTimeSlot(section: 3, startHour: 10, startMinute: 10, endHour: 11, endMinute: 0),
      SectionTimeSlot(section: 4, startHour: 11, startMinute: 10, endHour: 12, endMinute: 0),
      SectionTimeSlot(section: 5, startHour: 12, startMinute: 20, endHour: 13, endMinute: 5),
      SectionTimeSlot(section: 6, startHour: 13, startMinute: 5, endHour: 13, endMinute: 50),
      SectionTimeSlot(section: 7, startHour: 14, startMinute: 30, endHour: 15, endMinute: 20),
      SectionTimeSlot(section: 8, startHour: 15, startMinute: 30, endHour: 16, endMinute: 20),
      SectionTimeSlot(section: 9, startHour: 16, startMinute: 40, endHour: 17, endMinute: 30),
      SectionTimeSlot(section: 10, startHour: 17, startMinute: 40, endHour: 18, endMinute: 30),
      SectionTimeSlot(section: 11, startHour: 19, startMinute: 30, endHour: 20, endMinute: 20),
      SectionTimeSlot(section: 12, startHour: 20, startMinute: 30, endHour: 21, endMinute: 20),
      SectionTimeSlot(section: 13, startHour: 21, startMinute: 25, endHour: 22, endMinute: 10),
    ],
  );

  /// 通用高校 12 节制（上午 1-4，下午 5-8，晚上 9-12）
  static const SectionTimeTable standard12 = SectionTimeTable(
    presetId: 'standard_12',
    presetName: '通用高校标准 (12节)',
    slots: [
      SectionTimeSlot(section: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 45),
      SectionTimeSlot(section: 2, startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),
      SectionTimeSlot(section: 3, startHour: 10, startMinute: 0, endHour: 10, endMinute: 45),
      SectionTimeSlot(section: 4, startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),
      SectionTimeSlot(section: 5, startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),
      SectionTimeSlot(section: 6, startHour: 14, startMinute: 55, endHour: 15, endMinute: 40),
      SectionTimeSlot(section: 7, startHour: 16, startMinute: 0, endHour: 16, endMinute: 45),
      SectionTimeSlot(section: 8, startHour: 16, startMinute: 55, endHour: 17, endMinute: 40),
      SectionTimeSlot(section: 9, startHour: 19, startMinute: 0, endHour: 19, endMinute: 45),
      SectionTimeSlot(section: 10, startHour: 19, startMinute: 55, endHour: 20, endMinute: 40),
      SectionTimeSlot(section: 11, startHour: 20, startMinute: 50, endHour: 21, endMinute: 35),
      SectionTimeSlot(section: 12, startHour: 21, startMinute: 45, endHour: 22, endMinute: 30),
    ],
  );

  static const List<SectionTimeTable> presets = [
    nwpuChangan,
    nwpuYouyiWinter,
    nwpuYouyiSummer,
    standard12,
  ];

  static SectionTimeTable presetById(String id) {
    for (final preset in presets) {
      if (preset.presetId == id) return preset;
    }
    return nwpuChangan;
  }

  /// 获取第 [section] 节（1-based）的时间槽
  SectionTimeSlot? slotFor(int section) {
    for (final slot in slots) {
      if (slot.section == section) return slot;
    }
    if (section >= 1 && section <= slots.length) {
      return slots[section - 1];
    }
    return null;
  }

  /// 格式化某门课的精准上下课时间段（如 "14:00-15:40"）
  String formatCourseClockRange(int startSection, int sectionCount) {
    final endSection = startSection + sectionCount - 1;
    final startSlot = slotFor(startSection);
    final endSlot = slotFor(endSection) ?? startSlot;
    if (startSlot == null || endSlot == null) return '';
    return '${startSlot.startText}-${endSlot.endText}';
  }

  /// 返回课程的开始/结束时分描述（如 "08:30 上课 · 10:10 下课"）
  String formatCourseDetailTime(int startSection, int sectionCount) {
    final endSection = startSection + sectionCount - 1;
    final startSlot = slotFor(startSection);
    final endSlot = slotFor(endSection) ?? startSlot;
    if (startSlot == null || endSlot == null) return '';
    return '${startSlot.startText} - ${endSlot.endText}';
  }

  /// 判断哪些节次之后是午间/下午/晚间大时段分隔
  bool isPeriodBreakAfter(int section) {
    if (section >= sectionCount) return false;
    final curr = slotFor(section);
    final next = slotFor(section + 1);
    if (curr == null || next == null) return false;
    // 相邻两节间隔 >= 45 分钟（如午休、晚饭）或跨 12:15/13:55/18:00 边界
    final gap = next.startTotalMinutes - curr.endTotalMinutes;
    if (gap >= 40) return true;
    if (section == 4 || section == 6 || section == 10) {
      return sectionCount >= 13;
    }
    return false;
  }

  /// 将一天中的开始/结束分钟数精准映射到 (startSection, endSection)
  (int, int) mapMinutesToSections(int startMinutes, int endMinutes) {
    if (slots.isEmpty) {
      return (1, 2);
    }

    var startSec = slots.first.section;
    var bestStartDiff = 1 << 30;
    for (final slot in slots) {
      final diff = (startMinutes - slot.startTotalMinutes).abs();
      if (diff < bestStartDiff) {
        bestStartDiff = diff;
        startSec = slot.section;
      }
    }

    var endSec = startSec;
    if (endMinutes > startMinutes) {
      var bestEndDiff = 1 << 30;
      for (final slot in slots) {
        if (slot.section < startSec) continue;
        final diff = (endMinutes - slot.endTotalMinutes).abs();
        if (diff < bestEndDiff) {
          bestEndDiff = diff;
          endSec = slot.section;
        }
      }
    }

    if (endSec < startSec) {
      endSec = startSec;
    }
    return (
      startSec.clamp(1, AppConstants.sectionCount),
      endSec.clamp(startSec, AppConstants.sectionCount),
    );
  }

  /// 当前时刻所处节次编号（1-based），非上课时间返回 null
  int? currentSectionNumber([DateTime? now]) {
    final t = now ?? DateTime.now();
    final mins = t.hour * 60 + t.minute;
    for (final slot in slots) {
      if (mins >= slot.startTotalMinutes && mins <= slot.endTotalMinutes) {
        return slot.section;
      }
    }
    return null;
  }

  /// 当前时刻在纵向网格中的归一化位置 (0.0 ~ 1.0)
  double? currentTimelineFraction([DateTime? now]) {
    if (slots.isEmpty) return null;
    final t = now ?? DateTime.now();
    final mins = t.hour * 60 + t.minute;
    final firstStart = slots.first.startTotalMinutes;
    final lastEnd = slots.last.endTotalMinutes;
    if (mins < firstStart - 20 || mins > lastEnd + 15) {
      return null;
    }

    final total = slots.length;
    for (var i = 0; i < total; i++) {
      final slot = slots[i];
      if (mins <= slot.startTotalMinutes) {
        return (i / total).clamp(0.0, 1.0);
      }
      if (mins <= slot.endTotalMinutes) {
        final duration = (slot.endTotalMinutes - slot.startTotalMinutes).clamp(1, 300);
        final within = (mins - slot.startTotalMinutes) / duration;
        return ((i + within) / total).clamp(0.0, 1.0);
      }
      if (i + 1 < total && mins < slots[i + 1].startTotalMinutes) {
        return ((i + 1) / total).clamp(0.0, 1.0);
      }
    }
    return 1.0;
  }

  SectionTimeTable updateSlot(SectionTimeSlot updated) {
    final nextSlots = slots
        .map((s) => s.section == updated.section ? updated : s)
        .toList();
    return SectionTimeTable(
      presetId: 'custom',
      presetName: '自定义作息 (${nextSlots.length}节)',
      slots: nextSlots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'presetId': presetId,
      'presetName': presetName,
      'slots': slots.map((s) => s.toJson()).toList(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SectionTimeTable? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final rawSlots = map['slots'];
      if (rawSlots is! List || rawSlots.isEmpty) return null;
      final slots = rawSlots
          .whereType<Map>()
          .map((e) => SectionTimeSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.section.compareTo(b.section));
      if (slots.isEmpty) return null;
      return SectionTimeTable(
        presetId: (map['presetId'] ?? 'custom').toString(),
        presetName: (map['presetName'] ?? '自定义作息').toString(),
        slots: slots,
      );
    } catch (_) {
      return null;
    }
  }
}

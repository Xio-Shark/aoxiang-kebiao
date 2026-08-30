/// Course 领域实体。
///
/// 纯业务对象，不依赖 Flutter 或代码生成，保证导入、存储、展示链路稳定。
class Course {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String campus;
  final int weekday;
  final int startSection;
  final int sectionCount;
  final int startWeek;
  final int endWeek;
  final WeekPattern weekPattern;
  final List<int> customWeeks;
  final int color;
  final String note;

  const Course({
    required this.id,
    required this.name,
    this.teacher = '',
    this.classroom = '',
    this.campus = '',
    required this.weekday,
    required this.startSection,
    this.sectionCount = 2,
    required this.startWeek,
    required this.endWeek,
    this.weekPattern = WeekPattern.all,
    this.customWeeks = const [],
    this.color = 0xFF4F779A,
    this.note = '',
  });

  factory Course.create({
    required String id,
    required String name,
    String teacher = '',
    String classroom = '',
    String campus = '',
    required int weekday,
    required int startSection,
    int sectionCount = 2,
    required int startWeek,
    required int endWeek,
    WeekPattern weekPattern = WeekPattern.all,
    List<int> customWeeks = const [],
    int color = 0xFF4F779A,
    String note = '',
  }) {
    assert(weekday >= 1 && weekday <= 7, '星期必须在1-7之间');
    assert(startSection >= 1, '开始节次必须大于等于1');
    assert(sectionCount >= 1, '节次数必须大于等于1');
    assert(startWeek >= 1, '开始周必须大于等于1');
    assert(endWeek >= startWeek, '结束周必须大于等于开始周');

    return Course(
      id: id,
      name: name,
      teacher: teacher,
      classroom: classroom,
      campus: campus,
      weekday: weekday,
      startSection: startSection,
      sectionCount: sectionCount,
      startWeek: startWeek,
      endWeek: endWeek,
      weekPattern: weekPattern,
      customWeeks: List.unmodifiable(customWeeks),
      color: color,
      note: note,
    );
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    String? campus,
    int? weekday,
    int? startSection,
    int? sectionCount,
    int? startWeek,
    int? endWeek,
    WeekPattern? weekPattern,
    List<int>? customWeeks,
    int? color,
    String? note,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      campus: campus ?? this.campus,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      sectionCount: sectionCount ?? this.sectionCount,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      weekPattern: weekPattern ?? this.weekPattern,
      customWeeks: customWeeks ?? this.customWeeks,
      color: color ?? this.color,
      note: note ?? this.note,
    );
  }

  int get endSection => startSection + sectionCount - 1;

  bool isVisibleInWeek(int week) {
    if (week < startWeek || week > endWeek) {
      return false;
    }

    return switch (weekPattern) {
      WeekPattern.all => true,
      WeekPattern.odd => week.isOdd,
      WeekPattern.even => week.isEven,
      WeekPattern.custom => customWeeks.contains(week),
    };
  }

  List<int> get weeks {
    return switch (weekPattern) {
      WeekPattern.all => List.generate(
          endWeek - startWeek + 1,
          (index) => startWeek + index,
        ),
      WeekPattern.odd => [
          for (var week = startWeek; week <= endWeek; week++)
            if (week.isOdd) week,
        ],
      WeekPattern.even => [
          for (var week = startWeek; week <= endWeek; week++)
            if (week.isEven) week,
        ],
      WeekPattern.custom => customWeeks,
    };
  }

  String get weekDisplayText {
    final baseText = '$startWeek-$endWeek周';
    return switch (weekPattern) {
      WeekPattern.all => baseText,
      WeekPattern.odd => '$baseText(单)',
      WeekPattern.even => '$baseText(双)',
      WeekPattern.custom => customWeeks.map((week) => '$week周').join(', '),
    };
  }

  String get sectionDisplayText {
    if (sectionCount == 1) {
      return '第$startSection节';
    }
    return '$startSection-$endSection节';
  }

  String get timeRangeText => sectionDisplayText;

  bool canMergeWith(Course other) {
    return name == other.name &&
        classroom == other.classroom &&
        teacher == other.teacher &&
        weekday == other.weekday &&
        startWeek == other.startWeek &&
        endWeek == other.endWeek &&
        weekPattern == other.weekPattern &&
        campus == other.campus &&
        endSection + 1 == other.startSection;
  }

  Course mergeWith(Course other) {
    assert(canMergeWith(other), '课程不能合并');
    return copyWith(sectionCount: sectionCount + other.sectionCount);
  }

  bool hasTimeConflictWith(Course other) {
    if (weekday != other.weekday) {
      return false;
    }

    final weeksOverlap =
        weeks.toSet().intersection(other.weeks.toSet()).isNotEmpty;
    if (!weeksOverlap) {
      return false;
    }

    return startSection <= other.endSection && endSection >= other.startSection;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Course &&
            id == other.id &&
            name == other.name &&
            teacher == other.teacher &&
            classroom == other.classroom &&
            campus == other.campus &&
            weekday == other.weekday &&
            startSection == other.startSection &&
            sectionCount == other.sectionCount &&
            startWeek == other.startWeek &&
            endWeek == other.endWeek &&
            weekPattern == other.weekPattern &&
            color == other.color &&
            note == other.note &&
            _listEquals(customWeeks, other.customWeeks);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      teacher,
      classroom,
      campus,
      weekday,
      startSection,
      sectionCount,
      startWeek,
      endWeek,
      weekPattern,
      Object.hashAll(customWeeks),
      color,
      note,
    );
  }
}

enum WeekPattern {
  all,
  odd,
  even,
  custom,
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

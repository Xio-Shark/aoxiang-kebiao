/// Course 领域实体
/// 纯业务逻辑，不依赖任何外部框架
/// 
/// 设计原则：
/// - 不可变性：所有字段为final
/// - 完整性：包含课程的所有业务属性
/// - 验证：构造函数验证业务规则

import 'package:freezed_annotation/freezed_annotation.dart';

part 'course.freezed.dart';

/// 课程实体
/// 
/// 对应原有Android版本的Course.java
/// 字段映射：
/// - name -> name (课程名)
/// - room -> classroom (教室)
/// - teach -> teacher (教师)
/// - id -> id (课程编号)
/// - campus -> campus (校区)
/// - start -> startSection (开始节次)
/// - step -> sectionCount (节次数) 
/// - day -> weekday (星期)
/// - startWeek -> startWeek (开始周)
/// - endWeek -> endWeek (结束周)
/// - isOdd -> weekPattern (周次模式)
@freezed
class Course with _$Course {
  const Course._();
  
  const factory Course({
    /// 课程唯一ID
    required String id,
    
    /// 课程名称
    required String name,
    
    /// 教师姓名
    @Default('') String teacher,
    
    /// 上课教室
    @Default('') String classroom,
    
    /// 上课校区
    @Default('') String campus,
    
    /// 星期几 (1-7, 1=周一)
    required int weekday,
    
    /// 开始节次 (1-12)
    required int startSection,
    
    /// 节次数 (连续上几节课)
    @Default(2) int sectionCount,
    
    /// 开始周
    required int startWeek,
    
    /// 结束周
    required int endWeek,
    
    /// 周次模式
    /// - all: 全周
    /// - odd: 单周
    /// - even: 双周
    @Default(WeekPattern.all) WeekPattern weekPattern,
    
    /// 自定义周次列表（当weekPattern为custom时使用）
    @Default([]) List<int> customWeeks,
    
    /// 课程颜色（ARGB格式）
    @Default(0xFFE57373) int color,
    
    /// 备注
    @Default('') String note,
  }) = _Course;
  
  /// 验证构造函数
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
    int color = 0xFFE57373,
    String note = '',
  }) {
    // 验证业务规则
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
      customWeeks: customWeeks,
      color: color,
      note: note,
    );
  }
  
  /// 结束节次
  int get endSection => startSection + sectionCount - 1;
  
  /// 是否在指定周显示
  bool isVisibleInWeek(int week) {
    // 检查是否在周次范围内
    if (week < startWeek || week > endWeek) {
      return false;
    }
    
    // 检查周次模式
    switch (weekPattern) {
      case WeekPattern.all:
        return true;
      case WeekPattern.odd:
        return week.isOdd;
      case WeekPattern.even:
        return week.isEven;
      case WeekPattern.custom:
        return customWeeks.contains(week);
    }
  }
  
  /// 获取完整周次列表
  List<int> get weeks {
    switch (weekPattern) {
      case WeekPattern.all:
        return List.generate(endWeek - startWeek + 1, (i) => startWeek + i);
      case WeekPattern.odd:
        return [
          for (var w = startWeek; w <= endWeek; w++)
            if (w.isOdd) w
        ];
      case WeekPattern.even:
        return [
          for (var w = startWeek; w <= endWeek; w++)
            if (w.isEven) w
        ];
      case WeekPattern.custom:
        return customWeeks;
    }
  }
  
  /// 周次显示文本
  String get weekDisplayText {
    final baseText = '$startWeek-$endWeek周';
    switch (weekPattern) {
      case WeekPattern.all:
        return baseText;
      case WeekPattern.odd:
        return '$baseText(单)';
      case WeekPattern.even:
        return '$baseText(双)';
      case WeekPattern.custom:
        return customWeeks.map((w) => '${w}周').join(', ');
    }
  }
  
  /// 节次显示文本
  String get sectionDisplayText {
    if (sectionCount == 1) {
      return '第$startSection节';
    }
    return '$startSection-${endSection}节';
  }
  
  /// 时间范围显示文本
  String get timeRangeText => sectionDisplayText;
  
  /// 是否可以与另一课程合并
  /// 用于相邻节次的同名同教室课程合并
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
  
  /// 合并课程（增加节次）
  Course mergeWith(Course other) {
    assert(canMergeWith(other), '课程不能合并');
    return copyWith(
      sectionCount: sectionCount + other.sectionCount,
    );
  }
  
  /// 检查时间冲突
  bool hasTimeConflictWith(Course other) {
    if (weekday != other.weekday) return false;
    
    // 检查是否有重叠周次
    final weeksOverlap = weeks.toSet().intersection(other.weeks.toSet()).isNotEmpty;
    if (!weeksOverlap) return false;
    
    // 检查节次是否重叠
    final thisRange = (startSection, endSection);
    final otherRange = (other.startSection, other.endSection);
    
    return thisRange.$1 <= otherRange.$2 && thisRange.$2 >= otherRange.$1;
  }
}

/// 周次模式枚举
enum WeekPattern {
  all,
  odd,
  even,
  custom,
}

/// 扩展：判断奇偶
extension IntExtension on int {
  bool get isOdd => this % 2 == 1;
  bool get isEven => this % 2 == 0;
}

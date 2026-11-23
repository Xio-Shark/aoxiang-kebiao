import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
import '../../domain/entities/section_time.dart';
import 'course_card.dart';
import 'course_overlap_resolver.dart';
import 'schedule_grid_metrics.dart';

class WeekdayHeader extends StatelessWidget {
  final int? highlightedWeekday;
  final List<DateTime> weekDates;
  final String monthText;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const WeekdayHeader({
    super.key,
    required this.highlightedWeekday,
    required this.weekDates,
    required this.monthText,
    required this.onSwipePrevious,
    required this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onHorizontalDragEnd: _handleDragEnd,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Container(
              width: ScheduleGridMetrics.timeColumnWidth,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.56 : 0.72,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
                  width: 0.8,
                ),
              ),
              child: Text(
                monthText,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  height: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            ...List.generate(7, (index) {
              final weekday = index + 1;
              final date = index < weekDates.length ? weekDates[index] : null;
              final isToday = date != null &&
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return _WeekdayCell(
                label: weekdayLabels[index],
                date: date,
                isToday: isToday,
                isHighlighted: isToday || weekday == highlightedWeekday,
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity <= -80) {
      onSwipeNext();
      return;
    }
    if (velocity >= 80) {
      onSwipePrevious();
    }
  }
}

class _WeekdayCell extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isToday;
  final bool isHighlighted;

  const _WeekdayCell({
    required this.label,
    required this.date,
    required this.isToday,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dayStr = date != null ? '${date!.day}' : '';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScheduleGridMetrics.dayGap,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            gradient: isToday
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      Color.lerp(
                        theme.colorScheme.primary,
                        theme.colorScheme.tertiary,
                        0.32,
                      )!,
                    ],
                  )
                : null,
            color: isToday
                ? null
                : (isHighlighted
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surface.withValues(
                        alpha: isDark ? 0.45 : 0.65,
                      )),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday
                  ? theme.colorScheme.primary.withValues(alpha: 0.9)
                  : (isHighlighted
                      ? theme.colorScheme.primary.withValues(alpha: 0.38)
                      : theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.35)),
              width: isToday ? 1.2 : 0.8,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.34),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '周$label',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.9)
                      : (isHighlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant),
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 9.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3.5),
              Text(
                dayStr.isNotEmpty ? dayStr : '--',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday
                      ? theme.colorScheme.onPrimary
                      : (isHighlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface),
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 12.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimeColumn extends StatelessWidget {
  const TimeColumn({
    super.key,
    required this.timeTable,
    this.activeSection,
  });

  final SectionTimeTable timeTable;
  final int? activeSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = timeTable.sectionCount;

    return SizedBox(
      width: ScheduleGridMetrics.timeColumnWidth,
      child: Column(
        children: List.generate(total, (index) {
          final slot = timeTable.slots[index];
          final section = slot.section;
          final isActive = activeSection == section;

          return Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 0.55 : 0.62),
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.38),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '$section',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isActive
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.8,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      slot.startText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.85),
                        fontSize: 8.0,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      slot.endText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.52),
                        fontSize: 7.6,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class DayColumn extends StatelessWidget {
  final int weekday;
  final SectionTimeTable timeTable;
  final bool isHighlighted;
  final bool isToday;
  final List<Course> courses;
  final int? activeSection;
  final double? currentTimeFraction;
  final ValueChanged<Course> onCourseTap;

  const DayColumn({
    super.key,
    required this.weekday,
    required this.timeTable,
    required this.isHighlighted,
    this.isToday = false,
    required this.courses,
    this.activeSection,
    this.currentTimeFraction,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSections = timeTable.sectionCount;
    final backgroundColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
        : (isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : theme.colorScheme.surface.withValues(
                alpha: isDark ? 0.30 : 0.42,
              ));

    final borderColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.48)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.32);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ScheduleGridMetrics.dayGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: borderColor,
            width: isToday ? 1.05 : 0.7,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotHeight = constraints.maxHeight / totalSections;
            final conflictMap = CourseOverlapResolver.resolveConflicts(courses);
            final colWidth = constraints.maxWidth;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                _SectionDividers(timeTable: timeTable),
                ...courses.asMap().entries.map((entry) {
                  final idxInDay = entry.key;
                  final course = entry.value;
                  final overlapping = conflictMap[course.id] ?? [course];
                  final conflictCount = overlapping.length;

                  final clampedStart =
                      course.startSection.clamp(1, totalSections);
                  final clampedCount = course.sectionCount
                      .clamp(1, totalSections - clampedStart + 1);
                  final top = (clampedStart - 1) * slotHeight + 1.8;
                  final height = (clampedCount * slotHeight - 3.6)
                      .clamp(
                        ScheduleGridMetrics.minCourseHeight,
                        constraints.maxHeight,
                      )
                      .toDouble();

                  final isOngoing = isToday &&
                      activeSection != null &&
                      activeSection! >= course.startSection &&
                      activeSection! <= course.endSection;

                  double left = 2.0;
                  double right = 2.0;
                  if (conflictCount > 1) {
                    final sorted = [...overlapping]
                      ..sort((a, b) => a.id.compareTo(b.id));
                    final idx = sorted.indexWhere((c) => c.id == course.id);
                    final subWidth = (colWidth - 4) / conflictCount;
                    left = 2.0 + idx * subWidth;
                    right = colWidth - (left + subWidth);
                    if (right < 0) right = 0;
                  }

                  return Positioned(
                    top: top,
                    left: left,
                    right: right,
                    height: height,
                    child: CourseCard(
                      course: course,
                      height: height,
                      conflictCount: conflictCount,
                      isOngoing: isOngoing,
                      staggerIndex: (weekday - 1) + idxInDay,
                      onTap: () => onCourseTap(course),
                    ),
                  );
                }),
                // 今日实时时间指示线
                if (isToday && currentTimeFraction != null)
                  Positioned(
                    top: (currentTimeFraction! * constraints.maxHeight)
                        .clamp(2.0, constraints.maxHeight - 4.0),
                    left: -2,
                    right: -1,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.55),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1.8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary
                                        .withValues(alpha: 0.25),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionDividers extends StatelessWidget {
  const _SectionDividers({required this.timeTable});

  final SectionTimeTable timeTable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = timeTable.sectionCount;

    return Column(
      children: List.generate(total, (index) {
        final section = timeTable.slots[index].section;
        final isPeriodBreak = timeTable.isPeriodBreakAfter(section);
        final isLast = index == total - 1;

        return Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: isPeriodBreak
                            ? theme.colorScheme.primary.withValues(alpha: 0.24)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.22),
                        width: isPeriodBreak ? 1.0 : 0.5,
                      ),
                    ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
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

    return GestureDetector(
      onHorizontalDragEnd: _handleDragEnd,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // 左上角月份框（对齐下方时间轴）
            Container(
              width: ScheduleGridMetrics.timeColumnWidth,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                monthText,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  height: 1.1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 7 天星期与具体日期列
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
    final dayStr = date != null ? '${date!.day}' : '';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScheduleGridMetrics.dayGap,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: isToday
                ? theme.colorScheme.primary
                : (isHighlighted
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surface.withValues(alpha: 0.52)),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isToday
                  ? theme.colorScheme.primary
                  : (isHighlighted
                      ? theme.colorScheme.primary.withValues(alpha: 0.38)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
              width: isToday ? 1.2 : 0.8,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.32),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
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
                      ? theme.colorScheme.onPrimary
                      : (isHighlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant),
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dayStr.isNotEmpty ? dayStr : '--',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday
                      ? theme.colorScheme.onPrimary
                      : (isHighlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface),
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 12,
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
  const TimeColumn({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: ScheduleGridMetrics.timeColumnWidth,
      child: Column(
        children: List.generate(ScheduleGridMetrics.sectionCount, (index) {
          final section = index + 1;
          final time = index < ScheduleGridMetrics.sectionTimes.length
              ? ScheduleGridMetrics.sectionTimes[index]
              : null;

          return Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$section',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        height: 1,
                      ),
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      time['start']!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      time['end']!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                        fontSize: 8,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class DayColumn extends StatelessWidget {
  final bool isHighlighted;
  final bool isToday;
  final List<Course> courses;
  final ValueChanged<Course> onCourseTap;

  const DayColumn({
    super.key,
    required this.isHighlighted,
    this.isToday = false,
    required this.courses,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : (isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : theme.colorScheme.surface.withValues(alpha: 0.32));

    final borderColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ScheduleGridMetrics.dayGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isToday ? 1.0 : 0.7,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotHeight =
                constraints.maxHeight / ScheduleGridMetrics.sectionCount;
            final conflictMap = CourseOverlapResolver.resolveConflicts(courses);
            final colWidth = constraints.maxWidth;

            return Stack(
              children: [
                const _SectionDividers(),
                ...courses.map((course) {
                  final overlapping = conflictMap[course.id] ?? [course];
                  final conflictCount = overlapping.length;
                  
                  final top = (course.startSection - 1) * slotHeight + 2;
                  final height = (course.sectionCount * slotHeight - 4)
                      .clamp(
                        ScheduleGridMetrics.minCourseHeight,
                        constraints.maxHeight,
                      )
                      .toDouble();

                  // 多课程重叠并排显示计算（避免完全堆叠盖死）
                  double left = 2.0;
                  double right = 2.0;
                  if (conflictCount > 1) {
                    final sorted = [...overlapping]..sort((a, b) => a.id.compareTo(b.id));
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
                      onTap: () => onCourseTap(course),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionDividers extends StatelessWidget {
  const _SectionDividers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: List.generate(ScheduleGridMetrics.sectionCount, (index) {
        return Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                  width: 0.5,
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

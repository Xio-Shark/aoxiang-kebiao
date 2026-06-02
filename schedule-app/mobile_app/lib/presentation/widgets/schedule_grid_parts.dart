import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
import 'course_card.dart';
import 'schedule_grid_metrics.dart';

class WeekdayHeader extends StatelessWidget {
  final int? highlightedWeekday;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const WeekdayHeader({
    super.key,
    required this.highlightedWeekday,
    required this.onSwipePrevious,
    required this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return GestureDetector(
      onHorizontalDragEnd: _handleDragEnd,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            const SizedBox(width: ScheduleGridMetrics.timeColumnWidth + 4),
            ...List.generate(weekdays.length, (index) {
              final weekday = index + 1;
              return _WeekdayCell(
                label: weekdays[index],
                isHighlighted: weekday == highlightedWeekday,
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
          return Expanded(
            child: Center(
              child: Text(
                '$section',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
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
  final bool isHighlighted;
  final List<Course> courses;
  final ValueChanged<Course> onCourseTap;

  const DayColumn({
    super.key,
    required this.isHighlighted,
    required this.courses,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isHighlighted
        ? theme.colorScheme.primary.withValues(alpha: 0.07)
        : theme.colorScheme.surface.withValues(alpha: 0.36);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ScheduleGridMetrics.dayGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotHeight =
                constraints.maxHeight / ScheduleGridMetrics.sectionCount;

            return Stack(
              children: [
                const _SectionDividers(),
                ...courses.map((course) {
                  final top = (course.startSection - 1) * slotHeight + 2;
                  final height = (course.sectionCount * slotHeight - 4)
                      .clamp(
                        ScheduleGridMetrics.minCourseHeight,
                        constraints.maxHeight,
                      )
                      .toDouble();

                  return Positioned(
                    top: top,
                    left: 3,
                    right: 3,
                    height: height,
                    child: CourseCard(
                      course: course,
                      height: height,
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

class _WeekdayCell extends StatelessWidget {
  final String label;
  final bool isHighlighted;

  const _WeekdayCell({
    required this.label,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScheduleGridMetrics.dayGap,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isHighlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor(theme)),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isHighlighted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _borderColor(ThemeData theme) {
    if (isHighlighted) {
      return theme.colorScheme.primary.withValues(alpha: 0.28);
    }
    return theme.colorScheme.outlineVariant.withValues(alpha: 0.42);
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
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
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

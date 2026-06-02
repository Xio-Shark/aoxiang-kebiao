import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
import 'course_detail_sheet.dart';
import 'schedule_grid_metrics.dart';
import 'schedule_grid_parts.dart';

class ScheduleGrid extends StatelessWidget {
  final List<Course> courses;
  final int? highlightedWeekday;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.highlightedWeekday,
    required this.onSwipePrevious,
    required this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    final groupedCourses = _groupCoursesByWeekday(courses);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleDragEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ScheduleGridMetrics.horizontalPadding,
          4,
          ScheduleGridMetrics.horizontalPadding,
          10,
        ),
        child: Column(
          children: [
            WeekdayHeader(
              highlightedWeekday: highlightedWeekday,
              onSwipePrevious: onSwipePrevious,
              onSwipeNext: onSwipeNext,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  const TimeColumn(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Row(
                      children: List.generate(7, (index) {
                        final weekday = index + 1;
                        return Expanded(
                          child: DayColumn(
                            isHighlighted: weekday == highlightedWeekday,
                            courses: groupedCourses[weekday] ?? const [],
                            onCourseTap: (course) {
                              _showCourseDetail(context, course);
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
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

  void _showCourseDetail(BuildContext context, Course course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (context) => CourseDetailSheet(course: course),
    );
  }
}

Map<int, List<Course>> _groupCoursesByWeekday(List<Course> courses) {
  final grouped = <int, List<Course>>{};
  for (final course in courses) {
    grouped.putIfAbsent(course.weekday, () => []).add(course);
  }

  for (final dayCourses in grouped.values) {
    dayCourses.sort((a, b) => a.startSection.compareTo(b.startSection));
  }
  return grouped;
}

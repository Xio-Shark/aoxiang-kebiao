import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
import 'course_detail_sheet.dart';
import 'schedule_grid_metrics.dart';
import 'schedule_grid_parts.dart';

class ScheduleGrid extends StatelessWidget {
  final int week;
  final List<DateTime> weekDates;
  final String monthText;
  final List<Course> courses;
  final int? highlightedWeekday;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const ScheduleGrid({
    super.key,
    required this.week,
    required this.weekDates,
    required this.monthText,
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
          2,
          ScheduleGridMetrics.horizontalPadding,
          8,
        ),
        child: Column(
          children: [
            WeekdayHeader(
              highlightedWeekday: highlightedWeekday,
              weekDates: weekDates,
              monthText: monthText,
              onSwipePrevious: onSwipePrevious,
              onSwipeNext: onSwipeNext,
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Row(
                children: [
                  const TimeColumn(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Row(
                      children: List.generate(7, (index) {
                        final weekday = index + 1;
                        final isToday = weekday == highlightedWeekday;
                        return Expanded(
                          child: DayColumn(
                            isHighlighted: isToday,
                            isToday: isToday,
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
    final dayCourses = courses.where((c) => c.weekday == course.weekday).toList();
    final overlapping = dayCourses.where((other) {
      final start = course.startSection > other.startSection ? course.startSection : other.startSection;
      final end = course.endSection < other.endSection ? course.endSection : other.endSection;
      return start <= end;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (context) => CourseDetailSheet(
        course: course,
        overlappingCourses: overlapping,
      ),
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

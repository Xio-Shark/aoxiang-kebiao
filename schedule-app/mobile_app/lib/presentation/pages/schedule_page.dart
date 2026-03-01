/// 课程表页面 - 主页面
/// 展示一周7天的课程

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';
import '../widgets/course_card.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWeek = ref.watch(selectedWeekProvider);
    final scheduleAsync = ref.watch(scheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程表'),
        actions: [
          // 周次选择器
          _WeekSelector(
            selectedWeek: selectedWeek,
            onChanged: (week) {
              ref.read(selectedWeekProvider.notifier).state = week;
            },
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: scheduleAsync.when(
        data: (courses) => _ScheduleGrid(
          courses: courses.cast<Course>(),
          currentWeek: selectedWeek,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('加载失败: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/import');
        },
        icon: const Icon(Icons.add),
        label: const Text('导入课程'),
      ),
    );
  }
}

/// 周次选择器
class _WeekSelector extends StatelessWidget {
  final int selectedWeek;
  final ValueChanged<int> onChanged;

  const _WeekSelector({
    required this.selectedWeek,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: selectedWeek,
      onSelected: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('第$selectedWeek周'),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (context) {
        return List.generate(25, (index) {
          final week = index + 1;
          return PopupMenuItem(
            value: week,
            child: Text('第$week周'),
          );
        });
      },
    );
  }
}

/// 课程表网格
class _ScheduleGrid extends StatelessWidget {
  final List<Course> courses;
  final int currentWeek;

  const _ScheduleGrid({
    required this.courses,
    required this.currentWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 星期头部
        _WeekdayHeader(),
        // 课程表主体
        Expanded(
          child: Row(
            children: [
              // 时间列
              _TimeColumn(),
              // 星期列
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final weekday = index + 1;
                    final dayCourses = courses
                        .where((c) => c.weekday == weekday)
                        .toList();
                    return _DayColumn(
                      weekday: weekday,
                      courses: dayCourses,
                      onCourseTap: (course) {
                        _showCourseDetail(context, course);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCourseDetail(BuildContext context, Course course) {
    showModalBottomSheet(
      context: context,
      builder: (context) => CourseDetailSheet(course: course),
    );
  }
}

/// 星期头部
class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // 时间列占位
          const SizedBox(width: 50),
          // 星期
          ...weekdays.map((day) => Expanded(
            child: Center(
              child: Text(
                day,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          )),
        ],
      ),
    );
  }
}

/// 时间列
class _TimeColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      child: Column(
        children: List.generate(12, (index) {
          final section = index + 1;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  '$section',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 单日列
class _DayColumn extends StatelessWidget {
  final int weekday;
  final List<Course> courses;
  final Function(Course) onCourseTap;

  const _DayColumn({
    required this.weekday,
    required this.courses,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          // 背景网格
          Column(
            children: List.generate(12, (index) {
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                      right: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // 课程卡片
          ...courses.map((course) {
            return Positioned(
              top: (course.startSection - 1) * 60.0,
              left: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onCourseTap(course),
                child: CourseCard(course: course),
              ),
            );
          }),
        ],
      ),
    );
  }
}

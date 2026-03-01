/// 课程表页面 - 主页面
/// 展示一周 7 天课程

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';
import '../widgets/course_card.dart';
import 'settings_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  static const double _appBarHeight = 46;
  static const int _minWeek = 1;
  static const int _maxWeek = 25;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  bool _isForward = true;

  void _changeWeek(int targetWeek) {
    final currentWeek = ref.read(selectedWeekProvider);
    final nextWeek =
        targetWeek.clamp(SchedulePage._minWeek, SchedulePage._maxWeek);

    if (nextWeek == currentWeek) {
      return;
    }

    setState(() {
      _isForward = nextWeek > currentWeek;
    });
    ref.read(selectedWeekProvider.notifier).state = nextWeek;
    ref.invalidate(scheduleProvider);
  }

  SystemUiOverlayStyle _buildOverlayStyle(Color appBarColor) {
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarColor) == Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDarkBackground ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDarkBackground ? Brightness.dark : Brightness.light,
    );
  }

  int? _resolveHighlightedWeekday(AsyncValue<int> currentWeekAsync, int week) {
    return currentWeekAsync.maybeWhen(
      data: (currentWeek) =>
          currentWeek == week ? DateTime.now().weekday : null,
      orElse: () => null,
    );
  }

  Widget _buildAnimatedGrid({
    required int selectedWeek,
    required List<Course> courses,
    required int? highlightedWeekday,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideTween = Tween<Offset>(
          begin: Offset(_isForward ? 0.16 : -0.16, 0),
          end: Offset.zero,
        );

        return ClipRect(
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
      child: _ScheduleGrid(
        key: ValueKey<int>(selectedWeek),
        courses: courses,
        highlightedWeekday: highlightedWeekday,
        onSwipePrevious: () => _changeWeek(selectedWeek - 1),
        onSwipeNext: () => _changeWeek(selectedWeek + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedWeek = ref.watch(selectedWeekProvider);
    final scheduleAsync = ref.watch(scheduleProvider);
    final backgroundImagePath = ref.watch(backgroundImagePathProvider);
    final backgroundTransform = ref.watch(backgroundTransformProvider);
    final currentWeekAsync = ref.watch(currentWeekProvider);
    final highlightedWeekday =
        _resolveHighlightedWeekday(currentWeekAsync, selectedWeek);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: SchedulePage._appBarHeight,
        systemOverlayStyle: _buildOverlayStyle(Colors.transparent),
        title: const Text('课程表'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(selectedWeek - 1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(selectedWeek + 1),
          ),
          _WeekSelector(
            selectedWeek: selectedWeek,
            onChanged: _changeWeek,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ScheduleBackground(
            imagePath: backgroundImagePath,
            transform: backgroundTransform,
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top +
                  SchedulePage._appBarHeight,
            ),
            child: scheduleAsync.when(
              data: (courses) => _buildAnimatedGrid(
                selectedWeek: selectedWeek,
                courses: courses,
                highlightedWeekday: highlightedWeekday,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('加载失败: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景层
class _ScheduleBackground extends StatelessWidget {
  final String? imagePath;
  final BackgroundTransformState transform;

  const _ScheduleBackground({
    required this.imagePath,
    required this.transform,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;
    if (!hasImage) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dx = transform.offsetX * width * 0.5;
        final dy = transform.offsetY * height * 0.5;

        return ClipRect(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: transform.scale,
              child: Image.file(
                File(imagePath!),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
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
        return List.generate(SchedulePage._maxWeek, (index) {
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
  final int? highlightedWeekday;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const _ScheduleGrid({
    super.key,
    required this.courses,
    required this.highlightedWeekday,
    required this.onSwipePrevious,
    required this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -80) {
          onSwipeNext();
          return;
        }
        if (velocity >= 80) {
          onSwipePrevious();
        }
      },
      child: Column(
        children: [
          _WeekdayHeader(
            highlightedWeekday: highlightedWeekday,
            onSwipePrevious: onSwipePrevious,
            onSwipeNext: onSwipeNext,
          ),
          Expanded(
            child: Row(
              children: [
                _TimeColumn(),
                Expanded(
                  child: Row(
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      final dayCourses =
                          courses.where((c) => c.weekday == weekday).toList();

                      return Expanded(
                        child: _DayColumn(
                          isHighlighted: weekday == highlightedWeekday,
                          courses: dayCourses,
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
  final int? highlightedWeekday;
  final VoidCallback onSwipePrevious;
  final VoidCallback onSwipeNext;

  const _WeekdayHeader({
    required this.highlightedWeekday,
    required this.onSwipePrevious,
    required this.onSwipeNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -80) {
          onSwipeNext();
          return;
        }
        if (velocity >= 80) {
          onSwipePrevious();
        }
      },
      child: Container(
        height: 40,
        color: Colors.transparent,
        child: Row(
          children: [
            const SizedBox(width: 42),
            ...List.generate(weekdays.length, (index) {
              final weekday = index + 1;
              final isHighlighted = weekday == highlightedWeekday;

              return Expanded(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? primaryColor.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      weekdays[index],
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isHighlighted ? primaryColor : null,
                        fontWeight:
                            isHighlighted ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 时间列
class _TimeColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        children: List.generate(12, (index) {
          final section = index + 1;
          return Expanded(
            child: Container(
              color: Colors.transparent,
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
  final bool isHighlighted;
  final List<Course> courses;
  final Function(Course) onCourseTap;

  const _DayColumn({
    required this.isHighlighted,
    required this.courses,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor =
        theme.colorScheme.primary.withValues(alpha: isHighlighted ? 0.08 : 0);

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Column(
            children: List.generate(12, (index) {
              return Expanded(
                child: ColoredBox(
                  color: highlightColor,
                ),
              );
            }),
          ),
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

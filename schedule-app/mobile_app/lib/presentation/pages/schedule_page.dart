/// 课程表页面 - 主页面

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';
import '../widgets/schedule_background.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_message.dart';
import '../widgets/week_selector.dart';
import 'jiaowu_web_import_page.dart';
import 'settings_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  static const double appBarHeight = 50;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialWeek = ref.read(selectedWeekProvider);
    _pageController = PageController(initialPage: initialWeek - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeWeek(int targetWeek, {bool animate = true}) {
    final clamped = targetWeek.clamp(
      WeekSelector.minWeek,
      WeekSelector.maxWeek,
    ).toInt();

    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
          clamped - 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(clamped - 1);
      }
    }
    ref.read(selectedWeekProvider.notifier).state = clamped;
  }

  int? _resolveHighlightedWeekday(AsyncValue<int> currentWeekAsync, int week) {
    return currentWeekAsync.maybeWhen(
      data: (currentWeek) =>
          currentWeek == week ? DateTime.now().weekday : null,
      orElse: () => null,
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
    final statusBrightness = Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBrightness,
        statusBarBrightness: statusBrightness,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: _ScheduleAppBar(
          selectedWeek: selectedWeek,
          onWeekChanged: _changeWeek,
          onPrevious: selectedWeek == WeekSelector.minWeek
              ? null
              : () => _changeWeek(selectedWeek - 1),
          onNext: selectedWeek == WeekSelector.maxWeek
              ? null
              : () => _changeWeek(selectedWeek + 1),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            ScheduleBackground(
              imagePath: backgroundImagePath,
              transform: backgroundTransform,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top +
                    SchedulePage.appBarHeight,
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: WeekSelector.maxWeek,
                onPageChanged: (pageIndex) {
                  final targetWeek = pageIndex + 1;
                  if (ref.read(selectedWeekProvider) != targetWeek) {
                    ref.read(selectedWeekProvider.notifier).state = targetWeek;
                  }
                },
                itemBuilder: (context, index) {
                  final week = index + 1;
                  final weekCoursesAsync = ref.watch(weekScheduleProvider(week));
                  final weekHighlighted =
                      _resolveHighlightedWeekday(currentWeekAsync, week);

                  return weekCoursesAsync.when(
                    data: (courses) => ScheduleGrid(
                      key: ValueKey<int>(week),
                      courses: courses,
                      highlightedWeekday: weekHighlighted,
                      onSwipePrevious: () => _changeWeek(week - 1),
                      onSwipeNext: () => _changeWeek(week + 1),
                    ),
                    loading: () => const ScheduleMessage(
                      icon: Icons.hourglass_empty_rounded,
                      title: '正在整理课表',
                      message: '课程数据加载中',
                    ),
                    error: (error, stack) => ScheduleMessage(
                      icon: Icons.error_outline_rounded,
                      title: '课表加载失败',
                      message: error.toString(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedWeek;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ScheduleAppBar({
    required this.selectedWeek,
    required this.onWeekChanged,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Size get preferredSize => const Size.fromHeight(SchedulePage.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: SchedulePage.appBarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleSpacing: 14,
      title: Text(
        '翱翔课表',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      actions: [
        _ToolbarIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
          tooltip: '上一周',
        ),
        _ToolbarIconButton(
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
          tooltip: '下一周',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: WeekSelector(
            selectedWeek: selectedWeek,
            onChanged: onWeekChanged,
          ),
        ),
        _ToolbarIconButton(
          icon: Icons.language_rounded,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JiaowuWebImportPage(),
              ),
            );
          },
          tooltip: '教务导入',
        ),
        _ToolbarIconButton(
          icon: Icons.tune_rounded,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsPage(),
              ),
            );
          },
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
          disabledBackgroundColor:
              theme.colorScheme.surface.withValues(alpha: 0.34),
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

/// 课程表页面 - 主页面

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';
import '../widgets/add_course_dialog.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/schedule_background.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/schedule_message.dart';
import '../widgets/week_selector.dart';
import 'import_page.dart';
import 'jiaowu_web_import_page.dart';
import 'settings_page.dart';

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  static const double appBarHeight = 56;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialWeek = ref.read(currentWeekProvider);
    _pageController = PageController(initialPage: initialWeek - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedWeekProvider.notifier).state = initialWeek;
        // 启动时静默同步未来 14 天系统级课前提醒排程
        syncCourseReminders(ref);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeWeek(int targetWeek, {bool animate = true}) {
    final clamped = targetWeek
        .clamp(
          WeekSelector.minWeek,
          WeekSelector.maxWeek,
        )
        .toInt();

    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? (clamped - 1);
      if (currentPage != clamped - 1) {
        if (animate) {
          _pageController.animateToPage(
            clamped - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.jumpToPage(clamped - 1);
        }
      }
    }
    ref.read(selectedWeekProvider.notifier).state = clamped;
  }

  Future<void> _openImportCenter() async {
    await Navigator.of(context).push(
      SmoothPageRoute<void>(builder: (_) => const ImportPage()),
    );
    if (!mounted) return;
    _syncPageControllerWithSelectedWeek();
  }

  Future<void> _openJiaowuWebImport() async {
    await Navigator.of(context).push(
      SmoothPageRoute<void>(builder: (_) => const JiaowuWebImportPage()),
    );
    if (!mounted) return;
    _syncPageControllerWithSelectedWeek();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      SmoothPageRoute<void>(builder: (_) => const SettingsPage()),
    );
    if (!mounted) return;
    _syncPageControllerWithSelectedWeek();
  }

  void _syncPageControllerWithSelectedWeek() {
    final selected = ref.read(selectedWeekProvider);
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round();
      if (currentPage != null && currentPage != selected - 1) {
        _pageController.animateToPage(
          selected - 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = ref.watch(currentWeekProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final isCurrentWeek = selectedWeek == currentWeek;
    final backgroundImagePath = ref.watch(backgroundImagePathProvider);
    final backgroundTransform = ref.watch(backgroundTransformProvider);
    final backgroundOpacity = ref.watch(backgroundOpacityProvider);
    final timeTable = ref.watch(sectionTimeTableProvider);
    final allCoursesAsync = ref.watch(allCoursesProvider);
    final allCourses = allCoursesAsync.valueOrNull ?? const <Course>[];
    final isTotallyEmpty =
        allCoursesAsync.hasValue && allCourses.isEmpty;

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
          currentWeek: currentWeek,
          selectedWeek: selectedWeek,
          allCourses: allCourses,
          onWeekChanged: _changeWeek,
          onBackToCurrentWeek: () => _changeWeek(currentWeek),
          onAddCourse: () => AddCourseDialog.show(context),
          onOpenImportCenter: _openImportCenter,
          onOpenSettings: _openSettings,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            ScheduleBackground(
              imagePath: backgroundImagePath,
              transform: backgroundTransform,
              overlayOpacity: backgroundOpacity,
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
                    HapticFeedback.selectionClick();
                    ref.read(selectedWeekProvider.notifier).state = targetWeek;
                  }
                },
                itemBuilder: (context, index) {
                  final week = index + 1;
                  final weekCoursesAsync =
                      ref.watch(weekScheduleProvider(week));
                  final weekDates = ref.watch(weekDatesProvider(week));
                  final monthText = ref.watch(weekMonthDisplayProvider(week));
                  final weekHighlighted =
                      week == currentWeek ? DateTime.now().weekday : null;

                  return weekCoursesAsync.when(
                    data: (courses) => ScheduleGrid(
                      key: ValueKey<int>(week),
                      week: week,
                      weekDates: weekDates,
                      monthText: monthText,
                      courses: courses,
                      timeTable: timeTable,
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
            // 全学期空课表时的精美快速导入引导浮卡
            if (isTotallyEmpty)
              Positioned.fill(
                top: MediaQuery.of(context).padding.top +
                    SchedulePage.appBarHeight +
                    52,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FadeSlideEntrance(
                      duration: const Duration(milliseconds: 360),
                      offsetY: 16,
                      child: _EmptyScheduleGuideCard(
                        onWebImport: _openJiaowuWebImport,
                        onFileImport: _openImportCenter,
                        onAddCourse: () => AddCourseDialog.show(context),
                      ),
                    ),
                  ),
                ),
              ),
            // 平滑弹入滑出的「回到本周」悬浮胶囊
            Positioned(
              right: 16,
              bottom: 18 + MediaQuery.of(context).padding.bottom,
              child: IgnorePointer(
                ignoring: isCurrentWeek,
                child: AnimatedSlide(
                  offset: isCurrentWeek ? const Offset(0, 0.7) : Offset.zero,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: isCurrentWeek ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedScale(
                      scale: isCurrentWeek ? 0.85 : 1,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: BouncyTap(
                        onTap: () => _changeWeek(currentWeek),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Color.lerp(
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.tertiary,
                                  0.3,
                                )!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.36),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.today_rounded,
                                size: 17,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '回到本周 (第$currentWeek周)',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentWeek;
  final int selectedWeek;
  final List<Course> allCourses;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onBackToCurrentWeek;
  final VoidCallback onAddCourse;
  final VoidCallback onOpenImportCenter;
  final VoidCallback onOpenSettings;

  const _ScheduleAppBar({
    required this.currentWeek,
    required this.selectedWeek,
    required this.allCourses,
    required this.onWeekChanged,
    required this.onBackToCurrentWeek,
    required this.onAddCourse,
    required this.onOpenImportCenter,
    required this.onOpenSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(SchedulePage.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentWeek = selectedWeek == currentWeek;

    return AppBar(
      toolbarHeight: SchedulePage.appBarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleSpacing: 10,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WeekSelector(
            selectedWeek: selectedWeek,
            currentWeek: currentWeek,
            allCourses: allCourses,
            onChanged: onWeekChanged,
          ),
          const SizedBox(width: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: isCurrentWeek
                ? Container(
                    key: const ValueKey<String>('badge-this-week'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '本周',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : BouncyTap(
                    key: const ValueKey<String>('badge-back-week'),
                    onTap: onBackToCurrentWeek,
                    scaleDown: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.today_rounded,
                            size: 12,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '回本周',
                            style: TextStyle(
                              color: theme.colorScheme.tertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      actions: [
        _ToolbarIconButton(
          icon: Icons.file_download_outlined,
          onPressed: onOpenImportCenter,
          tooltip: '导入课表（官网/PDF/Word/CSV）',
          emphasized: true,
        ),
        _ToolbarIconButton(
          icon: Icons.add_rounded,
          onPressed: onAddCourse,
          tooltip: '手动添加课程',
        ),
        _ToolbarIconButton(
          icon: Icons.tune_rounded,
          onPressed: onOpenSettings,
          tooltip: '设置与外观',
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
  final bool emphasized;

  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Tooltip(
        message: tooltip,
        child: BouncyTap(
          onTap: onPressed,
          scaleDown: 0.9,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: emphasized
                  ? theme.colorScheme.primaryContainer
                      .withValues(alpha: isDark ? 0.82 : 0.92)
                  : theme.colorScheme.surface
                      .withValues(alpha: isDark ? 0.68 : 0.84),
              shape: BoxShape.circle,
              border: Border.all(
                color: emphasized
                    ? theme.colorScheme.primary.withValues(alpha: 0.35)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 19,
              color: emphasized
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyScheduleGuideCard extends StatelessWidget {
  const _EmptyScheduleGuideCard({
    required this.onWebImport,
    required this.onFileImport,
    required this.onAddCourse,
  });

  final VoidCallback onWebImport;
  final VoidCallback onFileImport;
  final VoidCallback onAddCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.34),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_view_week_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '欢迎使用翱翔课表',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '登录西工大翱翔教务一键导入，或选择 PDF / Word / CSV / Excel 等任意格式课表快速开启。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          BouncyTap(
            onTap: onWebImport,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    Color.lerp(
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                      0.3,
                    )!,
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language_rounded, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    '西工大教务官网一键导入',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFileImport,
                  icon: const Icon(Icons.upload_file_rounded, size: 17),
                  label: const Text('多格式导入'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddCourse,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('手动添加'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

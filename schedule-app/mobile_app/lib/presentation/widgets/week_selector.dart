import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/course.dart';
import 'motion_widgets.dart';

/// 周次选择胶囊 + 精美 5×5 周次网格底部抽屉
class WeekSelector extends StatelessWidget {
  static const int minWeek = 1;
  static const int maxWeek = 25;

  final int selectedWeek;
  final int currentWeek;
  final List<Course> allCourses;
  final ValueChanged<int> onChanged;

  const WeekSelector({
    super.key,
    required this.selectedWeek,
    this.currentWeek = 1,
    this.allCourses = const [],
    required this.onChanged,
  });

  Future<void> _openWeekPickerSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WeekGridSheet(
        selectedWeek: selectedWeek,
        currentWeek: currentWeek,
        allCourses: allCourses,
      ),
    );
    if (picked != null && picked != selectedWeek) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BouncyTap(
      onTap: () => _openWeekPickerSheet(context),
      scaleDown: 0.94,
      child: Container(
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.72 : 0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: Text(
                '第$selectedWeek周',
                key: ValueKey<int>(selectedWeek),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekGridSheet extends StatelessWidget {
  const _WeekGridSheet({
    required this.selectedWeek,
    required this.currentWeek,
    required this.allCourses,
  });

  final int selectedWeek;
  final int currentWeek;
  final List<Course> allCourses;

  int _courseCountInWeek(int week) {
    if (allCourses.isEmpty) return 0;
    var count = 0;
    for (final c in allCourses) {
      if (c.isVisibleInWeek(week)) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '切换周次',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '当前实际为第 $currentWeek 周 · 圆点表示有课',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (selectedWeek != currentWeek)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(currentWeek);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.today_rounded, size: 15),
                      label: const Text(
                        '回本周',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.16,
                ),
                itemCount: WeekSelector.maxWeek,
                itemBuilder: (context, index) {
                  final week = index + 1;
                  final isSelected = week == selectedWeek;
                  final isThisWeek = week == currentWeek;
                  final count = _courseCountInWeek(week);

                  return BouncyTap(
                    scaleDown: 0.92,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(week);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  Color.lerp(
                                    theme.colorScheme.primary,
                                    theme.colorScheme.tertiary,
                                    0.28,
                                  )!,
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isThisWeek
                                ? theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.6)
                                : theme.colorScheme.surfaceContainerLow),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isThisWeek
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.55)
                                  : theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4)),
                          width: isSelected || isThisWeek ? 1.2 : 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$week',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : (isThisWeek
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface),
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (isThisWeek)
                            Text(
                              '本周',
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                        .withValues(alpha: 0.9)
                                    : theme.colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                count == 0 ? 0 : (count >= 12 ? 3 : (count >= 5 ? 2 : 1)),
                                (_) => Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                            .withValues(alpha: 0.85)
                                        : theme.colorScheme.primary
                                            .withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

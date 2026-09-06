import 'package:flutter/material.dart';

class WeekSelector extends StatelessWidget {
  static const int minWeek = 1;
  static const int maxWeek = 25;

  final int selectedWeek;
  final int currentWeek;
  final ValueChanged<int> onChanged;

  const WeekSelector({
    super.key,
    required this.selectedWeek,
    this.currentWeek = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<int>(
      initialValue: selectedWeek,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      itemBuilder: (context) {
        return List.generate(maxWeek, (index) {
          final week = index + 1;
          final isSelected = week == selectedWeek;
          final isThisWeek = week == currentWeek;

          return PopupMenuItem(
            value: week,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '第$week周',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                if (isThisWeek)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '本周',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '第$selectedWeek周',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}


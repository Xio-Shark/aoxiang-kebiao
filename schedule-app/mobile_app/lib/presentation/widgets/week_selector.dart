import 'package:flutter/material.dart';

class WeekSelector extends StatelessWidget {
  static const int minWeek = 1;
  static const int maxWeek = 25;

  final int selectedWeek;
  final ValueChanged<int> onChanged;

  const WeekSelector({
    super.key,
    required this.selectedWeek,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<int>(
      initialValue: selectedWeek,
      onSelected: onChanged,
      itemBuilder: (context) {
        return List.generate(maxWeek, (index) {
          final week = index + 1;
          return PopupMenuItem(
            value: week,
            child: Text('第$week周'),
          );
        });
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '第$selectedWeek周',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
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

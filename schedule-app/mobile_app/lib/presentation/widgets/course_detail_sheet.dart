import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';

class CourseDetailSheet extends StatelessWidget {
  final Course course;

  const CourseDetailSheet({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseColor = Color(course.color);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(course: course, courseColor: courseColor),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: '教师',
                value: course.teacher.isEmpty ? '未设置' : course.teacher,
              ),
              _DetailRow(
                icon: Icons.place_outlined,
                label: '教室',
                value: course.classroom.isEmpty ? '未设置' : course.classroom,
              ),
              _DetailRow(
                icon: Icons.date_range_outlined,
                label: '周次',
                value: course.weekDisplayText,
              ),
              if (course.campus.isNotEmpty)
                _DetailRow(
                  icon: Icons.apartment_rounded,
                  label: '校区',
                  value: course.campus,
                ),
              if (course.note.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: '备注',
                  value: course.note,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final Course course;
  final Color courseColor;

  const _SheetHeader({
    required this.course,
    required this.courseColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: courseColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(width: 18, height: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_weekdayName(course.weekday)} ${course.sectionDisplayText}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayName(int weekday) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  if (weekday < 1 || weekday > names.length) {
    return '星期$weekday';
  }
  return names[weekday - 1];
}

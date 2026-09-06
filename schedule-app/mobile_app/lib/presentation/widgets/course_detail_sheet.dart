import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';
import 'add_course_dialog.dart';

class CourseDetailSheet extends ConsumerStatefulWidget {
  final Course course;
  final List<Course> overlappingCourses;

  const CourseDetailSheet({
    super.key,
    required this.course,
    this.overlappingCourses = const [],
  });

  @override
  ConsumerState<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends ConsumerState<CourseDetailSheet> {
  late Course _currentCourse;

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
  }

  Future<void> _deleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定要删除「${_currentCourse.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref.read(manageCourseUseCaseProvider).delete(_currentCourse.id);
      result.when(
        success: (_) {
          ref.invalidate(scheduleProvider);
          for (var w = 1; w <= 25; w++) {
            ref.invalidate(weekScheduleProvider(w));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除课程「${_currentCourse.name}」')),
            );
            Navigator.of(context).pop();
          }
        },
        failure: (f) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: ${f.message}')),
            );
          }
        },
      );
    }
  }

  Future<void> _editCourse() async {
    final updated = await AddCourseDialog.show(
      context,
      initialCourse: _currentCourse,
    );
    if (updated == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseColor = Color(_currentCourse.color);
    final allCourses = widget.overlappingCourses.isEmpty
        ? [_currentCourse]
        : widget.overlappingCourses;

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
              if (allCourses.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.layers_outlined, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '发现 ${allCourses.length} 门重叠课程，请选择查看：',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allCourses.map((c) {
                      final isSelected = c.id == _currentCourse.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 12),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentCourse = c;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              _SheetHeader(course: _currentCourse, courseColor: courseColor),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: '教师',
                value: _currentCourse.teacher.isEmpty ? '未设置' : _currentCourse.teacher,
              ),
              _DetailRow(
                icon: Icons.place_outlined,
                label: '教室',
                value: _currentCourse.classroom.isEmpty ? '未设置' : _currentCourse.classroom,
              ),
              _DetailRow(
                icon: Icons.date_range_outlined,
                label: '周次',
                value: _currentCourse.weekDisplayText,
              ),
              if (_currentCourse.campus.isNotEmpty)
                _DetailRow(
                  icon: Icons.apartment_rounded,
                  label: '校区',
                  value: _currentCourse.campus,
                ),
              if (_currentCourse.note.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: '备注',
                  value: _currentCourse.note,
                ),
              const SizedBox(height: 16),
              // 编辑与删除操作按钮栏
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editCourse,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('编辑课程'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _deleteCourse,
                      icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                      label: Text('删除', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                ],
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
            width: 48,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
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
  if (weekday < 1 || weekday > 7) {
    return '未知周';
  }
  return names[weekday - 1];
}

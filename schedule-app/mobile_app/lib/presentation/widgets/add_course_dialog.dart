import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../core/constants/course_color_palette.dart';
import '../../domain/entities/course.dart';

/// 手动添加或编辑课程弹窗
class AddCourseDialog extends ConsumerStatefulWidget {
  final Course? initialCourse;
  final int? defaultWeekday;
  final int? defaultStartSection;

  const AddCourseDialog({
    super.key,
    this.initialCourse,
    this.defaultWeekday,
    this.defaultStartSection,
  });

  static Future<bool?> show(
    BuildContext context, {
    Course? initialCourse,
    int? defaultWeekday,
    int? defaultStartSection,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCourseDialog(
        initialCourse: initialCourse,
        defaultWeekday: defaultWeekday,
        defaultStartSection: defaultStartSection,
      ),
    );
  }

  @override
  ConsumerState<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends ConsumerState<AddCourseDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _classroomController;
  late final TextEditingController _teacherController;

  late int _weekday;
  late int _startSection;
  late int _sectionCount;
  late int _startWeek;
  late int _endWeek;
  late WeekPattern _weekPattern;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCourse;
    _nameController = TextEditingController(text: c?.name ?? '');
    _classroomController = TextEditingController(text: c?.classroom ?? '');
    _teacherController = TextEditingController(text: c?.teacher ?? '');

    _weekday = c?.weekday ?? widget.defaultWeekday ?? DateTime.now().weekday;
    _startSection = c?.startSection ?? widget.defaultStartSection ?? 1;
    _sectionCount = c?.sectionCount ?? 2;
    _startWeek = c?.startWeek ?? 1;
    _endWeek = c?.endWeek ?? 18;
    _weekPattern = c?.weekPattern ?? WeekPattern.all;
    _selectedColor = c?.color ?? CourseColorPalette.morandiColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classroomController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.initialCourse != null;
    final course = Course(
      id: widget.initialCourse?.id ?? 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      classroom: _classroomController.text.trim(),
      teacher: _teacherController.text.trim(),
      campus: widget.initialCourse?.campus ?? '长安校区',
      weekday: _weekday,
      startSection: _startSection,
      sectionCount: _sectionCount,
      startWeek: _startWeek,
      endWeek: _endWeek,
      weekPattern: _weekPattern,
      customWeeks: widget.initialCourse?.customWeeks ?? const [],
      color: _selectedColor,
    );

    final useCase = ref.read(manageCourseUseCaseProvider);
    final result = isEdit ? await useCase.update(course) : await useCase.add(course);

    result.when(
      success: (_) {
        ref.invalidate(scheduleProvider);
        for (var w = 1; w <= 25; w++) {
          ref.invalidate(weekScheduleProvider(w));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? '课程更新成功' : '课程添加成功')),
          );
          Navigator.of(context).pop(true);
        }
      },
      failure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: ${failure.message}')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialCourse != null;
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? '编辑课程' : '手动添加课程',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 课程名称
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '课程名称 *',
                  prefixIcon: Icon(Icons.book_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '请输入课程名称' : null,
              ),
              const SizedBox(height: 12),
              // 教室与老师
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _classroomController,
                      decoration: const InputDecoration(
                        labelText: '上课教室',
                        prefixIcon: Icon(Icons.place_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _teacherController,
                      decoration: const InputDecoration(
                        labelText: '任课教师',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 星期选择
              Text('上课星期', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (index) {
                    final d = index + 1;
                    final isSelected = _weekday == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(weekdays[index]),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _weekday = d);
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
              // 节次与节数
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _startSection,
                      decoration: const InputDecoration(
                        labelText: '开始节次',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((s) => DropdownMenuItem(value: s, child: Text('第$s节')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _startSection = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _sectionCount,
                      decoration: const InputDecoration(
                        labelText: '节数',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [1, 2, 3, 4]
                          .map((c) => DropdownMenuItem(value: c, child: Text('$c节课')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _sectionCount = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 起止周
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _startWeek,
                      decoration: const InputDecoration(
                        labelText: '开始周',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(25, (i) => i + 1)
                          .map((w) => DropdownMenuItem(value: w, child: Text('第$w周')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _startWeek = val;
                            if (_endWeek < _startWeek) _endWeek = _startWeek;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _endWeek,
                      decoration: const InputDecoration(
                        labelText: '结束周',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(25, (i) => i + 1)
                          .where((w) => w >= _startWeek)
                          .map((w) => DropdownMenuItem(value: w, child: Text('第$w周')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _endWeek = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 单双周模式
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('每周'),
                    selected: _weekPattern == WeekPattern.all,
                    onSelected: (s) => s ? setState(() => _weekPattern = WeekPattern.all) : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('单周'),
                    selected: _weekPattern == WeekPattern.odd,
                    onSelected: (s) => s ? setState(() => _weekPattern = WeekPattern.odd) : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('双周'),
                    selected: _weekPattern == WeekPattern.even,
                    onSelected: (s) => s ? setState(() => _weekPattern = WeekPattern.even) : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 卡片配色
              Text('课程卡片配色', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourseColorPalette.morandiColors.map((colorVal) {
                  final isSelected = _selectedColor == colorVal;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // 提交按钮
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isEdit ? '保存修改' : '确认添加', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

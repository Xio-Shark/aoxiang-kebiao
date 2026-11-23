import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';
import '../../domain/entities/section_time.dart';
import 'motion_widgets.dart';

/// 导入预览确认结果
class ImportConfirmationResult {
  const ImportConfirmationResult({
    required this.replaceExisting,
    required this.syncTermStartDate,
    required this.syncTimeTable,
  });

  final bool replaceExisting;
  final bool syncTermStartDate;
  final bool syncTimeTable;
}

/// 导入前课程预览与确认底部抽屉
class ImportPreviewSheet extends StatefulWidget {
  const ImportPreviewSheet({
    super.key,
    required this.courses,
    required this.sourceLabel,
    this.timeTable = SectionTimeTable.nwpuChangan,
    this.initialReplaceExisting = true,
    this.detectedTermStartDate,
    this.detectedTimeTable,
  });

  final List<Course> courses;
  final String sourceLabel;
  final SectionTimeTable timeTable;
  final bool initialReplaceExisting;
  final DateTime? detectedTermStartDate;
  final SectionTimeTable? detectedTimeTable;

  static Future<ImportConfirmationResult?> show(
    BuildContext context, {
    required List<Course> courses,
    required String sourceLabel,
    SectionTimeTable timeTable = SectionTimeTable.nwpuChangan,
    bool initialReplaceExisting = true,
    DateTime? detectedTermStartDate,
    SectionTimeTable? detectedTimeTable,
  }) {
    return showModalBottomSheet<ImportConfirmationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportPreviewSheet(
        courses: courses,
        sourceLabel: sourceLabel,
        timeTable: timeTable,
        initialReplaceExisting: initialReplaceExisting,
        detectedTermStartDate: detectedTermStartDate,
        detectedTimeTable: detectedTimeTable,
      ),
    );
  }

  @override
  State<ImportPreviewSheet> createState() => _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends State<ImportPreviewSheet> {
  late bool _replaceExisting;
  late bool _syncTermStartDate;
  late bool _syncTimeTable;

  @override
  void initState() {
    super.initState();
    _replaceExisting = widget.initialReplaceExisting;
    _syncTermStartDate = widget.detectedTermStartDate != null;
    _syncTimeTable = widget.detectedTimeTable != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewTable =
        (_syncTimeTable && widget.detectedTimeTable != null)
            ? widget.detectedTimeTable!
            : widget.timeTable;
    final uniqueNames = widget.courses.map((c) => c.name).toSet().length;
    final minWeek = widget.courses
        .map((c) => c.startWeek)
        .reduce((a, b) => a < b ? a : b);
    final maxWeek = widget.courses
        .map((c) => c.endWeek)
        .reduce((a, b) => a > b ? a : b);
    final maxHeight = MediaQuery.of(context).size.height * 0.80;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已识别 ${widget.courses.length} 条排课',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '来源：${widget.sourceLabel} · $uniqueNames 门课程 · 第 $minWeek-$maxWeek 周',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: widget.courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final course = widget.courses[index];
                  return FadeSlideEntrance(
                    delay: Duration(milliseconds: (index * 24).clamp(0, 180)),
                    duration: const Duration(milliseconds: 220),
                    offsetY: 8,
                    child: _PreviewCourseTile(
                      course: course,
                      timeTable: previewTable,
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '覆盖现有课表（关闭则追加合并）',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _replaceExisting,
                        onChanged: (v) => setState(() => _replaceExisting = v),
                      ),
                    ],
                  ),
                  if (widget.detectedTermStartDate != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '同步开学第1周 (${widget.detectedTermStartDate!.year}-${widget.detectedTermStartDate!.month.toString().padLeft(2, '0')}-${widget.detectedTermStartDate!.day.toString().padLeft(2, '0')})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _syncTermStartDate,
                          onChanged: (v) =>
                              setState(() => _syncTermStartDate = v),
                        ),
                      ],
                    ),
                  if (widget.detectedTimeTable != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '同步教务上下课作息时间 (${widget.detectedTimeTable!.sectionCount}节，${widget.detectedTimeTable!.slots.first.startText}起)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _syncTimeTable,
                          onChanged: (v) => setState(() => _syncTimeTable = v),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(
                              ImportConfirmationResult(
                                replaceExisting: _replaceExisting,
                                syncTermStartDate: _syncTermStartDate,
                                syncTimeTable: _syncTimeTable,
                              ),
                            );
                          },
                          icon:
                              const Icon(Icons.download_done_rounded, size: 19),
                          label: Text(
                            '确认导入 (${widget.courses.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCourseTile extends StatelessWidget {
  const _PreviewCourseTile({
    required this.course,
    required this.timeTable,
  });

  final Course course;
  final SectionTimeTable timeTable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(course.color);
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dayLabel = (course.weekday >= 1 && course.weekday <= 7)
        ? weekdays[course.weekday - 1]
        : '周?';
    final clock = timeTable.formatCourseClockRange(
      course.startSection,
      course.sectionCount,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    '$dayLabel ${course.sectionDisplayText}',
                    if (clock.isNotEmpty) clock,
                    course.weekDisplayText,
                    if (course.classroom.isNotEmpty) course.classroom,
                    if (course.teacher.isNotEmpty) course.teacher,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

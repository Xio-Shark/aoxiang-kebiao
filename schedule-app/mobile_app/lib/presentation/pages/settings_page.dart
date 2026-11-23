/// 设置与外观个性化页面（含系统级课前提醒与作息时间表配置）

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/providers/app_providers.dart';
import '../../core/constants/course_color_palette.dart';
import '../../domain/entities/section_time.dart';
import '../widgets/motion_widgets.dart';
import 'background_crop_page.dart';
import 'import_page.dart';
import 'jiaowu_web_import_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isUpdatingBackground = false;
  bool _isSyncingReminders = false;

  Future<void> _toggleReminder(bool enabled) async {
    setState(() => _isSyncingReminders = true);
    try {
      final service = ref.read(courseReminderServiceProvider);
      if (enabled) {
        final granted = await service.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('未获得系统通知权限，请在系统设置中允许「翱翔课表」发送通知'),
              ),
            );
          }
          return;
        }
      }

      await ref.read(reminderSettingsProvider.notifier).setEnabled(enabled);
      final report = await syncCourseReminders(ref);
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? (report.scheduledCount > 0
                      ? '已开启系统级课前提醒，已预约未来 ${report.scheduledCount} 节课'
                      : '已开启课前提醒（未来 14 天暂无待提醒课程）')
                  : '已关闭系统级课前提醒',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingReminders = false);
      }
    }
  }

  Future<void> _updateLeadMinutes(int minutes) async {
    HapticFeedback.selectionClick();
    await ref.read(reminderSettingsProvider.notifier).setLeadMinutes(minutes);
    final report = await syncCourseReminders(ref);
    if (mounted && ref.read(reminderSettingsProvider).enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已调整为课前 $minutes 分钟提醒，已更新 ${report.scheduledCount} 条排程'),
        ),
      );
    }
  }

  Future<void> _sendTestReminder() async {
    final service = ref.read(courseReminderServiceProvider);
    final granted = await service.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('系统通知权限未开启，无法发送测试提醒')),
        );
      }
      return;
    }

    await service.sendTestNotification(
      timeTable: ref.read(sectionTimeTableProvider),
      settings: ref.read(reminderSettingsProvider),
    );
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发送一条系统级测试通知，请留意顶部通知栏')),
      );
    }
  }

  Future<void> _applyTimeTablePreset(SectionTimeTable preset) async {
    HapticFeedback.selectionClick();
    await ref.read(sectionTimeTableProvider.notifier).applyPreset(preset);
    await syncCourseReminders(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换作息时间：${preset.presetName}')),
      );
    }
  }

  Future<void> _editSectionSlot(SectionTimeSlot slot) async {
    final startPicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: slot.startHour, minute: slot.startMinute),
      helpText: '选择第 ${slot.section} 节上课时间',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (startPicked == null || !mounted) return;

    final endPicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: slot.endHour, minute: slot.endMinute),
      helpText: '选择第 ${slot.section} 节下课时间',
      cancelText: '取消',
      confirmText: '保存',
    );
    if (endPicked == null || !mounted) return;

    final startTotal = startPicked.hour * 60 + startPicked.minute;
    final endTotal = endPicked.hour * 60 + endPicked.minute;
    if (endTotal <= startTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下课时间必须晚于上课时间')),
      );
      return;
    }

    final updated = slot.copyWith(
      startHour: startPicked.hour,
      startMinute: startPicked.minute,
      endHour: endPicked.hour,
      endMinute: endPicked.minute,
    );
    await ref.read(sectionTimeTableProvider.notifier).updateSlot(updated);
    await syncCourseReminders(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已更新第 ${slot.section} 节：${updated.rangeText}'),
        ),
      );
    }
  }

  Future<void> _pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (!mounted || result == null || result.files.single.path == null) {
      return;
    }

    setState(() {
      _isUpdatingBackground = true;
    });

    try {
      final savedPath =
          await _persistBackgroundImage(result.files.single.path!);
      await ref.read(backgroundImagePathProvider.notifier).setPath(savedPath);
      await ref.read(backgroundTransformProvider.notifier).reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('背景图已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('背景图设置失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBackground = false;
        });
      }
    }
  }

  Future<void> _clearBackgroundImage() async {
    final currentPath = ref.read(backgroundImagePathProvider);
    await ref.read(backgroundImagePathProvider.notifier).clear();
    await ref.read(backgroundTransformProvider.notifier).reset();

    if (currentPath != null && currentPath.isNotEmpty) {
      final file = File(currentPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('背景图已清除')),
    );
  }

  Future<String> _persistBackgroundImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('选中的图片不存在');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory(p.join(appDir.path, 'backgrounds'));
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).toLowerCase();
    final targetPath = p.join(bgDir.path, 'schedule_background$extension');
    final target = File(targetPath);

    if (await target.exists()) {
      await target.delete();
    }

    await source.copy(targetPath);
    return targetPath;
  }

  Future<void> _pickTermStartDate() async {
    final current = ref.read(termStartDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '选择学期第一周周一所在日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null && mounted) {
      await ref.read(termStartDateProvider.notifier).setDate(picked);
      invalidateAllScheduleCaches(ref);
      await syncCourseReminders(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已设置第一周为: ${picked.year}年${picked.month}月${picked.day}日 (当前第 ${ref.read(currentWeekProvider)} 周)',
            ),
          ),
        );
      }
    }
  }

  Future<void> _setThisWeekAsFirst() async {
    await ref.read(termStartDateProvider.notifier).setThisWeekAsFirstWeek();
    invalidateAllScheduleCaches(ref);
    await syncCourseReminders(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已将本周设定为第 1 周')),
      );
    }
  }

  Future<void> _clearAllScheduleData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有课表数据'),
        content: const Text('确定要清空本地保存的所有课程数据吗？清空后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(76, 40),
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref.read(settingsUseCaseProvider).clearAll();
      await result.when<Future<void>>(
        success: (_) async {
          invalidateAllScheduleCaches(ref);
          await syncCourseReminders(ref);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('所有课表数据已清空')),
            );
          }
        },
        failure: (f) async {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('清空失败: ${f.message}')),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundImagePath = ref.watch(backgroundImagePathProvider);
    final backgroundOpacity = ref.watch(backgroundOpacityProvider);
    final termStart = ref.watch(termStartDateProvider);
    final currentWeek = ref.watch(currentWeekProvider);
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(themeSeedColorProvider);
    final timeTable = ref.watch(sectionTimeTableProvider);
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final syncReport = ref.watch(reminderSyncReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置与外观'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          // 1. 系统级上课前提醒卡片
          FadeSlideEntrance(
            duration: const Duration(milliseconds: 240),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            size: 19,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '上课前系统级提醒',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '锁屏/后台均可通过系统通知栏推送提醒',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isSyncingReminders)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch.adaptive(
                            value: reminderSettings.enabled,
                            onChanged: _toggleReminder,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '提前提醒时间',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [5, 10, 15, 20, 30].map((mins) {
                        final isSelected = reminderSettings.leadMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins 分钟前'),
                          selected: isSelected,
                          onSelected: (_) => _updateLeadMinutes(mins),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        '提醒铃声与震动',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: reminderSettings.soundEnabled,
                      onChanged: (v) async {
                        await ref
                            .read(reminderSettingsProvider.notifier)
                            .setSoundEnabled(v);
                        await syncCourseReminders(ref);
                      },
                    ),
                    if (reminderSettings.enabled && syncReport != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          syncReport.nextEntry != null
                              ? '已预约未来 ${syncReport.scheduledCount} 节课程提醒 · 下一次：${syncReport.nextEntry!.triggerAt.month}/${syncReport.nextEntry!.triggerAt.day} ${syncReport.nextEntry!.triggerAt.hour.toString().padLeft(2, '0')}:${syncReport.nextEntry!.triggerAt.minute.toString().padLeft(2, '0')} (${syncReport.nextEntry!.course.name})'
                              : '当前已开启提醒，未来 14 天内暂无待提醒课程',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _sendTestReminder,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 17,
                        ),
                        label: const Text('发送一条测试通知'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. 上下课作息时间表设置
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 40),
            duration: const Duration(milliseconds: 260),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '上下课作息时间表',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${timeTable.sectionCount}节制',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '当前：${timeTable.presetName}（影响时间轴、导入时间识别与课前提醒时刻）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SectionTimeTable.presets.map((preset) {
                        final selected = timeTable.presetId == preset.presetId;
                        return ChoiceChip(
                          label: Text(
                            preset.presetName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selected,
                          onSelected: (_) => _applyTimeTablePreset(preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text(
                        '查看 / 逐节自定义上下课时间',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: timeTable.slots.map((slot) {
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 13,
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Text(
                              '${slot.section}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            '第 ${slot.section} 节',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slot.rangeText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          onTap: () => _editSectionSlot(slot),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. 外观与主题色设置
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 70),
            duration: const Duration(milliseconds: 260),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '外观与主题配色',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 17),
                          label: Text('跟随系统'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 17),
                          label: Text('浅色'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 17),
                          label: Text('深色'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(themeModeProvider.notifier)
                            .setMode(selection.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '强调色主题',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: CourseColorPalette.themePresets.map((preset) {
                        final isSelected = seedColor == preset.seedColor;
                        final color = Color(preset.seedColor);
                        return BouncyTap(
                          scaleDown: 0.9,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(themeSeedColorProvider.notifier)
                                .setSeedColor(preset.seedColor);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.16)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                width: isSelected ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? color
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. 学期与周次设置
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 280),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '学期与当前日期',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '当前第 $currentWeek 周',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('开学第一周周一'),
                      subtitle: Text(
                        '${termStart.year}年${termStart.month}月${termStart.day}日',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickTermStartDate,
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _setThisWeekAsFirst,
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('设本周为第 1 周'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 5. 课表导入与数据管理
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 130),
            duration: const Duration(milliseconds: 280),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.language_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text(
                      '西工大教务官网一键导入',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('jwxt.nwpu.edu.cn/student/home'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        SmoothPageRoute<void>(
                          builder: (_) => const JiaowuWebImportPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      Icons.file_download_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text(
                      '多格式课表导入中心',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'PDF / Word / Excel / CSV / ICS / HTML / JSON',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        SmoothPageRoute<void>(
                          builder: (_) => const ImportPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      '清空所有课表数据',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text('重置并清空所有已导入与自定义课程'),
                    onTap: _clearAllScheduleData,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 6. 课表背景设置
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 160),
            duration: const Duration(milliseconds: 280),
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.wallpaper_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '课表自定义背景',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 126,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildBackgroundPreview(backgroundImagePath),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isUpdatingBackground
                                ? null
                                : _pickBackgroundImage,
                            icon: _isUpdatingBackground
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.image_outlined, size: 18),
                            label: Text(
                              _isUpdatingBackground ? '处理中...' : '选择图片',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: backgroundImagePath == null
                              ? null
                              : _clearBackgroundImage,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(86, 48),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清除'),
                        ),
                      ],
                    ),
                    if (backgroundImagePath != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '背景清晰度',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: backgroundOpacity,
                              min: 0.35,
                              max: 1.0,
                              divisions: 13,
                              label: '${(backgroundOpacity * 100).round()}%',
                              onChanged: (v) {
                                ref
                                    .read(backgroundOpacityProvider.notifier)
                                    .setOpacity(v);
                              },
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${(backgroundOpacity * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.crop_rounded),
                        title: const Text('框定背景范围'),
                        subtitle: const Text('拖动与缩放，选择要展示的区域'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothPageRoute<void>(
                              builder: (_) => BackgroundCropPage(
                                imagePath: backgroundImagePath,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPreview(String? path) {
    final theme = Theme.of(context);
    if (path == null || path.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
              theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: theme.colorScheme.primary,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                '当前使用默认极光弥散背景',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return ColoredBox(
          color: theme.colorScheme.errorContainer,
          child: const Center(child: Text('图片读取失败')),
        );
      },
    );
  }
}

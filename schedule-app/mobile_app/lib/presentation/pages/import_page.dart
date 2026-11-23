/// 全能课表导入中心页面
/// 支持：西工大翱翔教务官网直接导入 + PDF/Word/Excel/CSV/ICS/HTML/JSON/TXT 多格式解析 + 剪贴板/文本粘贴导入

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/providers/app_providers.dart';
import '../../data/datasources/course_file_import_data_source.dart';
import '../../domain/entities/course.dart';
import '../widgets/import_preview_sheet.dart';
import '../widgets/motion_widgets.dart';
import 'jiaowu_web_import_page.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final TextEditingController _pasteController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isParsing = false;
  bool _showPasteEditor = false;

  static const List<({String label, String ext, Color color, IconData icon})>
      _formatBadges = [
    (
      label: 'PDF',
      ext: '.pdf',
      color: Color(0xFFD9534F),
      icon: Icons.picture_as_pdf_rounded,
    ),
    (
      label: 'Word',
      ext: '.docx/.doc',
      color: Color(0xFF2B6CB0),
      icon: Icons.description_rounded,
    ),
    (
      label: 'CSV',
      ext: '.csv/.tsv',
      color: Color(0xFF2F855A),
      icon: Icons.grid_on_rounded,
    ),
    (
      label: 'Excel',
      ext: '.xlsx/.xls',
      color: Color(0xFF1F7A5C),
      icon: Icons.table_view_rounded,
    ),
    (
      label: 'ICS日历',
      ext: '.ics',
      color: Color(0xFF6B46C1),
      icon: Icons.event_note_rounded,
    ),
    (
      label: '网页HTML',
      ext: '.html',
      color: Color(0xFFC05621),
      icon: Icons.code_rounded,
    ),
    (
      label: 'JSON',
      ext: '.json',
      color: Color(0xFF4A5568),
      icon: Icons.data_object_rounded,
    ),
    (
      label: '纯文本',
      ext: '.txt',
      color: Color(0xFF3182CE),
      icon: Icons.notes_rounded,
    ),
  ];

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndPreviewFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: LocalCourseFileImportDataSource.supportedExtensions,
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
      _isParsing = true;
    });

    final parseResult = await ref
        .read(courseFileImportDataSourceProvider)
        .parseCourses(
          filePath: file.path,
          fileName: file.name,
          bytes: file.bytes,
        );

    if (!mounted) return;
    setState(() {
      _isParsing = false;
    });

    final courses = parseResult.when<List<Course>?>(
      success: (data) => data,
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        return null;
      },
    );

    if (courses == null) return;

    final extLabel = p.extension(file.name).replaceFirst('.', '').toUpperCase();
    await _previewAndCommit(
      courses: courses,
      sourceLabel: extLabel.isEmpty ? file.name : '$extLabel 文件 (${file.name})',
    );
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板中未发现文本内容')),
        );
      }
      return;
    }
    await _parseTextAndCommit(text, sourceLabel: '剪贴板智能嗅探');
  }

  Future<void> _parseTextAndCommit(
    String text, {
    required String sourceLabel,
  }) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴课表内容')),
      );
      return;
    }

    setState(() => _isParsing = true);
    final parseResult =
        await ref.read(courseFileImportDataSourceProvider).parseRawText(text);
    if (!mounted) return;
    setState(() => _isParsing = false);

    final courses = parseResult.when<List<Course>?>(
      success: (data) => data,
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        return null;
      },
    );

    if (courses == null) return;
    await _previewAndCommit(courses: courses, sourceLabel: sourceLabel);
  }

  Future<void> _previewAndCommit({
    required List<Course> courses,
    required String sourceLabel,
  }) async {
    final confirm = await ImportPreviewSheet.show(
      context,
      courses: courses,
      sourceLabel: sourceLabel,
      timeTable: ref.read(sectionTimeTableProvider),
    );
    if (confirm == null || !mounted) return;

    setState(() => _isParsing = true);
    final importResult = await ref.read(importScheduleUseCaseProvider).execute(
          courses,
          replaceExisting: confirm.replaceExisting,
        );
    if (!mounted) return;
    setState(() => _isParsing = false);

    await importResult.when<Future<void>>(
      success: (_) async {
        invalidateAllScheduleCaches(ref);
        await syncCourseReminders(ref);
        final targetWeek = _resolveTargetWeek(courses);
        ref.read(selectedWeekProvider.notifier).state = targetWeek;
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入成功，共写入 ${courses.length} 条排课记录')),
          );
          Navigator.of(context).pop();
        }
      },
      failure: (failure) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
    );
  }

  int _resolveTargetWeek(List<Course> courses) {
    final currentWeek = ref.read(currentWeekProvider);
    if (courses.any((c) => c.isVisibleInWeek(currentWeek))) {
      return currentWeek;
    }
    final minWeek = courses
        .map((course) => course.startWeek)
        .reduce((min, value) => value < min ? value : min);
    return minWeek.clamp(1, 25);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入课表'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 1. 西工大官网一键导入 Hero 卡片
              FadeSlideEntrance(
                duration: const Duration(milliseconds: 280),
                child: BouncyTap(
                  onTap: () {
                    Navigator.of(context).push(
                      SmoothPageRoute<void>(
                        builder: (_) => const JiaowuWebImportPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          Color.lerp(
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                            0.42,
                          )!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.language_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '西工大翱翔教务导入',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.24),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '推荐',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'jwxt.nwpu.edu.cn/student/home',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '内嵌浏览器直连西工大教务首页，登录后自动嗅探课表接口与网页表格，完整还原周次、单双周、教室与教师。也支持输入其他高校教务网址。',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 多格式文件导入卡片
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 60),
                duration: const Duration(milliseconds: 300),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.folder_copy_outlined,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '本地多格式文件导入',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '纯本地离线解析，支持二维矩阵课表与课程清单表格，并自动嗅探文件真实内容格式。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _formatBadges.map((badge) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5.5,
                              ),
                              decoration: BoxDecoration(
                                color: badge.color.withValues(alpha: 0.11),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: badge.color.withValues(alpha: 0.28),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    badge.icon,
                                    size: 14,
                                    color: badge.color,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    badge.label,
                                    style: TextStyle(
                                      color: badge.color,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '上次选择：${_selectedFile!.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _isParsing ? null : _pickAndPreviewFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 19),
                          label: const Text('选择文件并解析预览'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. 剪贴板 & 文本粘贴智能导入
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 110),
                duration: const Duration(milliseconds: 300),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: theme.colorScheme.tertiary,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '剪贴板与文本智能识别',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showPasteEditor = !_showPasteEditor;
                                });
                              },
                              child: Text(_showPasteEditor ? '收起输入框' : '手动粘贴'),
                            ),
                          ],
                        ),
                        Text(
                          '支持树维 / 正方 / 强智 / WakeUp 导出 JSON、CSV/TSV 表格、HTML 源码或「高数, 周一, 1-2节, 1-16周, 教西D102」文本行。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isParsing ? null : _importFromClipboard,
                          icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                          label: const Text('一键读取剪贴板并识别'),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _showPasteEditor
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _pasteController,
                                        minLines: 4,
                                        maxLines: 8,
                                        style: const TextStyle(fontSize: 12.5),
                                        decoration: const InputDecoration(
                                          hintText:
                                              '粘贴 JSON / CSV / HTML 或每行一门课：\n高等数学, 周一, 1-2节, 1-16周, 教西D102, 张老师',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FilledButton.tonalIcon(
                                        onPressed: _isParsing
                                            ? null
                                            : () => _parseTextAndCommit(
                                                  _pasteController.text,
                                                  sourceLabel: '粘贴文本识别',
                                                ),
                                        icon: const Icon(
                                          Icons.playlist_add_check_rounded,
                                          size: 19,
                                        ),
                                        label: const Text('解析粘贴内容并预览'),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. 兼容系统速览
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 160),
                duration: const Duration(milliseconds: 300),
                child: Card(
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: Icon(
                      Icons.verified_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text(
                      '支持哪些教务系统与课表格式？',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: const [
                      _CompatInfoRow(
                        title: '西工大翱翔教务（主适配）',
                        desc:
                            '直连 jwxt.nwpu.edu.cn/student/home，自动拦截树维 EAMS5 接口与课表 DOM，也支持导入打印导出的 PDF / Word 课表。',
                      ),
                      SizedBox(height: 8),
                      _CompatInfoRow(
                        title: '通用高校教务系统',
                        desc:
                            '兼容树维、正方（kbList）、强智、青果教务导出的 Excel / Word / HTML / PDF / CSV 课表与网页嗅探。',
                      ),
                      SizedBox(height: 8),
                      _CompatInfoRow(
                        title: '第三方课表与日历迁移',
                        desc:
                            '兼容 WakeUp 课程表导出文件与 CSV、标准 iCalendar (.ics) 日历文件与本应用 JSON 备份。',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isParsing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.24),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 14),
                        Text(
                          '正在智能解析课表...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompatInfoRow extends StatelessWidget {
  const _CompatInfoRow({
    required this.title,
    required this.desc,
  });

  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

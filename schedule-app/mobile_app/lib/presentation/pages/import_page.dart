/// 导入页面

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';
import '../../domain/entities/course.dart';

import 'jiaowu_web_import_page.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  PlatformFile? _selectedFile;
  bool _replaceExisting = true;
  bool _isImporting = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'docx', 'xlsx', 'xls', 'ics'],
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
    });
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

    setState(() {
      _isImporting = true;
    });

    final parseResult = await ref
        .read(courseFileImportDataSourceProvider)
        .parseCourses(
          fileName: 'clipboard.json',
          bytes: utf8.encode(text),
        );

    final courses = parseResult.when<List<Course>?>(
      success: (data) => data,
      failure: (failure) {
        // 尝试按通用文本行简单解析
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('剪贴板内容识别失败: ${failure.message}')),
          );
        }
        return null;
      },
    );

    if (courses == null || !mounted) {
      setState(() {
        _isImporting = false;
      });
      return;
    }

    final importResult = await ref.read(importScheduleUseCaseProvider).execute(
          courses,
          replaceExisting: _replaceExisting,
        );

    importResult.when(
      success: (_) {
        final targetWeek = _resolveTargetWeek(courses);
        ref.read(selectedWeekProvider.notifier).state = targetWeek;
        ref.invalidate(scheduleProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('剪贴板导入成功，共 ${courses.length} 门课程')),
          );
          Navigator.of(context).pop();
        }
      },
      failure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
    );

    if (mounted) {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _startImport() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择导入文件')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final parseResult = await ref
        .read(courseFileImportDataSourceProvider)
        .parseCourses(
          filePath: selectedFile.path,
          fileName: selectedFile.name,
          bytes: selectedFile.bytes,
        );

    final courses = parseResult.when(
      success: (data) => data,
      failure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
        return null;
      },
    );

    if (courses == null || !mounted) {
      setState(() {
        _isImporting = false;
      });
      return;
    }

    final importResult = await ref.read(importScheduleUseCaseProvider).execute(
          courses,
          replaceExisting: _replaceExisting,
        );

    importResult.when(
      success: (_) {
        final targetWeek = _resolveTargetWeek(courses);
        ref.read(selectedWeekProvider.notifier).state = targetWeek;
        ref.invalidate(scheduleProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入成功，共 ${courses.length} 门课程')),
          );
          Navigator.of(context).pop();
        }
      },
      failure: (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isImporting = false;
    });
  }

  int _resolveTargetWeek(List<Course> courses) {
    final minWeek = courses
        .map((course) => course.startWeek)
        .reduce((min, value) => value < min ? value : min);
    if (minWeek < 1) {
      return 1;
    }
    if (minWeek > 25) {
      return 25;
    }
    return minWeek;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入课表'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
            child: ListTile(
              leading: Icon(
                Icons.language_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              title: const Text(
                '教务系统直接导入',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('通过网页登录翱翔教务，一键自动嗅探导入'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JiaowuWebImportPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('选择本地文件'),
              subtitle: Text(_selectedFile?.name ?? '支持 .docx / .xlsx / .ics / .json'),
              trailing: const Icon(Icons.folder_open),
              onTap: _pickFile,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('从剪贴板嗅探导入'),
              subtitle: const Text('自动识别复制的教务课表文本或口令'),
              trailing: const Icon(Icons.auto_awesome),
              onTap: _importFromClipboard,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: _replaceExisting,
              title: const Text('覆盖现有课程'),
              subtitle: const Text('关闭后将尝试保留当前课程'),
              onChanged: (value) {
                setState(() {
                  _replaceExisting = value;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isImporting ? null : _startImport,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_isImporting ? '导入中...' : '开始导入'),
          ),
        ],
      ),
    );
  }
}

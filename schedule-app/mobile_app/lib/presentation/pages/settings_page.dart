/// 设置页面

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/providers/app_providers.dart';
import 'background_crop_page.dart';
import 'import_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isUpdatingBackground = false;

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
      final savedPath = await _persistBackgroundImage(result.files.single.path!);
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

    if (!mounted) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final backgroundImagePath = ref.watch(backgroundImagePathProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导入课表'),
              subtitle: const Text('从文件导入课程数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '背景图片',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildBackgroundPreview(backgroundImagePath),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    backgroundImagePath == null ? '未设置背景图' : backgroundImagePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isUpdatingBackground ? null : _pickBackgroundImage,
                        icon: _isUpdatingBackground
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(_isUpdatingBackground ? '处理中...' : '选择图片'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: backgroundImagePath == null ? null : _clearBackgroundImage,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('清除'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.crop),
                    title: const Text('框定背景范围'),
                    subtitle: const Text('拖动与缩放，选择要展示的区域'),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: backgroundImagePath != null,
                    onTap: backgroundImagePath == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BackgroundCropPage(
                                  imagePath: backgroundImagePath,
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPreview(String? path) {
    if (path == null || path.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('暂无背景图')),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.errorContainer,
          child: const Center(child: Text('图片读取失败')),
        );
      },
    );
  }
}

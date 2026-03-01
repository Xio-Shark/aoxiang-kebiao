/// 背景范围编辑页面

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/app_providers.dart';

class BackgroundCropPage extends ConsumerStatefulWidget {
  final String imagePath;

  const BackgroundCropPage({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<BackgroundCropPage> createState() => _BackgroundCropPageState();
}

class _BackgroundCropPageState extends ConsumerState<BackgroundCropPage> {
  late double _scale;
  late double _offsetX;
  late double _offsetY;
  double _baseScale = 1;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    final state = ref.read(backgroundTransformProvider);
    _scale = state.scale;
    _offsetX = state.offsetX;
    _offsetY = state.offsetY;
  }

  void _reset() {
    setState(() {
      _scale = 1;
      _offsetX = 0;
      _offsetY = 0;
    });
  }

  Future<void> _save() async {
    await ref.read(backgroundTransformProvider.notifier).update(
          scale: _scale,
          offsetX: _offsetX,
          offsetY: _offsetY,
        );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('框定背景范围'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                return ClipRect(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {
                      _baseScale = _scale;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        if (details.pointerCount >= 2) {
                          _scale = (_baseScale * details.scale).clamp(1.0, 4.0);
                        }
                        _offsetX = (_offsetX +
                                details.focalPointDelta.dx /
                                    (_viewportSize.width / 2))
                            .clamp(-2.0, 2.0);
                        _offsetY = (_offsetY +
                                details.focalPointDelta.dy /
                                    (_viewportSize.height / 2))
                            .clamp(-2.0, 2.0);
                      });
                    },
                    child: _buildPreviewImage(),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('缩放'),
                    Expanded(
                      child: Slider(
                        value: _scale,
                        min: 1.0,
                        max: 4.0,
                        divisions: 30,
                        label: _scale.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() {
                            _scale = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重置'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '拖动移动背景，双指缩放调整范围',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dx = _offsetX * width * 0.5;
        final dy = _offsetY * height * 0.5;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: _scale,
            child: Image.file(
              File(widget.imagePath),
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

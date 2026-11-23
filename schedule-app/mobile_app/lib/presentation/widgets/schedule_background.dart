import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/providers/app_providers.dart';

/// 柔和弥散极光背景与自定义壁纸背景层
class ScheduleBackground extends StatelessWidget {
  final String? imagePath;
  final BackgroundTransformState transform;
  final double overlayOpacity;

  const ScheduleBackground({
    super.key,
    required this.imagePath,
    required this.transform,
    this.overlayOpacity = 0.82,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 默认柔和极光弥散氛围层（纯硬件加速渐变，零滤镜卡顿）
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(
                          theme.colorScheme.surface,
                          theme.colorScheme.primaryContainer,
                          0.26,
                        )!,
                        theme.colorScheme.surface,
                        Color.lerp(
                          theme.colorScheme.surface,
                          theme.colorScheme.tertiaryContainer,
                          0.20,
                        )!,
                      ]
                    : [
                        Color.lerp(
                          theme.colorScheme.surface,
                          theme.colorScheme.primaryContainer,
                          0.34,
                        )!,
                        theme.colorScheme.surface,
                        Color.lerp(
                          theme.colorScheme.surface,
                          theme.colorScheme.secondaryContainer,
                          0.28,
                        )!,
                      ],
              ),
            ),
          ),
          // 顶部柔和主题光晕
          Positioned(
            top: -110,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.18 : 0.14,
                      ),
                      theme.colorScheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.tertiary.withValues(
                        alpha: isDark ? 0.16 : 0.12,
                      ),
                      theme.colorScheme.tertiary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            _BackgroundImage(
              imagePath: imagePath!,
              transform: transform,
            ),
            ColoredBox(
              color: theme.colorScheme.surface.withValues(
                alpha: (1 - overlayOpacity).clamp(0.15, 0.78),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.22),
                    theme.colorScheme.surface.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final String imagePath;
  final BackgroundTransformState transform;

  const _BackgroundImage({
    required this.imagePath,
    required this.transform,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dx = transform.offsetX * width * 0.5;
        final dy = transform.offsetY * height * 0.5;

        return ClipRect(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: transform.scale,
              child: Image.file(
                File(imagePath),
                width: width,
                height: height,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.92),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

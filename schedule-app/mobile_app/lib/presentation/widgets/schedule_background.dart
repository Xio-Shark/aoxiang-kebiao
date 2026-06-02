import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/providers/app_providers.dart';

class ScheduleBackground extends StatelessWidget {
  final String? imagePath;
  final BackgroundTransformState transform;

  const ScheduleBackground({
    super.key,
    required this.imagePath,
    required this.transform,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imagePath != null && imagePath!.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        radialGradient: RadialGradient(
          center: const Alignment(-0.7, -0.9),
          radius: 1.4,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            _BackgroundImage(
              imagePath: imagePath!,
              transform: transform,
            ),
          ColoredBox(
            color: theme.colorScheme.surface.withValues(alpha: 0.48),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.18),
                  theme.colorScheme.surface.withValues(alpha: 0.76),
                ],
              ),
            ),
          ),
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
                opacity: const AlwaysStoppedAnimation(0.86),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

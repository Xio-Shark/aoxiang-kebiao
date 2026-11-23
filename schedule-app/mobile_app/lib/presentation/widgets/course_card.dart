import 'package:flutter/material.dart';

import '../../core/constants/course_color_palette.dart';
import '../../domain/entities/course.dart';
import 'motion_widgets.dart';

/// 现代质感课程卡片（弹性按压 + 柔和交错浮现 + 左侧色条 + 上课中脉冲指示）
class CourseCard extends StatelessWidget {
  final Course course;
  final double height;
  final int conflictCount;
  final bool isOngoing;
  final int staggerIndex;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.height,
    this.conflictCount = 0,
    this.isOngoing = false,
    this.staggerIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(course.color);
    final accentColor = CourseColorPalette.getAccentColor(baseColor);
    final deepAccent = CourseColorPalette.getDeepAccentColor(baseColor);
    final textColor = _readableTextColor(baseColor);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final delayMs = (staggerIndex * 22).clamp(0, 180);

    return FadeSlideEntrance(
      delay: Duration(milliseconds: delayMs),
      duration: const Duration(milliseconds: 240),
      offsetY: 6,
      beginScale: 0.96,
      child: BouncyTap(
        onTap: onTap,
        scaleDown: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withValues(alpha: isDark ? 0.88 : 0.95),
                accentColor.withValues(alpha: isDark ? 0.78 : 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isOngoing
                  ? Colors.white.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: isDark ? 0.24 : 0.48),
              width: isOngoing ? 1.4 : 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: isOngoing ? 0.42 : 0.26),
                blurRadius: isOngoing ? 10 : 6,
                offset: const Offset(0, 2.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 左侧精致强调色条
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: deepAccent.withValues(alpha: 0.85),
                  ),
                ),
                // 顶部极细高光折射层
                Positioned(
                  left: 3,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 1.2,
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6.5, 4.5, 4.5, 4),
                  child: _CourseContent(
                    course: course,
                    textColor: textColor,
                    height: height,
                  ),
                ),
                // 「上课中」呼吸脉冲光点
                if (isOngoing)
                  const Positioned(
                    top: 3,
                    right: 3,
                    child: PulseDot(
                      color: Colors.white,
                      size: 5.5,
                    ),
                  ),
                // 多课程重叠角标
                if (conflictCount > 1)
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '+${conflictCount - 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseContent extends StatelessWidget {
  final Course course;
  final Color textColor;
  final double height;

  const _CourseContent({
    required this.course,
    required this.textColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = textColor.withValues(alpha: 0.88);
    final isCompact = height < 52;
    final isSpacious = height >= 84;
    final patternBadge = switch (course.weekPattern) {
      WeekPattern.odd => '单',
      WeekPattern.even => '双',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          course.name,
          style: TextStyle(
            color: textColor,
            fontSize: isCompact ? 10 : 10.8,
            fontWeight: FontWeight.w800,
            height: 1.16,
            letterSpacing: -0.15,
          ),
          maxLines: isCompact ? 1 : (isSpacious ? 3 : 2),
          overflow: TextOverflow.ellipsis,
        ),
        if (!isCompact && course.classroom.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.place_rounded, size: 9.2, color: secondary),
              const SizedBox(width: 1.5),
              Expanded(
                child: Text(
                  course.classroom,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (isSpacious && course.teacher.isNotEmpty) ...[
          const SizedBox(height: 2.5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: 9.2, color: secondary),
              const SizedBox(width: 1.5),
              Expanded(
                child: Text(
                  course.teacher,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 8.6,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (isSpacious && patternBadge != null) ...[
          const SizedBox(height: 3.5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$patternBadge周',
              style: TextStyle(
                color: textColor,
                fontSize: 7.8,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Color _readableTextColor(Color background) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}

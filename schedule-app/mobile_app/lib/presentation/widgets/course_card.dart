import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/course_color_palette.dart';
import '../../domain/entities/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final double height;
  final int conflictCount;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.height,
    this.conflictCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(course.color);
    final accentColor = CourseColorPalette.getAccentColor(baseColor);
    final textColor = _readableTextColor(baseColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withValues(alpha: 0.93),
                accentColor.withValues(alpha: 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.28),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _CourseContent(
                course: course,
                textColor: textColor,
                height: height,
              ),
              if (conflictCount > 1)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Text(
                      '+$conflictCount',
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
    final secondary = textColor.withValues(alpha: 0.85);
    final isCompact = height < 52;
    final isSpacious = height >= 88;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          course.name,
          style: TextStyle(
            color: textColor,
            fontSize: isCompact ? 10 : 11,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.1,
          ),
          maxLines: isCompact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isCompact && course.classroom.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.place_rounded, size: 9.5, color: secondary),
              const SizedBox(width: 1.5),
              Expanded(
                child: Text(
                  course.classroom,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
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
              Icon(Icons.person_rounded, size: 9.5, color: secondary),
              const SizedBox(width: 1.5),
              Expanded(
                child: Text(
                  course.teacher,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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

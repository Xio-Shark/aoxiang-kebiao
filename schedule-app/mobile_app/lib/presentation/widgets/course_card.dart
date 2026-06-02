/// 课程卡片组件。

import 'package:flutter/material.dart';

import '../../domain/entities/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final double height;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Color(course.color);
    final textColor = _readableTextColor(baseColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _CourseContent(
            course: course,
            textColor: textColor,
            compact: height < 54,
          ),
        ),
      ),
    );
  }
}

class _CourseContent extends StatelessWidget {
  final Course course;
  final Color textColor;
  final bool compact;

  const _CourseContent({
    required this.course,
    required this.textColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = textColor.withValues(alpha: 0.78);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.name,
          style: TextStyle(
            color: textColor,
            fontSize: compact ? 10.5 : 11.5,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: 0,
          ),
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact) ...[
          const SizedBox(height: 3),
          if (course.classroom.isNotEmpty)
            _MetaLine(
              icon: Icons.location_on_outlined,
              value: course.classroom,
              color: secondary,
            ),
          _MetaLine(
            icon: Icons.calendar_today_outlined,
            value: course.weekDisplayText,
            color: secondary,
          ),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetaLine({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

Color _readableTextColor(Color background) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  return brightness == Brightness.dark ? Colors.white : Colors.black;
}

/// 课程卡片组件
/// 展示单个课程的基本信息

import 'package:flutter/material.dart';
import '../../domain/entities/course.dart';

/// 课程卡片
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(course.color);
    final height = course.sectionCount * 60.0 - 4;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 课程名
          Text(
            course.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 教室
          if (course.classroom.isNotEmpty)
            Text(
              course.classroom,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          // 周次
          Text(
            course.weekDisplayText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 课程详情底部弹窗
class CourseDetailSheet extends StatelessWidget {
  final Course course;

  const CourseDetailSheet({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(course.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // TODO: 编辑课程
                },
              ),
            ],
          ),
          const Divider(),
          // 详情
          _DetailRow(
            icon: Icons.person,
            label: '教师',
            value: course.teacher.isEmpty ? '未设置' : course.teacher,
          ),
          _DetailRow(
            icon: Icons.location_on,
            label: '教室',
            value: course.classroom.isEmpty ? '未设置' : course.classroom,
          ),
          _DetailRow(
            icon: Icons.calendar_today,
            label: '周次',
            value: course.weekDisplayText,
          ),
          _DetailRow(
            icon: Icons.access_time,
            label: '时间',
            value: '星期${course.weekday} ${course.sectionDisplayText}',
          ),
          if (course.campus.isNotEmpty)
            _DetailRow(
              icon: Icons.apartment,
              label: '校区',
              value: course.campus,
            ),
          if (course.note.isNotEmpty)
            _DetailRow(
              icon: Icons.note,
              label: '备注',
              value: course.note,
            ),
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: 分享课程
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('分享'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: 删除课程
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('删除'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 详情行
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

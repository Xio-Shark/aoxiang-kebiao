import 'package:flutter/material.dart';

/// 莫兰迪低饱和度高级调色盘
/// 经过无障碍对比度调优，适合课程卡片与毛玻璃背景展示
class CourseColorPalette {
  static const List<int> morandiColors = [
    0xFF4F779A, // 雾霾蓝
    0xFF4A7C59, // 鼠尾草绿
    0xFF8C6D98, // 丁香紫灰
    0xFFC07058, // 陶土暖红
    0xFF3F827E, // 松石绿
    0xFF5D6D7E, // 板岩蓝灰
    0xFF996B54, // 琥珀茶棕
    0xFF6B728E, // 黛灰蓝
    0xFF52796F, // 青瓷暗绿
    0xFF85586F, // 烟粉玫瑰
    0xFF4A6B82, // 极光灰蓝
    0xFF7D7461, // 亚麻暖灰
    0xFF5C6B73, // 青石灰
    0xFFB06C6C, // 干枯玫瑰
    0xFF436573, // 深海青
    0xFF7A6855, // 复古卡其
  ];

  const CourseColorPalette._();

  /// 根据课程名称确定性映射到调色盘颜色
  static int getColorForName(String name) {
    if (name.isEmpty) return morandiColors.first;
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return morandiColors[hash % morandiColors.length];
  }

  /// 计算微渐变终止辅色（轻微提升明度）
  static Color getAccentColor(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final nextLightness = (hsl.lightness + 0.09).clamp(0.0, 0.95);
    return hsl.withLightness(nextLightness).toColor();
  }
}

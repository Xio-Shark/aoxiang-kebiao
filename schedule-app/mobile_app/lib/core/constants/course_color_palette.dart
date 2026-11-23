import 'package:flutter/material.dart';

/// 主题强调色预设
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.seedColor,
  });

  final String id;
  final String name;
  final int seedColor;
}

/// 莫兰迪低饱和度高级调色盘与主题配色
/// 经过无障碍对比度调优，兼顾浅色与深色模式下的细腻质感
class CourseColorPalette {
  const CourseColorPalette._();

  static const List<AppThemePreset> themePresets = [
    AppThemePreset(id: 'teal', name: '青瓷青', seedColor: 0xFF0E7C73),
    AppThemePreset(id: 'nwpu_blue', name: '翱翔蓝', seedColor: 0xFF1E5FA8),
    AppThemePreset(id: 'indigo', name: '黛靛蓝', seedColor: 0xFF4B5EAA),
    AppThemePreset(id: 'violet', name: '丁香紫', seedColor: 0xFF7B5EA7),
    AppThemePreset(id: 'amber', name: '暖陶橙', seedColor: 0xFFC46D3B),
    AppThemePreset(id: 'rose', name: '烟霞粉', seedColor: 0xFFB8546B),
  ];

  static const List<int> morandiColors = [
    0xFF3E78A3, // 晴空海蓝
    0xFF3E846C, // 鼠尾草绿
    0xFF7C66A6, // 暮云紫灰
    0xFFC56B54, // 陶土珊瑚
    0xFF2F8488, // 松石青绿
    0xFF536B88, // 岩板靛蓝
    0xFFA4704E, // 琥珀拿铁
    0xFF5D6C9B, // 黛蓝灰
    0xFF477E63, // 青瓷松绿
    0xFF9C5975, // 烟粉玫瑰
    0xFF3B7692, // 极光深青
    0xFF837356, // 亚麻暖棕
    0xFF55707E, // 青石雾蓝
    0xFFB6626E, // 干枯玫瑰
    0xFF366C7E, // 深海碧蓝
    0xFF7A6855, // 复古卡其
  ];

  /// 根据课程名称确定性映射到调色盘颜色
  static int getColorForName(String name) {
    if (name.isEmpty) return morandiColors.first;
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return morandiColors[hash % morandiColors.length];
  }

  /// 计算卡片微渐变终止辅色（轻微色相偏移 + 提升明度，避免单调）
  static Color getAccentColor(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final nextHue = (hsl.hue + 10) % 360;
    final nextLightness = (hsl.lightness + 0.08).clamp(0.0, 0.92);
    final nextSaturation = (hsl.saturation + 0.04).clamp(0.0, 0.9);
    return hsl
        .withHue(nextHue)
        .withLightness(nextLightness)
        .withSaturation(nextSaturation)
        .toColor();
  }

  /// 计算深层阴影或左侧强调条色
  static Color getDeepAccentColor(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final nextLightness = (hsl.lightness - 0.14).clamp(0.08, 0.85);
    return hsl.withLightness(nextLightness).toColor();
  }
}

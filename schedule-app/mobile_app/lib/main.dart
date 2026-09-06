/// 应用入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/providers/app_providers.dart';
import 'presentation/pages/schedule_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储实例
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AoxiangScheduleApp(),
    ),
  );
}

/// 应用根组件
class AoxiangScheduleApp extends StatelessWidget {
  const AoxiangScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0E7C73);

    return MaterialApp(
      title: '翱翔课表',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, seedColor),
      darkTheme: _buildTheme(Brightness.dark, seedColor),
      home: const SchedulePage(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness, Color seedColor) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      foregroundColor: colorScheme.onSurface,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      dragHandleColor: colorScheme.outline,
    ),
  );
}

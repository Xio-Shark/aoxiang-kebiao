/// Riverpod Providers - 依赖注入与全局状态管理

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/course_color_palette.dart';
import '../../data/datasources/aoxiang_jiaowu_adapter.dart';
import '../../data/datasources/course_file_import_data_source.dart';
import '../../data/datasources/course_local_data_source.dart';
import '../../data/datasources/parsers/schedule_text_utils.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../data/services/course_reminder_service.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/section_time.dart';
import '../../domain/repositories/course_repository.dart';
import '../usecases/schedule_usecases.dart';

// ==================== Core Providers ====================

/// SharedPreferences Provider（在 main 中 override）
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('请在 main 中 override'),
);

// ==================== Data Layer ====================

/// 本地数据源 Provider
final localDataSourceProvider = Provider<CourseLocalDataSource>(
  (ref) => SharedPrefsDataSource(ref.watch(sharedPreferencesProvider)),
);

/// 文件导入数据源 Provider
final courseFileImportDataSourceProvider = Provider<CourseFileImportDataSource>(
  (ref) => LocalCourseFileImportDataSource(),
);

/// 翱翔教务适配器 Provider
final aoxiangJiaowuAdapterProvider = Provider<AoxiangJiaowuAdapter>(
  (ref) => AoxiangJiaowuAdapter(),
);

/// 系统级课前通知服务 Provider（全局单例）
final courseReminderServiceProvider = Provider<CourseReminderService>(
  (ref) => CourseReminderService(),
);

/// Repository Provider
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepositoryImpl(ref.watch(localDataSourceProvider)),
);

// ==================== UseCases ====================

final importScheduleUseCaseProvider = Provider<ImportScheduleUseCase>(
  (ref) => ImportScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

final getScheduleUseCaseProvider = Provider<GetScheduleUseCase>(
  (ref) => GetScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

final calculateWeekUseCaseProvider = Provider<CalculateCurrentWeekUseCase>(
  (ref) => CalculateCurrentWeekUseCase(ref.watch(courseRepositoryProvider)),
);

final manageCourseUseCaseProvider = Provider<ManageCourseUseCase>(
  (ref) => ManageCourseUseCase(ref.watch(courseRepositoryProvider)),
);

final settingsUseCaseProvider = Provider<SettingsUseCase>(
  (ref) => SettingsUseCase(ref.watch(courseRepositoryProvider)),
);

final mergeCoursesUseCaseProvider = Provider<MergeCoursesUseCase>(
  (ref) => MergeCoursesUseCase(ref.watch(courseRepositoryProvider)),
);

final checkConflictUseCaseProvider = Provider<CheckConflictUseCase>(
  (ref) => CheckConflictUseCase(ref.watch(courseRepositoryProvider)),
);

// ==================== Theme & Appearance ====================

/// 主题外观模式（跟随系统 / 浅色 / 深色）
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'app_theme_mode';
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_readInitial(_prefs));

  static ThemeMode _readInitial(SharedPreferences prefs) {
    final stored = prefs.getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.name);
  }
}

/// 主题强调色 Seed Color
final themeSeedColorProvider =
    StateNotifierProvider<ThemeSeedColorNotifier, int>(
  (ref) => ThemeSeedColorNotifier(ref.watch(sharedPreferencesProvider)),
);

class ThemeSeedColorNotifier extends StateNotifier<int> {
  static const String _key = 'app_theme_seed_color';
  static final int _defaultColor = CourseColorPalette.themePresets.first.seedColor;
  final SharedPreferences _prefs;

  ThemeSeedColorNotifier(this._prefs)
      : super(_prefs.getInt(_key) ?? _defaultColor);

  Future<void> setSeedColor(int colorValue) async {
    state = colorValue;
    await _prefs.setInt(_key, colorValue);
  }
}

// ==================== UI Preferences ====================

/// 背景透明度设置 Provider
final backgroundOpacityProvider =
    StateNotifierProvider<BackgroundOpacityNotifier, double>(
  (ref) => BackgroundOpacityNotifier(ref.watch(sharedPreferencesProvider)),
);

class BackgroundOpacityNotifier extends StateNotifier<double> {
  static const String _key = 'background_opacity';
  static const double _defaultValue = 0.82;

  final SharedPreferences _prefs;

  BackgroundOpacityNotifier(this._prefs) : super(_readInitial(_prefs));

  static double _readInitial(SharedPreferences prefs) {
    final storedValue = prefs.getDouble(_key) ?? _defaultValue;
    return _clamp(storedValue);
  }

  static double _clamp(double value) {
    return value.clamp(0.35, 1.0).toDouble();
  }

  Future<void> setOpacity(double value) async {
    final normalized = _clamp(value);
    state = normalized;
    await _prefs.setDouble(_key, normalized);
  }
}

/// 背景图路径设置 Provider
final backgroundImagePathProvider =
    StateNotifierProvider<BackgroundImagePathNotifier, String?>(
  (ref) => BackgroundImagePathNotifier(ref.watch(sharedPreferencesProvider)),
);

class BackgroundImagePathNotifier extends StateNotifier<String?> {
  static const String _key = 'background_image_path';

  final SharedPreferences _prefs;

  BackgroundImagePathNotifier(this._prefs) : super(_readInitial(_prefs));

  static String? _readInitial(SharedPreferences prefs) {
    final value = prefs.getString(_key)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> setPath(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = normalized;
    await _prefs.setString(_key, normalized);
  }

  Future<void> clear() async {
    state = null;
    await _prefs.remove(_key);
  }
}

/// 背景变换状态
class BackgroundTransformState {
  final double scale;
  final double offsetX;
  final double offsetY;

  const BackgroundTransformState({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  BackgroundTransformState copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
  }) {
    return BackgroundTransformState(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }
}

/// 背景变换设置 Provider
final backgroundTransformProvider = StateNotifierProvider<
    BackgroundTransformNotifier, BackgroundTransformState>(
  (ref) => BackgroundTransformNotifier(ref.watch(sharedPreferencesProvider)),
);

class BackgroundTransformNotifier
    extends StateNotifier<BackgroundTransformState> {
  static const String _scaleKey = 'background_scale';
  static const String _offsetXKey = 'background_offset_x';
  static const String _offsetYKey = 'background_offset_y';

  final SharedPreferences _prefs;

  BackgroundTransformNotifier(this._prefs) : super(_readInitial(_prefs));

  static BackgroundTransformState _readInitial(SharedPreferences prefs) {
    return BackgroundTransformState(
      scale: _clampScale(prefs.getDouble(_scaleKey) ?? 1.0),
      offsetX: _clampOffset(prefs.getDouble(_offsetXKey) ?? 0),
      offsetY: _clampOffset(prefs.getDouble(_offsetYKey) ?? 0),
    );
  }

  static double _clampScale(double value) {
    return value.clamp(1.0, 4.0).toDouble();
  }

  static double _clampOffset(double value) {
    return value.clamp(-2.0, 2.0).toDouble();
  }

  Future<void> update({
    required double scale,
    required double offsetX,
    required double offsetY,
  }) async {
    final next = BackgroundTransformState(
      scale: _clampScale(scale),
      offsetX: _clampOffset(offsetX),
      offsetY: _clampOffset(offsetY),
    );
    state = next;
    await _prefs.setDouble(_scaleKey, next.scale);
    await _prefs.setDouble(_offsetXKey, next.offsetX);
    await _prefs.setDouble(_offsetYKey, next.offsetY);
  }

  Future<void> reset() async {
    state = const BackgroundTransformState(scale: 1, offsetX: 0, offsetY: 0);
    await _prefs.setDouble(_scaleKey, 1);
    await _prefs.setDouble(_offsetXKey, 0);
    await _prefs.setDouble(_offsetYKey, 0);
  }
}

// ==================== State Providers ====================

/// 学期开学日期设置 Provider
final termStartDateProvider =
    StateNotifierProvider<TermStartDateNotifier, DateTime>(
  (ref) => TermStartDateNotifier(ref.watch(sharedPreferencesProvider)),
);

class TermStartDateNotifier extends StateNotifier<DateTime> {
  static const String _key = 'term_start';
  final SharedPreferences _prefs;

  TermStartDateNotifier(this._prefs) : super(_readInitial(_prefs));

  static DateTime _readInitial(SharedPreferences prefs) {
    final str = prefs.getString(_key);
    if (str != null && str.isNotEmpty) {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day)
            .subtract(Duration(days: parsed.weekday - 1));
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  Future<void> setDate(DateTime date) async {
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    state = monday;
    await _prefs.setString(_key, monday.toIso8601String());
  }

  Future<void> setThisWeekAsFirstWeek() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    state = monday;
    await _prefs.setString(_key, monday.toIso8601String());
  }
}

/// 当前实际周数 Provider（基于开学日期与当前实际日期精准计算）
final currentWeekProvider = Provider<int>((ref) {
  final termStart = ref.watch(termStartDateProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = DateTime(termStart.year, termStart.month, termStart.day);
  final diffDays = today.difference(monday).inDays;
  if (diffDays < 0) {
    return 1;
  }
  final week = (diffDays ~/ 7) + 1;
  return week.clamp(AppConstants.minWeek, AppConstants.maxWeek);
});

/// 当前选中周 Provider
final selectedWeekProvider = StateProvider<int>((ref) {
  return ref.watch(currentWeekProvider);
});

/// 给定周对应的7天实际日期列表 Provider
final weekDatesProvider = Provider.family<List<DateTime>, int>((ref, week) {
  final termStart = ref.watch(termStartDateProvider);
  final weekMonday = termStart.add(Duration(days: (week - 1) * 7));
  return List.generate(7, (i) => weekMonday.add(Duration(days: i)));
});

/// 给定周对应的月份文本 Provider
final weekMonthDisplayProvider = Provider.family<String, int>((ref, week) {
  final dates = ref.watch(weekDatesProvider(week));
  final startMonth = dates.first.month;
  final endMonth = dates.last.month;
  if (startMonth == endMonth) {
    return '$startMonth月';
  }
  return '$startMonth/\n$endMonth月';
});

/// 当前选中的周是否正是今天所在的真实周
final isCurrentWeekSelectedProvider = Provider<bool>((ref) {
  final selected = ref.watch(selectedWeekProvider);
  final current = ref.watch(currentWeekProvider);
  return selected == current;
});

/// 全学期课程列表 Provider（用于空状态判断、周次分布圆点、课程统计）
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final useCase = ref.watch(getScheduleUseCaseProvider);
  final result = await useCase.getAll();
  return result.when(
    success: (courses) => courses,
    failure: (failure) => throw StateError(failure.message),
  );
});

/// 课程列表 Provider（指定周，支持 PageView 多周预加载与缓存）
final weekScheduleProvider =
    FutureProvider.family<List<Course>, int>((ref, week) async {
  final useCase = ref.watch(getScheduleUseCaseProvider);
  final result = await useCase.getByWeek(week);

  return result.when(
    success: (courses) => courses,
    failure: (failure) => throw StateError(failure.message),
  );
});

/// 课程列表 Provider（当前选中周）
final scheduleProvider = FutureProvider<List<Course>>((ref) async {
  final selectedWeek = ref.watch(selectedWeekProvider);
  return ref.watch(weekScheduleProvider(selectedWeek).future);
});

/// 校区 Provider
final campusProvider = FutureProvider<String>((ref) async {
  final useCase = ref.watch(settingsUseCaseProvider);
  final result = await useCase.getCampus();

  return result.when(
    success: (campus) => campus,
    failure: (_) => '',
  );
});

// ==================== 作息时间表 & 系统课前提醒 ====================

/// 作息时间表 Provider（单一真相源，默认西工大长安校区 13 节）
final sectionTimeTableProvider =
    StateNotifierProvider<SectionTimeTableNotifier, SectionTimeTable>(
  (ref) => SectionTimeTableNotifier(ref.watch(sharedPreferencesProvider)),
);

class SectionTimeTableNotifier extends StateNotifier<SectionTimeTable> {
  static const String _key = 'section_time_table_v1';
  final SharedPreferences _prefs;

  SectionTimeTableNotifier(this._prefs) : super(_readInitial(_prefs)) {
    ScheduleTextUtils.activeTimeTable = state;
  }

  static SectionTimeTable _readInitial(SharedPreferences prefs) {
    final stored = SectionTimeTable.fromJsonString(prefs.getString(_key));
    return stored ?? SectionTimeTable.nwpuChangan;
  }

  Future<void> applyPreset(SectionTimeTable preset) async {
    state = preset;
    ScheduleTextUtils.activeTimeTable = preset;
    await _prefs.setString(_key, preset.toJsonString());
  }

  Future<void> updateSlot(SectionTimeSlot slot) async {
    final next = state.updateSlot(slot);
    state = next;
    ScheduleTextUtils.activeTimeTable = next;
    await _prefs.setString(_key, next.toJsonString());
  }
}

/// 课前系统提醒配置 Provider
final reminderSettingsProvider =
    StateNotifierProvider<ReminderSettingsNotifier, CourseReminderSettings>(
  (ref) => ReminderSettingsNotifier(ref.watch(sharedPreferencesProvider)),
);

class ReminderSettingsNotifier extends StateNotifier<CourseReminderSettings> {
  static const String _enabledKey = 'course_reminder_enabled';
  static const String _leadMinutesKey = 'course_reminder_lead_minutes';
  static const String _soundKey = 'course_reminder_sound';
  final SharedPreferences _prefs;

  ReminderSettingsNotifier(this._prefs) : super(_readInitial(_prefs));

  static CourseReminderSettings _readInitial(SharedPreferences prefs) {
    return CourseReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      leadMinutes: (prefs.getInt(_leadMinutesKey) ?? 15).clamp(1, 60),
      soundEnabled: prefs.getBool(_soundKey) ?? true,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setLeadMinutes(int minutes) async {
    final clamped = minutes.clamp(1, 60);
    state = state.copyWith(leadMinutes: clamped);
    await _prefs.setInt(_leadMinutesKey, clamped);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _prefs.setBool(_soundKey, enabled);
  }
}

/// 最近一次提醒同步状态报告（用于在设置页展示已预约节数及下一节提醒时间）
final reminderSyncReportProvider = StateProvider<ReminderSyncReport?>((ref) {
  return null;
});

/// 统一失效全部课表缓存（修复导入/修改后已缓存周视图不刷新的问题）
void invalidateAllScheduleCaches(WidgetRef ref) {
  ref.invalidate(allCoursesProvider);
  ref.invalidate(scheduleProvider);
  for (var w = AppConstants.minWeek; w <= AppConstants.maxWeek; w++) {
    ref.invalidate(weekScheduleProvider(w));
  }
}

/// 同步系统级课前提醒排程（课表导入/修改/切换作息/修改开学日期后自动调用）
Future<ReminderSyncReport> syncCourseReminders(WidgetRef ref) async {
  final settings = ref.read(reminderSettingsProvider);
  final service = ref.read(courseReminderServiceProvider);
  final termStart = ref.read(termStartDateProvider);
  final timeTable = ref.read(sectionTimeTableProvider);

  final allResult = await ref.read(getScheduleUseCaseProvider).getAll();
  final courses = allResult.when(
    success: (data) => data,
    failure: (_) => const <Course>[],
  );

  final report = await service.syncScheduleReminders(
    courses: courses,
    termStartDate: termStart,
    timeTable: timeTable,
    settings: settings,
  );
  ref.read(reminderSyncReportProvider.notifier).state = report;
  return report;
}

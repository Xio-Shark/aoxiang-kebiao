/// Riverpod Providers - 依赖注入
/// 提供全局可访问的 UseCases 和 Repository

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/aoxiang_jiaowu_adapter.dart';
import '../../data/datasources/course_file_import_data_source.dart';
import '../../data/datasources/course_local_data_source.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../usecases/schedule_usecases.dart';

// ==================== Core Providers ====================

/// SharedPreferences Provider
/// 在 main 中 override
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

/// Repository Provider
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepositoryImpl(ref.watch(localDataSourceProvider)),
);

// ==================== UseCases ====================

/// 导入课程 UseCase Provider
final importScheduleUseCaseProvider = Provider<ImportScheduleUseCase>(
  (ref) => ImportScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

/// 获取课程表 UseCase Provider
final getScheduleUseCaseProvider = Provider<GetScheduleUseCase>(
  (ref) => GetScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

/// 计算当前周 UseCase Provider
final calculateWeekUseCaseProvider = Provider<CalculateCurrentWeekUseCase>(
  (ref) => CalculateCurrentWeekUseCase(ref.watch(courseRepositoryProvider)),
);

/// 管理课程 UseCase Provider
final manageCourseUseCaseProvider = Provider<ManageCourseUseCase>(
  (ref) => ManageCourseUseCase(ref.watch(courseRepositoryProvider)),
);

/// 设置 UseCase Provider
final settingsUseCaseProvider = Provider<SettingsUseCase>(
  (ref) => SettingsUseCase(ref.watch(courseRepositoryProvider)),
);

/// 合并课程 UseCase Provider
final mergeCoursesUseCaseProvider = Provider<MergeCoursesUseCase>(
  (ref) => MergeCoursesUseCase(ref.watch(courseRepositoryProvider)),
);

/// 冲突检测 UseCase Provider
final checkConflictUseCaseProvider = Provider<CheckConflictUseCase>(
  (ref) => CheckConflictUseCase(ref.watch(courseRepositoryProvider)),
);

// ==================== UI Preferences ====================

/// 背景透明度设置 Provider
final backgroundOpacityProvider =
    StateNotifierProvider<BackgroundOpacityNotifier, double>(
  (ref) => BackgroundOpacityNotifier(ref.watch(sharedPreferencesProvider)),
);

/// 背景透明度设置控制器
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

/// 背景图路径设置控制器
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
final backgroundTransformProvider =
    StateNotifierProvider<BackgroundTransformNotifier, BackgroundTransformState>(
  (ref) => BackgroundTransformNotifier(ref.watch(sharedPreferencesProvider)),
);

/// 背景变换设置控制器
class BackgroundTransformNotifier extends StateNotifier<BackgroundTransformState> {
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

/// 学期开学日期设置控制器
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
    // 默认推算：以当前周周一作为第 1 周周一
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
  return week.clamp(1, 25);
});

/// 当前选中周 Provider（同步，默认初始化为当前实际周）
final selectedWeekProvider = StateProvider<int>((ref) {
  return ref.watch(currentWeekProvider);
});

/// 给定周对应的7天实际日期列表 Provider
final weekDatesProvider = Provider.family<List<DateTime>, int>((ref, week) {
  final termStart = ref.watch(termStartDateProvider);
  final weekMonday = termStart.add(Duration(days: (week - 1) * 7));
  return List.generate(7, (i) => weekMonday.add(Duration(days: i)));
});

/// 给定周对应的月份文本 Provider（例如 "9月" 或 "9/\n10月"）
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

/// 课程列表 Provider（指定周，支持 PageView 多周顺畅预加载与缓存）
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

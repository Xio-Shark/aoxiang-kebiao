/// Riverpod Providers - 依赖注入
/// 提供全局可访问的 UseCases 和 Repository

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// 当前周 Provider（异步）
final currentWeekProvider = FutureProvider<int>((ref) async {
  final useCase = ref.watch(calculateWeekUseCaseProvider);
  final result = await useCase.execute();

  return result.when(
    success: (week) => week,
    failure: (_) => 1,
  );
});

/// 当前选中周 Provider（同步，用于 UI 状态）
final selectedWeekProvider = StateProvider<int>((ref) {
  final currentWeekAsync = ref.watch(currentWeekProvider);
  return currentWeekAsync.when(
    data: (week) => week,
    loading: () => 1,
    error: (_, __) => 1,
  );
});

/// 课程列表 Provider（当前选中周）
final scheduleProvider = FutureProvider<List<Course>>((ref) async {
  final selectedWeek = ref.watch(selectedWeekProvider);
  final useCase = ref.watch(getScheduleUseCaseProvider);

  final result = await useCase.getByWeek(selectedWeek);

  return result.when(
    success: (courses) => courses,
    failure: (_) => [],
  );
});

/// 学期开始日期 Provider
final termStartDateProvider = FutureProvider<DateTime?>((ref) async {
  final useCase = ref.watch(settingsUseCaseProvider);
  final result = await useCase.getTermStartDate();

  return result.when(
    success: (date) => date,
    failure: (_) => null,
  );
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

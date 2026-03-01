/// Riverpod Providers - 依赖注入
/// 提供全局可访问的UseCases和Repository

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/course_local_data_source.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/repositories/course_repository.dart';
import '../usecases/schedule_usecases.dart';

// ==================== Core Providers ====================

/// SharedPreferences Provider
/// 在main中override
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('请在main中override'),
);

// ==================== Data Layer ====================

/// 本地数据源Provider
final localDataSourceProvider = Provider<CourseLocalDataSource>(
  (ref) => SharedPrefsDataSource(ref.watch(sharedPreferencesProvider)),
);

/// Repository Provider
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepositoryImpl(ref.watch(localDataSourceProvider)),
);

// ==================== UseCases ====================

/// 导入课程UseCase Provider
final importScheduleUseCaseProvider = Provider<ImportScheduleUseCase>(
  (ref) => ImportScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

/// 获取课程表UseCase Provider
final getScheduleUseCaseProvider = Provider<GetScheduleUseCase>(
  (ref) => GetScheduleUseCase(ref.watch(courseRepositoryProvider)),
);

/// 计算当前周UseCase Provider
final calculateWeekUseCaseProvider = Provider<CalculateCurrentWeekUseCase>(
  (ref) => CalculateCurrentWeekUseCase(ref.watch(courseRepositoryProvider)),
);

/// 管理课程UseCase Provider
final manageCourseUseCaseProvider = Provider<ManageCourseUseCase>(
  (ref) => ManageCourseUseCase(ref.watch(courseRepositoryProvider)),
);

/// 设置UseCase Provider
final settingsUseCaseProvider = Provider<SettingsUseCase>(
  (ref) => SettingsUseCase(ref.watch(courseRepositoryProvider)),
);

/// 合并课程UseCase Provider
final mergeCoursesUseCaseProvider = Provider<MergeCoursesUseCase>(
  (ref) => MergeCoursesUseCase(ref.watch(courseRepositoryProvider)),
);

/// 冲突检测UseCase Provider
final checkConflictUseCaseProvider = Provider<CheckConflictUseCase>(
  (ref) => CheckConflictUseCase(ref.watch(courseRepositoryProvider)),
);

// ==================== State Providers ====================

/// 当前周Provider（异步）
final currentWeekProvider = FutureProvider<int>((ref) async {
  final useCase = ref.watch(calculateWeekUseCaseProvider);
  final result = await useCase.execute();
  
  return result.when(
    success: (week) => week,
    failure: (_) => 1, // 默认第1周
  );
});

/// 当前选中周Provider（同步，用于UI状态）
final selectedWeekProvider = StateProvider<int>((ref) {
  // 初始值从currentWeekProvider获取
  final currentWeekAsync = ref.watch(currentWeekProvider);
  return currentWeekAsync.when(
    data: (week) => week,
    loading: () => 1,
    error: (_, __) => 1,
  );
});

/// 课程列表Provider（当前选中周）
final scheduleProvider = FutureProvider<List<dynamic>>((ref) async {
  final selectedWeek = ref.watch(selectedWeekProvider);
  final useCase = ref.watch(getScheduleUseCaseProvider);
  
  final result = await useCase.getByWeek(selectedWeek);
  
  return result.when(
    success: (courses) => courses,
    failure: (_) => [],
  );
});

/// 学期开始日期Provider
final termStartDateProvider = FutureProvider<DateTime?>((ref) async {
  final useCase = ref.watch(settingsUseCaseProvider);
  final result = await useCase.getTermStartDate();
  
  return result.when(
    success: (date) => date,
    failure: (_) => null,
  );
});

/// 校区Provider
final campusProvider = FutureProvider<String>((ref) async {
  final useCase = ref.watch(settingsUseCaseProvider);
  final result = await useCase.getCampus();
  
  return result.when(
    success: (campus) => campus,
    failure: (_) => '',
  );
});

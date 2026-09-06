/// 本地数据源 - SharedPreferences实现
/// 对应原Android的SharedPreferencesUtils

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../models/course_model.dart';

abstract interface class CourseLocalDataSource {
  Future<Result<void>> saveCourses(List<CourseModel> courses);

  Future<Result<List<CourseModel>>> getCourses();

  Future<Result<void>> clearCourses();

  Future<Result<void>> saveTermStartDate(DateTime date);

  Future<Result<DateTime?>> getTermStartDate();

  Future<Result<void>> saveCampus(String campus);

  Future<Result<String>> getCampus();

  Future<Result<void>> saveWeekSnapshot(int week, List<CourseModel> courses);

  Future<Result<List<CourseModel>?>> getWeekSnapshot(int week);
}

/// SharedPreferences本地数据源实现
class SharedPrefsDataSource implements CourseLocalDataSource {
  final SharedPreferences _prefs;
  
  // 键名常量
  static const String _coursesKey = 'courses';
  static const String _termStartKey = 'term_start';
  static const String _campusKey = 'campus';
  
  SharedPrefsDataSource(this._prefs);
  
  void _clearSnapshots() {
    _memoryWeekCache.clear();
    final keys = _prefs.getKeys().where((k) => k.startsWith('snapshot_week_')).toList();
    for (final k in keys) {
      _prefs.remove(k);
    }
  }

  @override
  Future<Result<void>> saveCourses(List<CourseModel> courses) async {
    try {
      _clearSnapshots();
      final jsonList = courses.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_coursesKey, jsonString);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '保存课程失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<List<CourseModel>>> getCourses() async {
    try {
      final jsonString = _prefs.getString(_coursesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const Result.success([]);
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final courses = decoded
          .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      
      return Result.success(courses);
    } catch (e) {
      return Result.failure(
        Failure.parse(
          message: '读取课程失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<void>> clearCourses() async {
    try {
      _clearSnapshots();
      await _prefs.remove(_coursesKey);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '清空课程失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<void>> saveTermStartDate(DateTime date) async {
    try {
      await _prefs.setString(_termStartKey, date.toIso8601String());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '保存学期开始日期失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<DateTime?>> getTermStartDate() async {
    try {
      final dateString = _prefs.getString(_termStartKey);
      if (dateString == null) {
        return const Result.success(null);
      }
      
      final date = DateTime.tryParse(dateString);
      if (date == null) {
        return Result.failure(
          Failure.validation(
            message: '学期开始日期格式错误',
          ),
        );
      }
      
      return Result.success(date);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '读取学期开始日期失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<void>> saveCampus(String campus) async {
    try {
      await _prefs.setString(_campusKey, campus);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '保存校区失败: $e',
        ),
      );
    }
  }
  
  @override
  Future<Result<String>> getCampus() async {
    try {
      final campus = _prefs.getString(_campusKey) ?? '';
      return Result.success(campus);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '读取校区失败: $e',
        ),
      );
    }
  }

  static final Map<int, List<CourseModel>> _memoryWeekCache = {};

  @override
  Future<Result<void>> saveWeekSnapshot(int week, List<CourseModel> courses) async {
    try {
      _memoryWeekCache[week] = courses;
      final key = 'snapshot_week_$week';
      final jsonList = courses.map((e) => e.toJson()).toList();
      await _prefs.setString(key, jsonEncode(jsonList));
      return const Result.success(null);
    } catch (e) {
      return Result.failure(
        Failure.storage(
          message: '保存周快照失败: $e',
        ),
      );
    }
  }

  @override
  Future<Result<List<CourseModel>?>> getWeekSnapshot(int week) async {
    try {
      if (_memoryWeekCache.containsKey(week)) {
        return Result.success(_memoryWeekCache[week]);
      }
      final key = 'snapshot_week_$week';
      final jsonString = _prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        return const Result.success(null);
      }
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final courses = decoded
          .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _memoryWeekCache[week] = courses;
      return Result.success(courses);
    } catch (e) {
      return Result.failure(
        Failure.parse(
          message: '读取周快照失败: $e',
        ),
      );
    }
  }
  
  /// 从旧版格式迁移
  /// 原Android格式: [{"name": "高数", "room": "A101", ...}]
  Future<Result<List<CourseModel>>> migrateFromLegacy() async {
    try {
      final jsonString = _prefs.getString(_coursesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const Result.success([]);
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final courses = decoded
          .map((e) => CourseModel.fromLegacyJson(e as Map<String, dynamic>))
          .toList();
      
      return Result.success(courses);
    } catch (e) {
      return Result.failure(
        Failure.parse(
          message: '从旧版格式迁移失败: $e',
        ),
      );
    }
  }
}

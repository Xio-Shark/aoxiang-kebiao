/// 本地数据源 - SharedPreferences实现
/// 对应原Android的SharedPreferencesUtils

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../models/course_model.dart';
import 'course_local_data_source.dart';

/// SharedPreferences本地数据源实现
class SharedPrefsDataSource implements CourseLocalDataSource {
  final SharedPreferences _prefs;
  
  // 键名常量
  static const String _coursesKey = 'courses';
  static const String _termStartKey = 'term_start';
  static const String _campusKey = 'campus';
  
  SharedPrefsDataSource(this._prefs);
  
  @override
  Future<Result<void>> saveCourses(List<CourseModel> courses) async {
    try {
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

/// UseCases - 应用层业务逻辑
/// 每个UseCase对应一个单一的业务操作

import '../../core/result/result.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';

/// 导入课程表UseCase
class ImportScheduleUseCase {
  final CourseRepository _repository;
  
  ImportScheduleUseCase(this._repository);
  
  /// 执行导入
  /// 
  /// [courses]：要导入的课程列表
  /// [replaceExisting]：是否替换现有课程
  Future<Result<void>> execute(
    List<Course> courses, {
    bool replaceExisting = false,
  }) async {
    return _repository.importCourses(courses, replaceExisting: replaceExisting);
  }
}

/// 获取课程表UseCase
class GetScheduleUseCase {
  final CourseRepository _repository;
  
  GetScheduleUseCase(this._repository);
  
  /// 获取指定周的课程
  Future<Result<List<Course>>> getByWeek(int week) async {
    return _repository.getCoursesByWeek(week);
  }
  
  /// 获取所有课程
  Future<Result<List<Course>>> getAll() async {
    return _repository.getAllCourses();
  }
  
  /// 获取指定星期和节次的课程
  Future<Result<List<Course>>> getByWeekdayAndSection(
    int weekday,
    int section,
  ) async {
    return _repository.getCoursesByWeekdayAndSection(weekday, section);
  }
}

/// 计算当前周UseCase
class CalculateCurrentWeekUseCase {
  final CourseRepository _repository;
  
  CalculateCurrentWeekUseCase(this._repository);
  
  /// 计算当前周次
  Future<Result<int>> execute() async {
    return _repository.calculateCurrentWeek();
  }
  
  /// 检查指定周是否在学期内
  Future<Result<bool>> isValidWeek(int week) async {
    final coursesResult = await _repository.getAllCourses();
    
    return coursesResult.mapSuccess((courses) {
      if (courses.isEmpty) return false;
      
      final maxWeek = courses
          .map((c) => c.endWeek)
          .reduce((max, w) => w > max ? w : max);
      
      return week >= 1 && week <= maxWeek;
    });
  }
}

/// 管理课程UseCase（增删改）
class ManageCourseUseCase {
  final CourseRepository _repository;
  
  ManageCourseUseCase(this._repository);
  
  /// 添加课程
  Future<Result<Course>> add(Course course) async {
    return _repository.addCourse(course);
  }
  
  /// 更新课程
  Future<Result<Course>> update(Course course) async {
    return _repository.updateCourse(course);
  }
  
  /// 删除课程
  Future<Result<void>> delete(String id) async {
    return _repository.deleteCourse(id);
  }
  
  /// 获取单个课程
  Future<Result<Course>> getById(String id) async {
    return _repository.getCourseById(id);
  }
}

/// 设置UseCase
class SettingsUseCase {
  final CourseRepository _repository;
  
  SettingsUseCase(this._repository);
  
  /// 设置学期开始日期
  Future<Result<void>> setTermStartDate(DateTime date) async {
    return _repository.setTermStartDate(date);
  }
  
  /// 获取学期开始日期
  Future<Result<DateTime?>> getTermStartDate() async {
    return _repository.getTermStartDate();
  }
  
  /// 设置校区
  Future<Result<void>> setCampus(String campus) async {
    return _repository.setCampus(campus);
  }
  
  /// 获取校区
  Future<Result<String>> getCampus() async {
    return _repository.getCampus();
  }
  
  /// 清空所有数据
  Future<Result<void>> clearAll() async {
    return _repository.clearAllCourses();
  }
}

/// 课程合并UseCase
class MergeCoursesUseCase {
  final CourseRepository _repository;
  
  MergeCoursesUseCase(this._repository);
  
  /// 合并相邻的同名同教室课程
  Future<Result<List<Course>>> execute(List<Course> courses) async {
    return _repository.mergeAdjacentCourses(courses);
  }
  
  /// 获取合并后的课程表
  Future<Result<List<Course>>> getMergedSchedule(int week) async {
    final result = await _repository.getCoursesByWeek(week);
    
    return result.when(
      success: (courses) async {
        final merged = await _repository.mergeAdjacentCourses(courses);
        return merged;
      },
      failure: Result.failure,
    );
  }
}

/// 冲突检测UseCase
class CheckConflictUseCase {
  final CourseRepository _repository;
  
  CheckConflictUseCase(this._repository);
  
  /// 检查课程是否与现有课程冲突
  Future<Result<List<Course>>> findConflicts(Course course) async {
    final allResult = await _repository.getAllCourses();
    
    return allResult.mapSuccess((courses) {
      return courses.where((c) {
        // 排除自己
        if (c.id == course.id) return false;
        
        // 检查时间冲突
        return c.hasTimeConflictWith(course);
      }).toList();
    });
  }
  
  /// 检查是否存在冲突
  Future<Result<bool>> hasConflict(Course course) async {
    final conflictsResult = await findConflicts(course);
    return conflictsResult.mapSuccess((conflicts) => conflicts.isNotEmpty);
  }
}

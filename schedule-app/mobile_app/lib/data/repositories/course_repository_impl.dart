import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/course_local_data_source.dart';
import '../models/course_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseLocalDataSource _localDataSource;

  const CourseRepositoryImpl(this._localDataSource);

  @override
  Future<Result<void>> importCourses(
    List<Course> courses, {
    bool replaceExisting = false,
  }) async {
    final nextCourses = <CourseModel>[];

    if (!replaceExisting) {
      final existingResult = await _localDataSource.getCourses();
      final existing = existingResult.when<List<CourseModel>?>(
        success: (courses) => courses,
        failure: (_) => null,
      );
      if (existing == null) {
        return existingResult.when<Result<void>>(
          success: (_) => const Result.success(null),
          failure: (failure) => Result.failure(failure),
        );
      }
      nextCourses.addAll(existing);
    }

    nextCourses.addAll(courses.map(CourseModel.fromEntity));
    return _localDataSource.saveCourses(_dedupeById(nextCourses));
  }

  @override
  Future<Result<List<Course>>> getAllCourses() async {
    final result = await _localDataSource.getCourses();
    switch (result) {
      case Success(:final data):
        return Result.success(data.map((c) => c.toEntity()).toList());
      case FailureResult(:final failureValue):
        return Result.failure(failureValue);
    }
  }

  @override
  Future<Result<List<Course>>> getCoursesByWeek(int week) async {
    // 优先尝试读取周快照缓存实现秒开
    final snapshotResult = await _localDataSource.getWeekSnapshot(week);
    final snapshot = snapshotResult.when<List<CourseModel>?>(
      success: (data) => data,
      failure: (_) => null,
    );
    if (snapshot != null && snapshot.isNotEmpty) {
      // 异步在微任务中刷新校验
      _refreshWeekSnapshotInBackground(week);
      final courses = snapshot.map((e) => e.toEntity()).toList()
        ..sort(_compareCoursePosition);
      return Result.success(courses);
    }

    final result = await getAllCourses();
    return result.mapSuccess((courses) {
      final weekCourses = courses
          .where((course) => course.isVisibleInWeek(week))
          .toList()
        ..sort(_compareCoursePosition);
      
      // 保存至快照
      _localDataSource.saveWeekSnapshot(
        week,
        weekCourses.map(CourseModel.fromEntity).toList(),
      );
      return weekCourses;
    });
  }

  void _refreshWeekSnapshotInBackground(int week) {
    Future.microtask(() async {
      final all = await getAllCourses();
      all.mapSuccess((courses) {
        final weekCourses = courses
            .where((course) => course.isVisibleInWeek(week))
            .toList()
          ..sort(_compareCoursePosition);
        _localDataSource.saveWeekSnapshot(
          week,
          weekCourses.map(CourseModel.fromEntity).toList(),
        );
      });
    });
  }

  @override
  Future<Result<List<Course>>> getCoursesByWeekdayAndSection(
    int weekday,
    int section,
  ) async {
    final result = await getAllCourses();
    return result.mapSuccess((courses) {
      return courses.where((course) {
        return course.weekday == weekday &&
            course.startSection <= section &&
            course.endSection >= section;
      }).toList();
    });
  }

  @override
  Future<Result<Course>> getCourseById(String id) async {
    final result = await getAllCourses();
    return result.when(
      success: (courses) {
        for (final course in courses) {
          if (course.id == id) {
            return Result.success(course);
          }
        }
        return Result.failure(
          Failure.validation(message: '未找到课程: $id'),
        );
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<Course>> addCourse(Course course) async {
    final allResult = await _localDataSource.getCourses();
    return allResult.when(
      success: (courses) async {
        final next = [...courses, CourseModel.fromEntity(course)];
        final saveResult = await _localDataSource.saveCourses(_dedupeById(next));
        return saveResult.when(
          success: (_) => Result.success(course),
          failure: (failure) => Result.failure(failure),
        );
      },
      failure: (failure) async => Result.failure(failure),
    );
  }

  @override
  Future<Result<Course>> updateCourse(Course course) async {
    final allResult = await _localDataSource.getCourses();
    switch (allResult) {
      case Success(:final data):
        var found = false;
        final next = data.map((item) {
          if (item.id != course.id) {
            return item;
          }
          found = true;
          return CourseModel.fromEntity(course);
        }).toList();

        if (!found) {
          return Result.failure(
            Failure.validation(message: '未找到要更新的课程: ${course.id}'),
          );
        }

        final saveResult = await _localDataSource.saveCourses(next);
        switch (saveResult) {
          case Success():
            return Result.success(course);
          case FailureResult(:final failureValue):
            return Result.failure(failureValue);
        }
      case FailureResult(:final failureValue):
        return Result.failure(failureValue);
    }
  }

  @override
  Future<Result<void>> deleteCourse(String id) async {
    final allResult = await _localDataSource.getCourses();
    switch (allResult) {
      case Success(:final data):
        final next = data.where((course) => course.id != id).toList();
        return _localDataSource.saveCourses(next);
      case FailureResult(:final failureValue):
        return Result.failure(failureValue);
    }
  }

  @override
  Future<Result<void>> clearAllCourses() {
    return _localDataSource.clearCourses();
  }

  @override
  Future<Result<void>> setTermStartDate(DateTime date) {
    return _localDataSource.saveTermStartDate(date);
  }

  @override
  Future<Result<DateTime?>> getTermStartDate() {
    return _localDataSource.getTermStartDate();
  }

  @override
  Future<Result<void>> setCampus(String campus) {
    return _localDataSource.saveCampus(campus);
  }

  @override
  Future<Result<String>> getCampus() {
    return _localDataSource.getCampus();
  }

  @override
  Future<Result<int>> calculateCurrentWeek() async {
    final termResult = await _localDataSource.getTermStartDate();
    return termResult.when(
      success: (termStart) {
        if (termStart == null) {
          return const Result.success(1);
        }

        final today = DateTime.now();
        final startDate = DateTime(
          termStart.year,
          termStart.month,
          termStart.day,
        );
        final currentDate = DateTime(today.year, today.month, today.day);
        final diffDays = currentDate.difference(startDate).inDays;
        if (diffDays < 0) {
          return const Result.success(1);
        }
        return Result.success((diffDays ~/ 7 + 1).clamp(1, 25).toInt());
      },
      failure: (failure) => Result.failure(failure),
    );
  }

  @override
  Future<Result<List<Course>>> mergeAdjacentCourses(List<Course> courses) async {
    final sorted = [...courses]..sort(_compareCoursePosition);
    final merged = <Course>[];

    for (final course in sorted) {
      if (merged.isNotEmpty && merged.last.canMergeWith(course)) {
        merged[merged.length - 1] = merged.last.mergeWith(course);
      } else {
        merged.add(course);
      }
    }

    return Result.success(merged);
  }

  List<CourseModel> _dedupeById(List<CourseModel> courses) {
    final byId = <String, CourseModel>{};
    for (final course in courses) {
      byId[course.id] = course;
    }
    return byId.values.toList()..sort(_compareCoursePosition);
  }
}

int _compareCoursePosition(Course a, Course b) {
  final weekdayCompare = a.weekday.compareTo(b.weekday);
  if (weekdayCompare != 0) {
    return weekdayCompare;
  }

  final sectionCompare = a.startSection.compareTo(b.startSection);
  if (sectionCompare != 0) {
    return sectionCompare;
  }

  return a.name.compareTo(b.name);
}

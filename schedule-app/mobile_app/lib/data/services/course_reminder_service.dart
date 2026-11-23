/// 系统级上课前提醒服务（基于 flutter_local_notifications）
/// 负责：
/// 1. 初始化 Android 通知渠道 / iOS 通知权限与本地时区
/// 2. 根据课表、学期第一周日期与当前作息时间表，精准计算未来 14 天内所有即将开始的课程
/// 3. 自动排程系统级课前通知（兼顾 Android 精确闹钟权限降级与 iOS 64 条上限）

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/section_time.dart';

/// 课前提醒配置
class CourseReminderSettings {
  const CourseReminderSettings({
    this.enabled = false,
    this.leadMinutes = 15,
    this.soundEnabled = true,
  });

  final bool enabled;
  final int leadMinutes;
  final bool soundEnabled;

  CourseReminderSettings copyWith({
    bool? enabled,
    int? leadMinutes,
    bool? soundEnabled,
  }) {
    return CourseReminderSettings(
      enabled: enabled ?? this.enabled,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

/// 单条待触发的课前提醒项（纯数据模型，便于单元测试与状态展示）
class ScheduledReminderEntry {
  const ScheduledReminderEntry({
    required this.notificationId,
    required this.course,
    required this.week,
    required this.classStart,
    required this.classEnd,
    required this.triggerAt,
    required this.title,
    required this.body,
  });

  final int notificationId;
  final Course course;
  final int week;
  final DateTime classStart;
  final DateTime classEnd;
  final DateTime triggerAt;
  final String title;
  final String body;
}

/// 提醒排程同步结果
class ReminderSyncReport {
  const ReminderSyncReport({
    required this.scheduledCount,
    required this.usedExactAlarm,
    this.nextEntry,
  });

  final int scheduledCount;
  final bool usedExactAlarm;
  final ScheduledReminderEntry? nextEntry;
}

class CourseReminderService {
  CourseReminderService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'aoxiang_course_reminders';
  static const String channelName = '上课前提醒';
  static const String channelDescription = '在每节课开始前通过系统通知提醒上课时间与教室地点';
  static const int testNotificationId = 999901;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _tzInitialized = false;

  /// 纯函数：计算未来 [horizonDays] 天内需要发送的所有课前系统通知
  static List<ScheduledReminderEntry> buildUpcomingReminderEntries({
    required List<Course> courses,
    required DateTime termStartDate,
    required SectionTimeTable timeTable,
    required CourseReminderSettings settings,
    DateTime? now,
    int horizonDays = 14,
    int maxCount = 60,
  }) {
    if (!settings.enabled || courses.isEmpty) {
      return const [];
    }

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final termMonday = DateTime(
      termStartDate.year,
      termStartDate.month,
      termStartDate.day,
    ).subtract(Duration(days: termStartDate.weekday - 1));

    final entries = <ScheduledReminderEntry>[];

    for (var dayOffset = 0; dayOffset < horizonDays; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final diffDays = date.difference(termMonday).inDays;
      if (diffDays < 0) continue;

      final week = (diffDays ~/ 7) + 1;
      if (week < AppConstants.minWeek || week > AppConstants.maxWeek) {
        continue;
      }

      final weekday = date.weekday;
      for (final course in courses) {
        if (course.weekday != weekday || !course.isVisibleInWeek(week)) {
          continue;
        }

        final startSlot = timeTable.slotFor(course.startSection);
        final endSlot = timeTable.slotFor(course.endSection) ?? startSlot;
        if (startSlot == null || endSlot == null) continue;

        final classStart = DateTime(
          date.year,
          date.month,
          date.day,
          startSlot.startHour,
          startSlot.startMinute,
        );
        final classEnd = DateTime(
          date.year,
          date.month,
          date.day,
          endSlot.endHour,
          endSlot.endMinute,
        );
        final triggerAt =
            classStart.subtract(Duration(minutes: settings.leadMinutes));

        if (!triggerAt.isAfter(current)) {
          continue;
        }

        final placePart =
            course.classroom.isNotEmpty ? ' · ${course.classroom}' : '';
        final teacherPart =
            course.teacher.isNotEmpty ? ' · ${course.teacher}' : '';
        final title = '${settings.leadMinutes}分钟后上课：${course.name}';
        final body =
            '${course.sectionDisplayText} (${startSlot.startText}-${endSlot.endText})$placePart$teacherPart';

        entries.add(
          ScheduledReminderEntry(
            notificationId: _computeNotificationId(date, course),
            course: course,
            week: week,
            classStart: classStart,
            classEnd: classEnd,
            triggerAt: triggerAt,
            title: title,
            body: body,
          ),
        );
      }
    }

    entries.sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
    if (entries.length > maxCount) {
      return entries.sublist(0, maxCount);
    }
    return entries;
  }

  /// 初始化本地通知引擎与时区数据库
  Future<void> initialize() async {
    _ensureTimeZone();
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 向系统申请通知权限（Android 13+ 通知权限与精确闹钟权限 / iOS 通知权限）
  Future<bool> requestPermissions() async {
    await initialize();
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission() ?? true;
      // 尽量请求 Android 12+ 精确闹钟权限，用户未授权时仍可退回非精确排程
      try {
        final canExact = await android.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          await android.requestExactAlarmsPermission();
        }
      } catch (_) {}
      return granted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      return await macos?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  /// 全量重排课前系统通知
  Future<ReminderSyncReport> syncScheduleReminders({
    required List<Course> courses,
    required DateTime termStartDate,
    required SectionTimeTable timeTable,
    required CourseReminderSettings settings,
  }) async {
    await initialize();
    if (kIsWeb) {
      return const ReminderSyncReport(scheduledCount: 0, usedExactAlarm: false);
    }

    await _plugin.cancelAll();
    if (!settings.enabled) {
      return const ReminderSyncReport(scheduledCount: 0, usedExactAlarm: false);
    }

    final entries = buildUpcomingReminderEntries(
      courses: courses,
      termStartDate: termStartDate,
      timeTable: timeTable,
      settings: settings,
    );

    if (entries.isEmpty) {
      return const ReminderSyncReport(scheduledCount: 0, usedExactAlarm: false);
    }

    var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    var usedExact = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      try {
        final canExact = await android?.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          usedExact = false;
        }
      } catch (_) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        usedExact = false;
      }
    }

    final details = _buildDetails(soundEnabled: settings.soundEnabled);
    var scheduled = 0;

    for (final entry in entries) {
      try {
        final tzDate = tz.TZDateTime.from(entry.triggerAt, tz.local);
        await _plugin.zonedSchedule(
          entry.notificationId,
          entry.title,
          entry.body,
          tzDate,
          details,
          androidScheduleMode: scheduleMode,
          payload: entry.course.id,
        );
        scheduled++;
      } catch (_) {
        // 单条异常降级为非精确模式重试，保证不阻断其余排程
        try {
          final tzDate = tz.TZDateTime.from(entry.triggerAt, tz.local);
          await _plugin.zonedSchedule(
            entry.notificationId,
            entry.title,
            entry.body,
            tzDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: entry.course.id,
          );
          usedExact = false;
          scheduled++;
        } catch (_) {}
      }
    }

    return ReminderSyncReport(
      scheduledCount: scheduled,
      usedExactAlarm: usedExact,
      nextEntry: entries.first,
    );
  }

  /// 发送一条即时测试通知，便于用户立刻验证系统级弹窗与声音权限
  Future<void> sendTestNotification({
    required SectionTimeTable timeTable,
    required CourseReminderSettings settings,
  }) async {
    await initialize();
    if (kIsWeb) return;

    final firstSlot = timeTable.slotFor(1);
    final timeHint = firstSlot != null ? firstSlot.rangeText : '08:30-09:15';

    await _plugin.show(
      testNotificationId,
      '翱翔课表 · 课前系统提醒已就绪',
      '将在每节课前 ${settings.leadMinutes} 分钟推送提醒（当前作息：${timeTable.presetName}，第1节 $timeHint）',
      _buildDetails(soundEnabled: settings.soundEnabled),
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
  }

  NotificationDetails _buildDetails({required bool soundEnabled}) {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
      enableVibration: soundEnabled,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      styleInformation: const BigTextStyleInformation(''),
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  void _ensureTimeZone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    // 优先匹配设备本地 UTC 偏移（中国大陆 UTC+8 精确映射至 Asia/Shanghai）
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    final locationName = switch (offsetHours) {
      8 => 'Asia/Shanghai',
      9 => 'Asia/Tokyo',
      0 => 'UTC',
      _ => 'Asia/Shanghai',
    };
    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    _tzInitialized = true;
  }

  static int _computeNotificationId(DateTime date, Course course) {
    final dayKey = date.year * 10000 + date.month * 100 + date.day;
    var hash = dayKey * 31 + course.startSection * 17;
    for (var i = 0; i < course.id.length; i++) {
      hash = (hash * 31 + course.id.codeUnitAt(i)) & 0x3FFFFFFF;
    }
    return (hash % 900000) + 1000;
  }
}

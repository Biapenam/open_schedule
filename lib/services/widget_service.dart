import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../services/course_service.dart';

class WidgetService {
  // 必须和 AndroidManifest 中 receiver 的包名一致
  static const _widgetName = 'ScheduleWidgetProvider';
  static const _platform = MethodChannel('open_schedule/widget');

  final CourseService _courseService = CourseService();

  /// 初始化：设置 App Group ID（Android 上等同于包名）
  static Future<void> init() async {
    // Android 不需要 AppGroupId，仅 iOS 需要；这里保留调用以兼容
    await HomeWidget.setAppGroupId('com.example.schedule_app');
  }

  /// 推送今日课程数据到桌面小组件
  Future<void> updateWidget() async {
    try {
      final courses = await _courseService.loadCourses();
      final semesterStart = await _courseService.loadSemesterStart();
      final totalWeeks = await _courseService.loadTotalWeeks();
      final startTimes = await _courseService.loadSectionStartTimes();
      final duration = await _courseService.loadSectionDuration();

      final now = DateTime.now();
      final todayWeekday = now.weekday; // 1=周一

      int currentWeek = 1;
      if (semesterStart != null) {
        currentWeek =
            _courseService.currentWeek(semesterStart).clamp(1, totalWeeks);
      }

      // 筛选今天、本周的课程，按节次排序
      final todayCourses = courses
          .where((c) =>
              c.dayOfWeek == todayWeekday && c.weeks.contains(currentWeek))
          .toList()
        ..sort((a, b) => a.startSection.compareTo(b.startSection));

      // 构建 JSON
      final courseList = todayCourses.map((c) {
        final startIdx = c.startSection - 1;
        final endIdx = c.endSection - 1;
        final lastSectionIdx = endIdx < startTimes.length ? endIdx : startIdx;
        final startTime = startIdx < startTimes.length
            ? startTimes[startIdx]
            : (startIdx < defaultSectionStartTimes.length
                ? defaultSectionStartTimes[startIdx]
                : '08:00');
        final lastSectionStart = lastSectionIdx < startTimes.length
            ? startTimes[lastSectionIdx]
            : (lastSectionIdx < defaultSectionStartTimes.length
                ? defaultSectionStartTimes[lastSectionIdx]
                : '08:00');
        final endTime = _courseService.calcEndTime(lastSectionStart, duration);
        return {
          'name': c.name,
          'time': '$startTime-$endTime',
          'location': c.location,
        };
      }).toList();

      // 写入数据（home_widget Android 端对应 HomeWidgetPreferences）
      await HomeWidget.saveWidgetData<String>(
        'today_courses',
        jsonEncode(courseList),
      );

      // 通知 Android 刷新桌面组件
      await HomeWidget.updateWidget(
        androidName: _widgetName,
      );
    } catch (e) {
      // Widget 更新失败不应影响主应用
    }
  }

  Future<String> requestPinWidget() async {
    try {
      await updateWidget();
      return await _platform.invokeMethod<String>('requestPinWidget') ??
          'unknown';
    } on PlatformException catch (e) {
      return e.code;
    }
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';

class CourseService {
  static const _coursesKey = 'courses';
  static const _semesterStartKey = 'semester_start';
  static const _totalWeeksKey = 'total_weeks';
  static const _dailySectionsKey = 'daily_sections';
  static const _sectionTimesKey = 'section_times'; // 存自定义开始时间列表
  static const _sectionDurationKey = 'section_duration'; // 每节课时长（分钟）

  // ─── 课程 CRUD ───────────────────────────────────────────

  Future<List<Course>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coursesKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .where((course) => course.id.isNotEmpty && course.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCourses(List<Course> courses) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(courses.map((c) => c.toJson()).toList());
    await prefs.setString(_coursesKey, raw);
  }

  Future<void> addCourse(Course course) async {
    final courses = await loadCourses();
    courses.add(course);
    await saveCourses(courses);
  }

  Future<void> updateCourse(Course updated) async {
    final courses = await loadCourses();
    final idx = courses.indexWhere((c) => c.id == updated.id);
    if (idx != -1) courses[idx] = updated;
    await saveCourses(courses);
  }

  Future<void> deleteCourse(String id) async {
    final courses = await loadCourses();
    courses.removeWhere((c) => c.id == id);
    await saveCourses(courses);
  }

  // ─── 学期设置 ─────────────────────────────────────────────

  Future<DateTime?> loadSemesterStart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_semesterStartKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveSemesterStart(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_semesterStartKey, date.toIso8601String());
  }

  Future<int> loadTotalWeeks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalWeeksKey) ?? 20;
  }

  Future<void> saveTotalWeeks(int weeks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalWeeksKey, weeks);
  }

  // ─── 每日节数 ─────────────────────────────────────────────

  Future<int> loadDailySections() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailySectionsKey) ?? 12;
  }

  Future<void> saveDailySections(int sections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailySectionsKey, sections);
  }

  // ─── 节次时间设置 ──────────────────────────────────────────

  /// 加载每节课开始时间列表（格式 "HH:mm"），不存在则返回默认值
  Future<List<String>> loadSectionStartTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sectionTimesKey);
    if (raw == null) return List<String>.from(defaultSectionStartTimes);
    return List<String>.from(jsonDecode(raw));
  }

  Future<void> saveSectionStartTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sectionTimesKey, jsonEncode(times));
  }

  /// 每节课时长（分钟）
  Future<int> loadSectionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sectionDurationKey) ?? 45;
  }

  Future<void> saveSectionDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sectionDurationKey, minutes);
  }

  // ─── 工具方法 ─────────────────────────────────────────────

  /// 根据开始时间和时长计算结束时间字符串
  String calcEndTime(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final total = h * 60 + m + durationMinutes;
    final eh = total ~/ 60;
    final em = total % 60;
    return '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  int currentWeek(DateTime semesterStart) {
    final now = DateTime.now();
    final diff = now.difference(semesterStart).inDays;
    if (diff < 0) return 1;
    return (diff ~/ 7) + 1;
  }

  List<Course> coursesForWeek(List<Course> all, int week) {
    return all.where((c) => c.weeks.contains(week)).toList();
  }
}

// 默认节次开始时间（12节）
const List<String> defaultSectionStartTimes = [
  '08:00',
  '08:55',
  '09:50',
  '10:55',
  '11:50',
  '13:30',
  '14:25',
  '15:20',
  '16:15',
  '18:30',
  '19:25',
  '20:20',
];

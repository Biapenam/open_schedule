import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/schedule.dart';

class CourseService {
  static const _schedulesKey = 'schedules';
  static const _activeScheduleIdKey = 'active_schedule_id';

  // 旧的全局 key（用于一次性迁移）
  static const _legacyCoursesKey = 'courses';
  static const _legacySemesterStartKey = 'semester_start';
  static const _legacyTotalWeeksKey = 'total_weeks';
  static const _legacyDailySectionsKey = 'daily_sections';
  static const _legacySectionTimesKey = 'section_times';
  static const _legacySectionDurationKey = 'section_duration';

  static const _uuid = Uuid();
  static Future<void> _writeQueue = Future<void>.value();
  bool _migrated = false;

  Future<T> _serializeWrite<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  String _coursesKey(String scheduleId) => 'courses_$scheduleId';

  // ─── 迁移与初始化 ──────────────────────────────────────────

  /// 确保数据已迁移到多课表结构。App 启动时调用一次即可。
  Future<void> ensureMigrated() async {
    if (_migrated) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_schedulesKey) == null) {
      await _migrateFromLegacy(prefs);
    }
    _migrated = true;
  }

  Future<void> _migrateFromLegacy(SharedPreferences prefs) async {
    final rawCourses = prefs.getString(_legacyCoursesKey);
    final rawStart = prefs.getString(_legacySemesterStartKey);
    final totalWeeks = prefs.getInt(_legacyTotalWeeksKey) ?? 20;
    final dailySections = prefs.getInt(_legacyDailySectionsKey) ?? 12;
    final rawTimes = prefs.getString(_legacySectionTimesKey);
    final duration = prefs.getInt(_legacySectionDurationKey) ?? 45;

    DateTime? start;
    if (rawStart != null) start = DateTime.tryParse(rawStart);

    List<String> times = List<String>.from(defaultSectionStartTimes);
    if (rawTimes != null) {
      try {
        final decoded = jsonDecode(rawTimes);
        if (decoded is List) {
          times = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // 使用默认时间，避免损坏的旧配置阻塞应用启动。
      }
    }

    final id = _uuid.v4();
    final schedule = Schedule(
      id: id,
      name: '我的课表',
      semesterStart: start,
      totalWeeks: totalWeeks,
      dailySections: dailySections,
      sectionStartTimes: times,
      sectionDuration: duration,
    );

    await prefs.setString(_schedulesKey, jsonEncode([schedule.toJson()]));
    await prefs.setString(_activeScheduleIdKey, id);

    // 迁移课程到 schedule 专属 key
    if (rawCourses != null) {
      try {
        final decoded = jsonDecode(rawCourses);
        if (decoded is List) {
          final courses = decoded
              .whereType<Map<String, dynamic>>()
              .map(Course.fromJson)
              .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
              .toList();
          await prefs.setString(_coursesKey(id),
              jsonEncode(courses.map((c) => c.toJson()).toList()));
        }
      } catch (_) {}
    }

    // 清理旧的全局 key
    await prefs.remove(_legacyCoursesKey);
    await prefs.remove(_legacySemesterStartKey);
    await prefs.remove(_legacyTotalWeeksKey);
    await prefs.remove(_legacyDailySectionsKey);
    await prefs.remove(_legacySectionTimesKey);
    await prefs.remove(_legacySectionDurationKey);
  }

  // ─── 课表（学期）管理 ─────────────────────────────────────

  Future<List<Schedule>> loadSchedules() async {
    await ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Schedule.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSchedules(List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _schedulesKey, jsonEncode(schedules.map((s) => s.toJson()).toList()));
  }

  Future<String?> getActiveScheduleId() async {
    await ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeScheduleIdKey);
  }

  Future<void> setActiveScheduleId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeScheduleIdKey, id);
  }

  /// 获取当前激活的课表。若 active id 失效则回退到第一个。
  Future<Schedule?> getActiveSchedule() async {
    final schedules = await loadSchedules();
    if (schedules.isEmpty) return null;
    final id = await getActiveScheduleId();
    if (id == null) return schedules.first;
    return schedules.firstWhere((s) => s.id == id,
        orElse: () => schedules.first);
  }

  /// 切换当前激活课表
  Future<void> setActiveSchedule(String id) async {
    await setActiveScheduleId(id);
  }

  /// 创建新课表，返回创建的课表（不自动切换）
  Future<Schedule> createSchedule(String name) async {
    return _serializeWrite(() async {
      final schedules = await loadSchedules();
      final schedule = Schedule(
        id: _uuid.v4(),
        name: name.trim().isEmpty ? '新课表' : name.trim(),
      );
      await _saveSchedules([...schedules, schedule]);
      return schedule;
    });
  }

  /// 重命名课表
  Future<void> renameSchedule(String id, String name) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final idx = schedules.indexWhere((s) => s.id == id);
      if (idx == -1) return;
      schedules[idx] = schedules[idx].copyWith(name: name);
      await _saveSchedules(schedules);
    });
  }

  /// 删除课表（至少保留一个）。若删除的是当前激活课表，自动切换。
  Future<void> deleteSchedule(String id) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final remaining = schedules.where((s) => s.id != id).toList();
      if (remaining.isEmpty) return; // 至少保留一个课表
      await _saveSchedules(remaining);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_coursesKey(id));
      final activeId = await getActiveScheduleId();
      if (activeId == id) await setActiveScheduleId(remaining.first.id);
    });
  }

  /// 更新某个课表的元数据（不存在则新增）
  Future<void> saveScheduleMeta(Schedule updated) async {
    await _serializeWrite(() async {
      final schedules = await loadSchedules();
      final idx = schedules.indexWhere((s) => s.id == updated.id);
      if (idx == -1) {
        await _saveSchedules([...schedules, updated]);
      } else {
        schedules[idx] = updated;
        await _saveSchedules(schedules);
      }
    });
  }

  // ─── 课程 CRUD（作用于当前激活课表） ───────────────────────

  Future<List<Course>> loadCourses() async {
    final id = await getActiveScheduleId();
    if (id == null) return [];
    return loadCoursesFor(id ?? '');
  }

  Future<List<Course>> loadCoursesFor(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coursesKey(scheduleId));
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
    await _serializeWrite(() async {
      final id = await getActiveScheduleId();
      if (id == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(courses.map((c) => c.toJson()).toList());
      await prefs.setString(_coursesKey(id), raw);
    });
  }

  Future<void> addCourse(Course course) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final id = await getActiveScheduleId();
      if (id == null) return;
      courses.add(course);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coursesKey(id), jsonEncode(courses.map((c) => c.toJson()).toList()));
    });
  }

  Future<void> updateCourse(Course updated) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final id = await getActiveScheduleId();
      if (id == null) return;
      final idx = courses.indexWhere((c) => c.id == updated.id);
      if (idx != -1) courses[idx] = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coursesKey(id), jsonEncode(courses.map((c) => c.toJson()).toList()));
    });
  }

  Future<void> deleteCourse(String id) async {
    await _serializeWrite(() async {
      final courses = await loadCourses();
      final activeId = await getActiveScheduleId();
      if (activeId == null) return;
      courses.removeWhere((c) => c.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_coursesKey(activeId), jsonEncode(courses.map((c) => c.toJson()).toList()));
    });
  }

  // ─── 学期设置（作用于当前激活课表元数据） ──────────────────

  Future<DateTime?> loadSemesterStart() async {
    final s = await getActiveSchedule();
    return s?.semesterStart;
  }

  Future<void> saveSemesterStart(DateTime date) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(semesterStart: date));
  }

  Future<int> loadTotalWeeks() async {
    final s = await getActiveSchedule();
    return s?.totalWeeks ?? 20;
  }

  Future<void> saveTotalWeeks(int weeks) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(totalWeeks: weeks));
  }

  // ─── 每日节数 ─────────────────────────────────────────────

  Future<int> loadDailySections() async {
    final s = await getActiveSchedule();
    return s?.dailySections ?? 12;
  }

  Future<void> saveDailySections(int sections) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(dailySections: sections));
  }

  // ─── 节次时间设置 ──────────────────────────────────────────

  /// 加载每节课开始时间列表（格式 "HH:mm"），不存在则返回默认值
  Future<List<String>> loadSectionStartTimes() async {
    final s = await getActiveSchedule();
    return s?.sectionStartTimes ?? List<String>.from(defaultSectionStartTimes);
  }

  Future<void> saveSectionStartTimes(List<String> times) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(sectionStartTimes: times));
  }

  /// 每节课时长（分钟）
  Future<int> loadSectionDuration() async {
    final s = await getActiveSchedule();
    return s?.sectionDuration ?? 45;
  }

  Future<void> saveSectionDuration(int minutes) async {
    final s = await getActiveSchedule();
    if (s == null) return;
    await saveScheduleMeta(s.copyWith(sectionDuration: minutes));
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

  /// 计算当前周（真实值，不 clamp）。
  /// 返回值可能 < 1（学期未开始）或 > totalWeeks（学期已结束），
  /// 调用方需自行判断是否在学期范围内。
  int currentWeek(DateTime semesterStart) {
    final now = DateTime.now();
    final diff = now.difference(semesterStart).inDays;
    if (diff < 0) return (diff ~/ 7) - 1;
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

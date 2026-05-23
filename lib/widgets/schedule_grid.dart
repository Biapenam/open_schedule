import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import 'course_detail_sheet.dart';
import 'dart:math' as math;

const double _cellHeight = 58.0;
const double _sectionLabelWidth = 34.0;

class ScheduleGrid extends StatefulWidget {
  final List<Course> courses;
  final bool isCurrentWeek;
  final VoidCallback onCourseDeleted;
  final VoidCallback onCourseEdited;
  final int totalWeeks;
  final int dailySections;
  final int weekNumber;
  final int currentWeek;

  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.isCurrentWeek,
    required this.onCourseDeleted,
    required this.onCourseEdited,
    required this.totalWeeks,
    required this.weekNumber,
    required this.currentWeek,
    this.dailySections = 12,
  });

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  final CourseService _service = CourseService();
  List<String> _startTimes = [];

  @override
  void initState() {
    super.initState();
    _loadTimes();
  }

  Future<void> _loadTimes() async {
    final times = await _service.loadSectionStartTimes();
    if (mounted) {
      setState(() {
        _startTimes = times;
      });
    }
  }

  String _getStartTime(int section) {
    final idx = section - 1;
    if (idx < _startTimes.length) return _startTimes[idx];
    if (idx < defaultSectionStartTimes.length)
      return defaultSectionStartTimes[idx];
    return '08:00';
  }

  /// 推算该周周一日期
  DateTime _getWeekMonday() {
    final now = DateTime.now();
    final todayMonday = now.subtract(Duration(days: now.weekday - 1));
    return todayMonday
        .add(Duration(days: (widget.weekNumber - widget.currentWeek) * 7));
  }

  /// 计算本周实际需要显示的天数（周末有课才显示）
  int _getVisibleDays() {
    final hasWeekend = widget.courses.any((c) => c.dayOfWeek >= 6);
    return hasWeekend ? 7 : 5;
  }

  @override
  Widget build(BuildContext context) {
    final todayWeekday = DateTime.now().weekday;
    final weekMonday = _getWeekMonday();
    final visibleDays = _getVisibleDays();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildHeader(todayWeekday, weekMonday, visibleDays),
            Expanded(
              child: SingleChildScrollView(
                child: _buildBody(todayWeekday, visibleDays),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 标题行 ─────────────────────────────────────────────────
  Widget _buildHeader(int todayWeekday, DateTime weekMonday, int visibleDays) {
    const dayChars = ['', '一', '二', '三', '四', '五', '六', '日'];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: _sectionLabelWidth),
          for (int d = 1; d <= visibleDays; d++)
            Expanded(
              child: Builder(builder: (context) {
                final dayDate = weekMonday.add(Duration(days: d - 1));
                final isToday = widget.isCurrentWeek && d == todayWeekday;
                final isWeekend = d >= 6;
                return Column(
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      '周${dayChars[d]}',
                      style: TextStyle(
                        color: isToday
                            ? Colors.white
                            : isWeekend
                                ? Colors.white54
                                : Colors.white70,
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    isToday
                        ? Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Center(
                              child: Text('${dayDate.day}',
                                  style: const TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ),
                          )
                        : Text('${dayDate.day}',
                            style: TextStyle(
                              color:
                                  isWeekend ? Colors.white38 : Colors.white60,
                              fontSize: 11,
                            )),
                    const SizedBox(height: 6),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  // ── 主体 ───────────────────────────────────────────────────
  Widget _buildBody(int todayWeekday, int visibleDays) {
    final totalHeight = _cellHeight * widget.dailySections;

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 节次标签列（固定宽度）
          SizedBox(
            width: _sectionLabelWidth,
            height: totalHeight,
            child: Column(
              children: List.generate(widget.dailySections, (i) {
                final section = i + 1;
                return Container(
                  height: _cellHeight,
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$section',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6C63FF).withOpacity(0.6),
                          )),
                      Text(_getStartTime(section),
                          style: const TextStyle(
                              fontSize: 8, color: Color(0xFFBBBBCC))),
                    ],
                  ),
                );
              }),
            ),
          ),
          // 每天的列，用 Expanded 平分剩余宽度
          for (int day = 1; day <= visibleDays; day++)
            Expanded(child: _buildDayColumn(day, todayWeekday, totalHeight)),
        ],
      ),
    );
  }

  // ── 单天列 ────────────────────────────────────────────────
  Widget _buildDayColumn(int day, int todayWeekday, double totalHeight) {
    final isToday = widget.isCurrentWeek && day == todayWeekday;
    final isWeekend = day >= 6;
    final dayCourses = widget.courses.where((c) => c.dayOfWeek == day).toList();

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 背景格线
          Column(
            children: List.generate(
                widget.dailySections,
                (i) => Container(
                      height: _cellHeight,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFF6C63FF).withOpacity(0.04)
                            : isWeekend
                                ? const Color(0xFF000000).withOpacity(0.01)
                                : Colors.transparent,
                        border: const Border(
                          bottom:
                              BorderSide(color: Color(0xFFEEEEF5), width: 1),
                          right:
                              BorderSide(color: Color(0xFFF5F5FA), width: 0.5),
                        ),
                      ),
                    )),
          ),
          // 课程块（绝对定位）
          for (final course in dayCourses)
            Positioned(
              top: (course.startSection - 1) * _cellHeight + 2,
              left: 2,
              right: 2,
              height:
                  (course.endSection - course.startSection + 1) * _cellHeight -
                      4,
              child: _CourseBlock(
                course: course,
                blockHeight: (course.endSection - course.startSection + 1) *
                        _cellHeight -
                    4,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CourseDetailSheet(
                    course: course,
                    onDeleted: widget.onCourseDeleted,
                    onEdited: widget.onCourseEdited,
                    totalWeeks: widget.totalWeeks,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 课程块（独立 StatelessWidget，用 LayoutBuilder 获取实际宽度）──
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double blockHeight;
  final VoidCallback onTap;

  const _CourseBlock({
    required this.course,
    required this.blockHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(course.colorValue);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.88), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 装饰圆
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // 内容：用 LayoutBuilder 获取实际列宽，动态调整字体
            LayoutBuilder(builder: (context, constraints) {
              return _buildContent(constraints.maxWidth, constraints.maxHeight);
            }),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: course.dayOfWeek * 60))
          .fadeIn(duration: 400.ms)
          .scaleXY(begin: 0.88, curve: Curves.easeOutBack),
    );
  }

  Widget _buildContent(double colWidth, double height) {
    // 可用空间
    final availW = colWidth - 8; // 左右各4px padding
    final availH = height - 8; // 上下各4px padding

    final hasLocation = course.location.isNotEmpty;
    final hasTeacher = course.teacher.isNotEmpty;

    // ── 动态字体：列越窄字越小，但不低于8sp ──────────────────
    // 标准列宽约55px（5列）；7列时约45px
    // 基准字体：名称11，地点10；列宽<44时各降1
    final nameFontBase = colWidth < 44 ? 10.0 : 11.0;
    final infoFontBase = colWidth < 44 ? 9.0 : 10.0;
    final nameLineH = nameFontBase * 1.3;
    final infoLineH = infoFontBase * 1.3;
    const gap = 3.0;

    // ── 计算课程名行数 ────────────────────────────────────────
    // 每行能放几个汉字（汉字宽约等于字号）
    final charsPerLine = (availW / nameFontBase).floor().clamp(1, 20);
    final nameCharCount = course.name.length;
    final nameNaturalLines = (nameCharCount / charsPerLine).ceil().clamp(1, 10);

    // 预留地点空间：至少2行infoLineH + gap
    final reserveForInfo = hasLocation ? (gap + infoLineH * 2) : 0.0;
    final nameAvailH = availH - reserveForInfo;
    final nameLines = (nameAvailH / nameLineH)
        .floor()
        .clamp(1, nameNaturalLines)
        .clamp(1, 10);

    // ── 计算地点行数 ──────────────────────────────────────────
    final usedByName = nameLineH * nameLines;
    final afterName = availH - usedByName;
    final charsPerLineInfo = (availW / infoFontBase).floor().clamp(1, 20);
    final locCharCount = course.location.length;
    final locNaturalLines = ((locCharCount + 1) / charsPerLineInfo)
        .ceil()
        .clamp(1, 6); // +1 for icon

    int locationLines = 0;
    if (hasLocation && afterName >= gap + infoLineH) {
      final locAvailH = afterName - gap - (hasTeacher ? gap + infoLineH : 0);
      final computedLines = (locAvailH / infoLineH).floor();
      locationLines = math.max(1, math.min(computedLines, locNaturalLines));
      locationLines = locationLines.clamp(1, 6);
    }

    // ── 教师显示判断 ──────────────────────────────────────────
    final usedSoFar =
        usedByName + (locationLines > 0 ? gap + infoLineH * locationLines : 0);
    final showTeacher = hasTeacher && (availH - usedSoFar) >= gap + infoLineH;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 课程名
          Text(
            course.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: nameFontBase,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: nameLines,
            overflow: TextOverflow.ellipsis,
          ),

          // 地点
          if (locationLines > 0) ...[
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.location_on_rounded,
                      color: Colors.white70, size: infoFontBase),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.location,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: infoFontBase,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: locationLines.clamp(2, 6),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // 教师
          if (showTeacher) ...[
            SizedBox(height: gap),
            Row(
              children: [
                Icon(Icons.person_rounded,
                    color: Colors.white60, size: infoFontBase),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.teacher,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: infoFontBase,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

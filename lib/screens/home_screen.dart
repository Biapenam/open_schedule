import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/widget_service.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/week_selector.dart';
import 'add_course_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final CourseService _service = CourseService();

  List<Course> _courses = [];
  int _currentWeek = 1;
  int _selectedWeek = 1;
  int _totalWeeks = 20;
  int _dailySections = 12;
  bool _loading = true;

  late PageController _pageController;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: 300.ms);
    _loadData();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final courses = await _service.loadCourses();
    final start = await _service.loadSemesterStart();
    final totalWeeks = await _service.loadTotalWeeks();
    final dailySections = await _service.loadDailySections();
    int currentWeek = 1;
    if (start != null) {
      currentWeek = _service.currentWeek(start).clamp(1, totalWeeks);
    }
    _pageController = PageController(initialPage: currentWeek - 1);
    setState(() {
      _courses = courses;
      _currentWeek = currentWeek;
      _selectedWeek = currentWeek;
      _totalWeeks = totalWeeks;
      _dailySections = dailySections;
      _loading = false;
    });
    _fabController.forward();
    WidgetService().updateWidget();
  }

  Future<void> _refresh() async {
    final courses = await _service.loadCourses();
    setState(() => _courses = courses);
    WidgetService().updateWidget();
  }

  void _goToWeek(int week) {
    final target = week.clamp(1, _totalWeeks);
    _pageController.animateToPage(target - 1,
        duration: 350.ms, curve: Curves.easeInOutCubic);
  }

  void _openAddCourse() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => AddCourseScreen(
          totalWeeks: _totalWeeks,
          initialWeek: _selectedWeek,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: 400.ms,
      ),
    );
    if (result == true) _refresh();
  }

  void _openSettings() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            WeekSelector(
              currentWeek: _currentWeek,
              selectedWeek: _selectedWeek,
              totalWeeks: _totalWeeks,
              onWeekChanged: _goToWeek,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalWeeks,
                onPageChanged: (page) =>
                    setState(() => _selectedWeek = page + 1),
                itemBuilder: (context, index) {
                  final week = index + 1;
                  final weekCourses = _service.coursesForWeek(_courses, week);
                  return ScheduleGrid(
                    courses: weekCourses,
                    isCurrentWeek: week == _currentWeek,
                    onCourseDeleted: _refresh,
                    onCourseEdited: _refresh,
                    totalWeeks: _totalWeeks,
                    dailySections: _dailySections,
                    weekNumber: week,
                    currentWeek: _currentWeek,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale:
            CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: _openAddCourse,
          tooltip: '添加课程',
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final todayStr = '${now.month}月${now.day}日 ${weekdays[now.weekday]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('我的课程表', style: Theme.of(context).textTheme.displayLarge)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2),
              const SizedBox(height: 2),
              Text(todayStr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.7)))
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

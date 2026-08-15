import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_schedule/models/course.dart';
import 'package:open_schedule/models/schedule.dart';
import 'package:open_schedule/services/course_service.dart';
import 'package:open_schedule/services/import_export_service.dart';
import 'package:open_schedule/widgets/import_export_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Schedule buildSchedule() => Schedule(
        id: 's-1',
        name: '2026春季学期',
        semesterStart: DateTime(2026, 2, 23),
        totalWeeks: 20,
        dailySections: 12,
        sectionDuration: 45,
        // 远程 Schedule 模型会把节次时间补全到 dailySections 个
        sectionStartTimes: List<String>.from(defaultSectionStartTimes),
      );

  List<Course> buildCourses() => [
        Course(
          id: 'c-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A-101',
          colorValue: 0xFF6C63FF,
          weeks: [1, 2, 3, 4, 5, 6],
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
        ),
        Course(
          id: 'c-2',
          name: '大学英语',
          teacher: '',
          location: '',
          colorValue: 0xFFFF6584,
          weeks: [1, 3, 5],
          dayOfWeek: 3,
          startSection: 3,
          endSection: 4,
        ),
      ];

  test('encode -> decode 往返数据一致', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    expect(code.startsWith('OS1:'), isTrue);

    final data = ImportExportService.decode(code);
    expect(data.schedule.name, '2026春季学期');
    expect(data.schedule.totalWeeks, 20);
    expect(data.schedule.dailySections, 12);
    expect(data.schedule.sectionDuration, 45);
    expect(data.schedule.semesterStart, DateTime(2026, 2, 23));
    expect(data.schedule.sectionStartTimes, defaultSectionStartTimes);

    expect(data.courses.length, 2);
    final first = data.courses.first;
    expect(first.name, '高等数学');
    expect(first.teacher, '张老师');
    expect(first.location, 'A-101');
    expect(first.colorValue, 0xFF6C63FF);
    expect(first.weeks, [1, 2, 3, 4, 5, 6]);
    expect(first.dayOfWeek, 1);
    expect(first.startSection, 1);
    expect(first.endSection, 2);
    // 导入时应重新生成 id，避免跨设备冲突
    expect(first.id, isNot('c-1'));
    expect(data.schedule.id, isNot('s-1'));
  });

  test('空课表也能导出导入', () {
    final schedule = Schedule(id: 's-2', name: '空课表');
    final code = ImportExportService.encode(schedule, const []);
    final data = ImportExportService.decode(code);
    expect(data.courses, isEmpty);
    expect(data.schedule.name, '空课表');
  });

  test('校验码被破坏时抛出 FormatException', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());
    // 改动最后一位校验字符
    final corrupted =
        code.substring(0, code.length - 1) + (code.endsWith('A') ? 'B' : 'A');
    expect(() => ImportExportService.decode(corrupted), throwsFormatException);
  });

  test('缺少前缀时抛出 FormatException', () {
    expect(
        () => ImportExportService.decode('hello world'), throwsFormatException);
    expect(() => ImportExportService.decode(''), throwsFormatException);
  });

  test('粘贴时混入换行 / 空白也能解析', () {
    final code = ImportExportService.encode(buildSchedule(), buildCourses());
    final messy = '\n  ${code.substring(0, 20)}\n${code.substring(20)} \n';
    final data = ImportExportService.decode(messy);
    expect(data.courses.length, 2);
  });

  // ── 导入流程集成测试 ─────────────────────────────────────

  Future<void> _openImportSheet(
      WidgetTester tester, CourseService service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  isScrollControlled: true,
                  builder: (_) => ImportSheet(service: service),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> _parseAndTapImport(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('解析口令'));
    await tester.pumpAndSettle();
    final importBtn = find.text('导入 2026春季学期');
    await tester.ensureVisible(importBtn);
    await tester.pumpAndSettle();
    await tester.tap(importBtn);
    await tester.pumpAndSettle();
  }

  testWidgets('导入：无同名课表时直接导入，名称不加后缀', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await _openImportSheet(tester, service);
    await _parseAndTapImport(tester, code);

    final schedules = await service.loadSchedules();
    final imported = schedules.where((s) => s.name == '2026春季学期');
    expect(imported.length, 1);
    final courses = await service.loadCoursesFor(imported.first.id);
    expect(courses.length, 2);
    expect(courses.first.name, '高等数学');
  });

  testWidgets('导入：同名课表时另存为新课表（名称带后缀）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    await service.createSchedule('2026春季学期'); // 制造同名
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await _openImportSheet(tester, service);
    await _parseAndTapImport(tester, code);

    expect(find.text('已存在同名课表'), findsOneWidget);
    await tester.tap(find.text('另存为新课表'));
    await tester.pumpAndSettle();

    final schedules = await service.loadSchedules();
    expect(schedules.where((s) => s.name == '2026春季学期 (导入)').length, 1);
  });

  testWidgets('导入：同名课表时选择覆盖保留原课表 id', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CourseService();
    await service.ensureMigrated();
    final existing = await service.createSchedule('2026春季学期');
    await service.saveCoursesFor(existing.id, [
      Course(
        id: 'old-1',
        name: '旧课程',
        teacher: '',
        location: '',
        colorValue: 0xFF000000,
        weeks: const [1],
        dayOfWeek: 1,
        startSection: 1,
        endSection: 1,
      ),
    ]);
    final code = ImportExportService.encode(buildSchedule(), buildCourses());

    await _openImportSheet(tester, service);
    await _parseAndTapImport(tester, code);

    await tester.tap(find.text('覆盖'));
    await tester.pumpAndSettle();

    final schedules = await service.loadSchedules();
    final imported = schedules.firstWhere((s) => s.name == '2026春季学期');
    expect(imported.id, existing.id); // 保留原 id
    final courses = await service.loadCoursesFor(imported.id);
    expect(courses.length, 2); // 课程被替换为口令中的课程
    expect(courses.any((c) => c.name == '旧课程'), isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_schedule/app.dart';
import 'package:open_schedule/screens/add_course_screen.dart';
import 'package:open_schedule/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the schedule home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('我的课表'), findsOneWidget);
    expect(find.text('第 1 周'), findsOneWidget);
  });

  // 覆盖常见平板比例的横屏与竖屏，验证无 RenderFlex / bottom overflow
  const tabletSizes = <String, Size>{
    '16:9 landscape': Size(1280, 720),
    '16:10 landscape': Size(1280, 800),
    '4:3 landscape': Size(1024, 768),
    '16:9 portrait': Size(720, 1280),
    '16:10 portrait': Size(800, 1280),
    '4:3 portrait': Size(768, 1024),
  };

  for (final entry in tabletSizes.entries) {
    testWidgets('home tablet ${entry.key} renders without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const ScheduleApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('add course tablet two-column renders without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: AddCourseScreen(totalWeeks: 20, initialWeek: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 平板双栏布局应同时出现两栏的标题
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('上课时间'), findsOneWidget);
    expect(find.text('上课周次'), findsOneWidget);
    expect(find.text('课程颜色'), findsOneWidget);
  });

  testWidgets('settings tablet renders without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

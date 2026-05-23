import 'package:flutter_test/flutter_test.dart';
import 'package:open_schedule/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the schedule home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('我的课程表'), findsOneWidget);
    expect(find.text('第 1 周'), findsOneWidget);
  });
}

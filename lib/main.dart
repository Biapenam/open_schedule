import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/course_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化日期本地化数据（修复 LocaleDataException）
  await initializeDateFormatting('zh_CN', null);
  await WidgetService.init();
  // 迁移旧数据到多课表结构（仅首次运行执行）
  await CourseService().ensureMigrated();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ScheduleApp());
}

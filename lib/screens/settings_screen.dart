import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/course_service.dart';
import '../services/import_export_service.dart';
import '../services/widget_service.dart';
import '../widgets/import_export_sheet.dart';
import '../widgets/schedule_manager_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CourseService _service = CourseService();

  String _scheduleName = '我的课表';
  DateTime? _semesterStart;
  int _totalWeeks = 20;
  int _dailySections = 12;
  int _sectionDuration = 45;
  List<String> _sectionStartTimes = [];
  bool _loading = true;
  bool _saving = false;
  bool _addingWidget = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.ensureMigrated();
    final schedule = await _service.getActiveSchedule();
    final start = schedule?.semesterStart;
    final weeks = schedule?.totalWeeks ?? 20;
    final sections = schedule?.dailySections ?? 12;
    final duration = schedule?.sectionDuration ?? 45;
    final times =
        schedule?.sectionStartTimes ?? await _service.loadSectionStartTimes();
    if (!mounted) return;
    setState(() {
      _scheduleName = schedule?.name ?? '我的课表';
      _semesterStart = start;
      _totalWeeks = weeks;
      _dailySections = sections;
      _sectionDuration = duration;
      _sectionStartTimes = times;
      _loading = false;
    });
  }

  Future<void> _openScheduleManager() async {
    await ScheduleManagerSheet.show(
      context,
      service: _service,
      onChanged: () {
        Navigator.pop(context);
        _load();
      },
    );
  }

  /// 导出当前课表为口令
  Future<void> _openExport() async {
    final schedule = await _service.getActiveSchedule();
    if (!mounted) return;
    if (schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可导出的课表')),
      );
      return;
    }
    final courses = await _service.loadCoursesFor(schedule.id);
    if (!mounted) return;
    final code = ImportExportService.encode(schedule, courses);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ExportSheet(
        code: code,
        scheduleName: schedule.name,
        courseCount: courses.length,
      ),
    );
  }

  /// 从口令导入课表；成功后刷新并同步桌面小卡片
  Future<void> _openImport() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ImportSheet(service: _service),
    );
    if (result == true) {
      _load();
      WidgetService().updateWidget();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: '选择学期开始日期（第1周周一）',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6C63FF),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _semesterStart = picked);
  }

  void _showChangelog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      // 平板下限制宽度并居中
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                  SizedBox(width: 8),
                  Text('更新日志',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: const [
                  _ChangelogEntry(
                    version: 'v1.1.2',
                    isLatest: true,
                    changes: [
                      '新增了对Pad大屏设备的适配',
                      '新增了使用口令在不同设备间传输课表信息的功能',
                      '优化了性能开销',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.1',
                    isLatest: false,
                    changes: [
                      '修复了一些已知问题',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.1.0',
                    isLatest: false,
                    changes: [
                      '新增多课表功能，支持新建、切换、重命名、删除多个课表',
                      '学期结束后课表自动切换为空状态，不再错误顺延开始日期',
                      '新增学期状态提示栏（未开始 / 进行中 / 已结束）',
                      '标题栏支持点击课表名称快速切换课表',
                      '旧版本数据自动迁移至新课表结构',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.6',
                    isLatest: false,
                    changes: [
                      '修复在设置界面更新课程开始结束时间后，课程表界面时间不会更改的问题',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.5',
                    isLatest: false,
                    changes: [
                      '课程表左侧时间列新增每节课结束时间显示',
                      '修复桌面小卡片多节课程结束时间计算不准确的问题',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.4',
                    isLatest: false,
                    changes: [
                      '新增应用内添加桌面小卡片入口',
                      '为桌面小卡片添加流程增加异常兜底提示',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.3',
                    isLatest: false,
                    changes: [
                      '修复桌面小卡片读取数据位置不一致导致刷新后仍显示无课的问题',
                      '课程和时间设置保存后会主动刷新桌面小卡片',
                      '新增桌面小卡片功能',
                      '精简更新日志样式，移除年份标记',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.2',
                    isLatest: false,
                    changes: [
                      '添加课程保存前的时间冲突提示，避免误录重叠课程',
                      '增强本地课程数据读取容错，降低旧数据或异常数据导致崩溃的风险',
                      '桌面小卡片支持点击打开应用',
                      '修复默认测试与当前应用入口不匹配的问题',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.1',
                    isLatest: false,
                    changes: [
                      '新增桌面小卡片，显示当天课程时间和地点',
                      '课程表标题栏新增每天对应日期显示',
                      '支持周六、周日课程显示',
                      '应用更名为 Open Schedule',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: 'v1.0.0',
                    isLatest: false,
                    changes: [
                      '初始版本发布',
                      '支持手动添加、编辑、删除课程',
                      '周视图课程表，支持周次切换',
                      '课程详情弹窗',
                      '学期设置（开始日期、总周数）',
                      '自定义节次时间和课程时长',
                      '单周/双周快捷选择',
                      '10种课程颜色',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    if (_semesterStart != null) {
      await _service.saveSemesterStart(_semesterStart!);
    }
    await _service.saveTotalWeeks(_totalWeeks);
    await _service.saveDailySections(_dailySections);
    await _service.saveSectionDuration(_sectionDuration);
    await _service.saveSectionStartTimes(_sectionStartTimes);
    await WidgetService().updateWidget();
    if (!mounted) return;
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('设置已保存'),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  // 编辑某节课的开始时间
  Future<void> _pickSectionTime(int index) async {
    final current =
        _sectionStartTimes.length > index ? _sectionStartTimes[index] : '08:00';
    final parts = current.split(':');
    final initTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initTime,
      helpText: '设置第 ${index + 1} 节开始时间',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6C63FF),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final h = picked.hour.toString().padLeft(2, '0');
        final m = picked.minute.toString().padLeft(2, '0');
        while (_sectionStartTimes.length <= index) {
          _sectionStartTimes.add('08:00');
        }
        _sectionStartTimes[index] = '$h:$m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text('$_scheduleName · 设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // 平板下限制内容最大宽度并居中，避免横屏时卡片横跨整屏
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── 课表管理 ──
                    _buildCard(
                      title: '课表管理',
                      icon: Icons.collections_bookmark_rounded,
                      children: [
                        ListTile(
                          leading: _iconBox(Icons.swap_horiz_rounded),
                          title: const Text('切换 / 管理课表',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          subtitle: Text('当前：$_scheduleName',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8888AA))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFCCCCDD)),
                          onTap: _openScheduleManager,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _iconBox(Icons.upload_rounded),
                          title: const Text('导出课表',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          subtitle: const Text('生成口令，可在另一台设备快速恢复',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8888AA))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFCCCCDD)),
                          onTap: _openExport,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _iconBox(Icons.download_rounded),
                          title: const Text('从口令导入',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          subtitle: const Text('粘贴口令，恢复课表到本机',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8888AA))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFCCCCDD)),
                          onTap: _openImport,
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 学期信息 ──
                    _buildCard(
                      title: '学期信息',
                      icon: Icons.school_rounded,
                      children: [
                        _buildDateTile(),
                        const Divider(height: 1),
                        _buildWeeksTile(),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 课程时间 ──
                    _buildCard(
                      title: '课程时间设置',
                      icon: Icons.schedule_rounded,
                      children: [
                        _buildDailySectionsTile(),
                        const Divider(height: 1),
                        _buildDurationTile(),
                        const Divider(height: 1),
                        _buildSectionTimesList(),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    _buildCard(
                      title: '桌面小卡片',
                      icon: Icons.widgets_rounded,
                      children: [
                        ListTile(
                          leading: _iconBox(Icons.add_to_home_screen_rounded),
                          title: const Text('添加桌面小卡片',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          subtitle: const Text('在桌面显示今天的课程',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8888AA))),
                          trailing: _addingWidget
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFFCCCCDD)),
                          onTap: _addingWidget ? null : _requestPinWidget,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: _iconBox(Icons.help_outline_rounded),
                          title: const Text('如何手动添加',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          subtitle: const Text('适用于系统没有弹出添加确认时',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8888AA))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFCCCCDD)),
                          onTap: _showManualWidgetGuide,
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 16),

                    // ── 关于 ──
                    _buildCard(
                      title: '关于',
                      icon: Icons.info_rounded,
                      children: [
                        _buildInfoTile('应用名称', 'Open Schedule'),
                        const Divider(height: 1),
                        _buildInfoTile('版本', '1.1.2'),
                        const Divider(height: 1),
                        _buildInfoTile('开发者', 'Sora'),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('更新日志',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E))),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFFCCCCDD)),
                          onTap: () => _showChangelog(context),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.2),

                    const SizedBox(height: 32),

                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('保存设置',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C63FF))),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _requestPinWidget() async {
    setState(() => _addingWidget = true);
    final result = await WidgetService().requestPinWidget();
    if (!mounted) return;

    setState(() => _addingWidget = false);
    final accepted = result == 'accepted';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            accepted ? '已请求添加小卡片；如桌面未弹出确认，请手动添加' : _pinWidgetErrorText(result)),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _pinWidgetErrorText(String result) {
    return switch (result) {
      'launcher_not_supported' => '当前桌面不支持快捷添加小卡片',
      'unsupported_android_version' ||
      'launcher_rejected' ||
      'illegal_state' =>
        '请在桌面小组件列表中添加 Open Schedule',
      _ => '当前桌面无法快捷添加小卡片',
    };
  }

  void _showManualWidgetGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      // 平板下限制宽度并居中
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.widgets_rounded, color: Color(0xFF6C63FF), size: 20),
                SizedBox(width: 8),
                Text('手动添加桌面小卡片',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
              ],
            ),
            const SizedBox(height: 16),
            const _GuideStep(
              index: 1,
              text: '回到手机桌面，长按桌面空白处。',
            ),
            const _GuideStep(
              index: 2,
              text: '进入“小组件”或“插件”列表。',
            ),
            const _GuideStep(
              index: 3,
              text: '找到 Open Schedule，选择课程表小卡片并添加到桌面。',
            ),
            const SizedBox(height: 12),
            const Text(
              '不同系统的入口名称可能略有不同。若快捷添加没有弹出确认，请使用这条方式。',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF8888AA), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    final formatted = _semesterStart != null
        ? DateFormat('yyyy年M月d日 (E)', 'zh_CN').format(_semesterStart!)
        : '未设置';
    return ListTile(
      leading: _iconBox(Icons.calendar_today_rounded),
      title: const Text('学期开始日期',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
      subtitle: Text(formatted,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCDD)),
      onTap: _pickDate,
    );
  }

  Widget _buildWeeksTile() {
    return ListTile(
      leading: _iconBox(Icons.view_week_rounded),
      title: const Text('学期总周数',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
      subtitle: Text('当前：$_totalWeeks 周',
          style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
      trailing: _stepper(
        value: _totalWeeks,
        min: 1,
        max: 30,
        onChanged: (v) => setState(() => _totalWeeks = v),
      ),
    );
  }

  Widget _buildDailySectionsTile() {
    return ListTile(
      leading: _iconBox(Icons.format_list_numbered_rounded),
      title: const Text('每天课程节数',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
      subtitle: Text('当前：$_dailySections 节',
          style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
      trailing: _stepper(
        value: _dailySections,
        min: 4,
        max: 16,
        onChanged: (v) => setState(() => _dailySections = v),
      ),
    );
  }

  Widget _buildDurationTile() {
    return ListTile(
      leading: _iconBox(Icons.timer_rounded),
      title: const Text('每节课时长',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
      subtitle: Text('当前：$_sectionDuration 分钟',
          style: const TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
      trailing: _stepper(
        value: _sectionDuration,
        min: 20,
        max: 120,
        step: 5,
        onChanged: (v) => setState(() => _sectionDuration = v),
      ),
    );
  }

  Widget _buildSectionTimesList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('各节开始时间',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          const Text('点击时间可修改，结束时间根据课程时长自动计算',
              style: TextStyle(fontSize: 11, color: Color(0xFF8888AA))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_dailySections, (i) {
              final startTime = _sectionStartTimes.length > i
                  ? _sectionStartTimes[i]
                  : defaultSectionStartTimes.length > i
                      ? defaultSectionStartTimes[i]
                      : '08:00';
              final endTime = _service.calcEndTime(startTime, _sectionDuration);
              return GestureDetector(
                onTap: () => _pickSectionTime(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text('第${i + 1}节',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(startTime,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E))),
                      Text(endTime,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF8888AA))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
      trailing: Text(value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8888AA))),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
    );
  }

  Widget _stepper({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded),
          onPressed: value > min ? () => onChanged(value - step) : null,
          color: const Color(0xFF6C63FF),
          iconSize: 20,
        ),
        Text('$value',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: value < max ? () => onChanged(value + step) : null,
          color: const Color(0xFF6C63FF),
          iconSize: 20,
        ),
      ],
    );
  }
}

// ── 更新日志条目组件 ──────────────────────────────────────────
class _ChangelogEntry extends StatelessWidget {
  final String version;
  final bool isLatest;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.isLatest,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧时间轴
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isLatest
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFFCCCCDD),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 80, color: const Color(0xFFEEEEF5)),
          ],
        ),
        const SizedBox(width: 12),
        // 右侧内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLatest
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFFF0EFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(version,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isLatest
                                ? Colors.white
                                : const Color(0xFF8888AA))),
                  ),
                  if (isLatest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6584).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('最新',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF6584))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              ...changes.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w700)),
                        Expanded(
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4A4A6A),
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int index;
  final String text;

  const _GuideStep({
    required this.index,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$index',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF4A4A6A), height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

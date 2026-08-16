import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/widget_service.dart';

class AddCourseScreen extends StatefulWidget {
  final int totalWeeks;
  final int initialWeek;
  final Course? editingCourse;

  const AddCourseScreen({
    super.key,
    required this.totalWeeks,
    required this.initialWeek,
    this.editingCourse,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CourseService _service = CourseService();

  late TextEditingController _nameCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _locationCtrl;

  int _dayOfWeek = 1;
  int _startSection = 1;
  int _endSection = 2;
  int _selectedColor = courseColors[0];
  Set<int> _selectedWeeks = {};
  bool _saving = false;
  int _dailySections = 12;
  List<String> _sectionStartTimes = [];
  int _sectionDuration = 45;

  bool get _isEditing => widget.editingCourse != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editingCourse;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _teacherCtrl = TextEditingController(text: c?.teacher ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
    _dayOfWeek = c?.dayOfWeek ?? 1;
    _startSection = c?.startSection ?? 1;
    _endSection = c?.endSection ?? 2;
    _selectedColor = c?.colorValue ?? courseColors[0];
    _selectedWeeks = c != null ? Set<int>.from(c.weeks) : {};
    if (_selectedWeeks.isEmpty) {
      _selectedWeeks =
          Set<int>.from(List.generate(widget.totalWeeks, (i) => i + 1));
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sections = await _service.loadDailySections();
    final times = await _service.loadSectionStartTimes();
    final duration = await _service.loadSectionDuration();
    if (!mounted) return;
    setState(() {
      _dailySections = sections;
      _sectionStartTimes = times;
      _sectionDuration = duration;
      if (_startSection > sections) _startSection = 1;
      if (_endSection > sections) _endSection = sections;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _teacherCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _getStartTime(int section) {
    final idx = section - 1;
    if (idx < _sectionStartTimes.length) {
      return _sectionStartTimes[idx];
    }
    if (idx < defaultSectionStartTimes.length) {
      return defaultSectionStartTimes[idx];
    }
    return '08:00';
  }

  String _getEndTime(int section) {
    return _service.calcEndTime(_getStartTime(section), _sectionDuration);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWeeks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个上课周次')),
      );
      return;
    }
    final conflicts = await _findConflicts();
    if (conflicts.isNotEmpty) {
      final shouldContinue = await _showConflictDialog(conflicts);
      if (shouldContinue != true) return;
    }
    setState(() => _saving = true);
    final course = Course(
      id: _isEditing ? widget.editingCourse!.id : const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      colorValue: _selectedColor,
      weeks: _selectedWeeks.toList()..sort(),
      dayOfWeek: _dayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
    );
    if (_isEditing) {
      await _service.updateCourse(course);
    } else {
      await _service.addCourse(course);
    }
    await WidgetService().updateWidget();
    if (!mounted) return;
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context, true);
  }

  Future<List<Course>> _findConflicts() async {
    final courses = await _service.loadCourses();
    return courses.where((course) {
      if (_isEditing && course.id == widget.editingCourse!.id) return false;
      final sameDay = course.dayOfWeek == _dayOfWeek;
      final sameWeek = course.weeks.any(_selectedWeeks.contains);
      final sectionOverlaps = _startSection <= course.endSection &&
          _endSection >= course.startSection;
      return sameDay && sameWeek && sectionOverlaps;
    }).toList();
  }

  Future<bool?> _showConflictDialog(List<Course> conflicts) {
    final names = conflicts.take(3).map((c) => '「${c.name}」').join('、');
    final extra = conflicts.length > 3 ? '等 ${conflicts.length} 门课程' : '';

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('课程时间可能冲突'),
        content: Text(
          '当前时间与 $names$extra 有重叠。仍然保存吗？',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('继续保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('保存',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        // 平板（宽度 >= 840）：双栏布局，充分利用横向空间；
        // 手机 / 窄屏：保持单栏。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 840;
            final padding = twoColumn ? 24.0 : 16.0;
            // 周次格子在双栏下按栏宽动态决定列数
            final weekColumns = twoColumn
                ? (((constraints.maxWidth - padding * 2 - 20) / 2 / 72)
                    .floor()
                    .clamp(4, 8))
                : 5;
            return ListView(
              padding: EdgeInsets.all(padding),
              children: [
                if (!twoColumn) ...[
                  _sectionBasicInfo(),
                  const SizedBox(height: 20),
                  _sectionClassTime(),
                  const SizedBox(height: 20),
                  _sectionWeeks(weekColumns),
                  const SizedBox(height: 20),
                  _sectionColor(),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionBasicInfo(),
                            const SizedBox(height: 20),
                            _sectionClassTime(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionWeeks(weekColumns),
                            const SizedBox(height: 20),
                            _sectionColor(),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 双栏 / 单栏共享的 section ─────────────────────────────
  Widget _sectionBasicInfo() {
    return _buildSection('基本信息', [
      _buildTextField(_nameCtrl, '课程名称 *', Icons.book_rounded,
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入课程名称' : null),
      const SizedBox(height: 12),
      _buildTextField(_teacherCtrl, '任课教师（可选）', Icons.person_rounded),
      const SizedBox(height: 12),
      _buildTextField(_locationCtrl, '上课地点（可选）', Icons.location_on_rounded),
    ]).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2);
  }

  Widget _sectionClassTime() {
    return _buildSection('上课时间', [
      _buildDayPicker(),
      const SizedBox(height: 14),
      _buildSectionPicker(),
    ]).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.2);
  }

  Widget _sectionWeeks(int crossAxisCount) {
    return _buildSection('上课周次', [
      _buildWeekPicker(crossAxisCount: crossAxisCount),
    ]).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.2);
  }

  Widget _sectionColor() {
    return _buildSection('课程颜色', [
      _buildColorPicker(),
    ]).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.2);
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
      ),
    );
  }

  Widget _buildDayPicker() {
    const days = ['', '一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('星期',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int d = 1; d <= 7; d++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _dayOfWeek = d),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 38,
                    decoration: BoxDecoration(
                      color: _dayOfWeek == d
                          ? (d >= 6
                              ? const Color(0xFFFF6584)
                              : const Color(0xFF6C63FF))
                          : (d >= 6
                              ? const Color(0xFFFFF0F3)
                              : const Color(0xFFF0EFFF)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(days[d],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dayOfWeek == d
                                  ? Colors.white
                                  : (d >= 6
                                      ? const Color(0xFFFF6584)
                                      : const Color(0xFF4A4A6A)))),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('节次',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFFAAAAAA),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SectionDropdown(
                label: '开始节次',
                value: _startSection,
                max: _dailySections,
                onChanged: (v) {
                  setState(() {
                    _startSection = v;
                    if (_endSection < v) _endSection = v;
                  });
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 18)),
            ),
            Expanded(
              child: _SectionDropdown(
                label: '结束节次',
                value: _endSection,
                min: _startSection,
                max: _dailySections,
                onChanged: (v) => setState(() => _endSection = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_getStartTime(_startSection)} — ${_getEndTime(_endSection)}',
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildWeekPicker({int crossAxisCount = 5}) {
    final allSelected = _selectedWeeks.length == widget.totalWeeks;
    // 单周：1,3,5...  双周：2,4,6...
    final oddWeeks = List.generate(widget.totalWeeks, (i) => i + 1)
        .where((w) => w.isOdd)
        .toSet();
    final evenWeeks = List.generate(widget.totalWeeks, (i) => i + 1)
        .where((w) => w.isEven)
        .toSet();
    final isOddSelected = _selectedWeeks.containsAll(oddWeeks) &&
        _selectedWeeks.difference(oddWeeks).isEmpty;
    final isEvenSelected = _selectedWeeks.containsAll(evenWeeks) &&
        _selectedWeeks.difference(evenWeeks).isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：已选信息 + 全选
        Row(
          children: [
            Text('已选 ${_selectedWeeks.length} / ${widget.totalWeeks} 周',
                style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
            const Spacer(),
            _QuickChip(
              label: '全选',
              active: allSelected,
              onTap: () => setState(() {
                if (allSelected) {
                  _selectedWeeks.clear();
                } else {
                  _selectedWeeks = Set<int>.from(
                      List.generate(widget.totalWeeks, (i) => i + 1));
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 快捷选择：单周 / 双周
        Row(
          children: [
            _QuickChip(
              label: '单周',
              icon: Icons.looks_one_rounded,
              active: isOddSelected,
              onTap: () =>
                  setState(() => _selectedWeeks = Set<int>.from(oddWeeks)),
            ),
            const SizedBox(width: 8),
            _QuickChip(
              label: '双周',
              icon: Icons.looks_two_rounded,
              active: isEvenSelected,
              onTap: () =>
                  setState(() => _selectedWeeks = Set<int>.from(evenWeeks)),
            ),
            const SizedBox(width: 8),
            _QuickChip(
              label: '清空',
              icon: Icons.clear_rounded,
              active: false,
              onTap: () => setState(() => _selectedWeeks.clear()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 周格子（列数按可用宽度动态调整）
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
          ),
          itemCount: widget.totalWeeks,
          itemBuilder: (_, i) {
            final week = i + 1;
            final selected = _selectedWeeks.contains(week);
            final isOdd = week.isOdd;
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedWeeks.remove(week);
                  } else {
                    _selectedWeeks.add(week);
                  }
                });
              },
              child: AnimatedContainer(
                duration: 150.ms,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6C63FF)
                      : isOdd
                          ? const Color(0xFFF0EFFF)
                          : const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$week',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF4A4A6A))),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // 图例
        const Row(
          children: [
            _LegendDot(color: Color(0xFFF0EFFF), label: '单周'),
            SizedBox(width: 12),
            _LegendDot(color: Color(0xFFE8F4FD), label: '双周'),
            SizedBox(width: 12),
            _LegendDot(color: Color(0xFF6C63FF), label: '已选'),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: courseColors.map((colorVal) {
        final color = Color(colorVal);
        final selected = _selectedColor == colorVal;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = colorVal),
          child: AnimatedContainer(
            duration: 200.ms,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: color.withValues(alpha: 0.5), width: 3)
                  : null,
              boxShadow: selected
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                  : [],
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── 快捷选择按钮 ──────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6C63FF) : const Color(0xFFF0EFFF),
          borderRadius: BorderRadius.circular(20),
          border: active
              ? null
              : Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: active ? Colors.white : const Color(0xFF6C63FF)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF6C63FF))),
          ],
        ),
      ),
    );
  }
}

// ── 图例小点 ──────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8888AA))),
      ],
    );
  }
}

// ── 节次下拉框 ────────────────────────────────────────────────
class _SectionDropdown extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SectionDropdown({
    required this.label,
    required this.value,
    this.min = 1,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<int>(
        value: value.clamp(min, max),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.white,
        style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 14,
            fontWeight: FontWeight.w600),
        items: List.generate(max - min + 1, (i) {
          final s = min + i;
          return DropdownMenuItem(value: s, child: Text('第 $s 节'));
        }),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}

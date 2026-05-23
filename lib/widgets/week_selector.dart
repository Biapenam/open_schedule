import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WeekSelector extends StatelessWidget {
  final int currentWeek;
  final int selectedWeek;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;

  const WeekSelector({
    super.key,
    required this.currentWeek,
    required this.selectedWeek,
    required this.totalWeeks,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // 上一周
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap:
                selectedWeek > 1 ? () => onWeekChanged(selectedWeek - 1) : null,
          ),
          // 周次显示
          Expanded(
            child: GestureDetector(
              onTap: () => _showWeekPicker(context),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 当前周指示
                    if (selectedWeek == currentWeek)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '本周',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ).animate().scale(duration: 200.ms),
                    Text(
                      '第 $selectedWeek 周',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ $totalWeeks',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded,
                        size: 18, color: Color(0xFFAAAAAA)),
                  ],
                ),
              ),
            ),
          ),
          // 下一周
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: selectedWeek < totalWeeks
                ? () => onWeekChanged(selectedWeek + 1)
                : null,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.2);
  }

  void _showWeekPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WeekPickerSheet(
        selectedWeek: selectedWeek,
        currentWeek: currentWeek,
        totalWeeks: totalWeeks,
        onSelected: (w) {
          Navigator.pop(context);
          onWeekChanged(w);
        },
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          color:
              onTap != null ? const Color(0xFF6C63FF) : const Color(0xFFCCCCDD),
          size: 22,
        ),
      ),
    );
  }
}

class _WeekPickerSheet extends StatelessWidget {
  final int selectedWeek;
  final int currentWeek;
  final int totalWeeks;
  final ValueChanged<int> onSelected;

  const _WeekPickerSheet({
    required this.selectedWeek,
    required this.currentWeek,
    required this.totalWeeks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '选择周次',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: totalWeeks,
            itemBuilder: (_, i) {
              final week = i + 1;
              final isSelected = week == selectedWeek;
              final isCurrent = week == currentWeek;
              return GestureDetector(
                onTap: () => onSelected(week),
                child: AnimatedContainer(
                  duration: 200.ms,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : isCurrent
                            ? const Color(0xFF6C63FF).withOpacity(0.1)
                            : const Color(0xFFF5F5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : isCurrent
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF4A4A6A),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

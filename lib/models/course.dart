import 'dart:convert';

class Course {
  final String id;
  final String name;
  final String teacher;
  final String location;
  final int colorValue;
  final List<int> weeks; // 哪些周有课，如 [1,2,3,...,16]
  final int dayOfWeek; // 1=周一，2=周二，...，7=周日
  final int startSection; // 开始节次（1-12）
  final int endSection; // 结束节次（1-12）

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.colorValue,
    required this.weeks,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
  });

  // 深拷贝修改
  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    int? colorValue,
    List<int>? weeks,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      colorValue: colorValue ?? this.colorValue,
      weeks: weeks ?? List.from(this.weeks),
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'location': location,
        'colorValue': colorValue,
        'weeks': weeks,
        'dayOfWeek': dayOfWeek,
        'startSection': startSection,
        'endSection': endSection,
      };

  factory Course.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String readString(String key) => (json[key] ?? '').toString();

    final rawWeeks = json['weeks'];
    final weeks = rawWeeks is List
        ? rawWeeks
            .map((w) => w is int ? w : int.tryParse(w.toString()))
            .whereType<int>()
            .where((w) => w > 0)
            .toList()
        : <int>[];

    final startSection = readInt('startSection', 1).clamp(1, 16).toInt();
    final endSection =
        readInt('endSection', startSection).clamp(startSection, 16).toInt();

    return Course(
      id: readString('id'),
      name: readString('name'),
      teacher: readString('teacher'),
      location: readString('location'),
      colorValue: readInt('colorValue', courseColors[0]),
      weeks: weeks,
      dayOfWeek: readInt('dayOfWeek', 1).clamp(1, 7).toInt(),
      startSection: startSection,
      endSection: endSection,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Course.fromJsonString(String s) => Course.fromJson(jsonDecode(s));
}

// 节次时间对照表
const List<String> sectionTimes = [
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

const List<String> sectionEndTimes = [
  '08:45',
  '09:40',
  '10:35',
  '11:40',
  '12:35',
  '14:15',
  '15:10',
  '16:05',
  '17:00',
  '19:15',
  '20:10',
  '21:05',
];

// 预设课程颜色
const List<int> courseColors = [
  0xFF6C63FF, // 紫色
  0xFFFF6584, // 粉红
  0xFF43C6AC, // 青绿
  0xFFFF9A3C, // 橙色
  0xFF4FC3F7, // 天蓝
  0xFFAB47BC, // 深紫
  0xFF26A69A, // 墨绿
  0xFFEF5350, // 红色
  0xFF66BB6A, // 绿色
  0xFFFFCA28, // 黄色（文字用深色）
];

const List<String> dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const List<String> dayShortNames = [
  '',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

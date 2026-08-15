import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/course_service.dart' show defaultSectionStartTimes;

/// 课表（学期）模型：每个课表拥有独立的学期设置与课程列表。
class Schedule {
  static const minTotalWeeks = 1;
  static const maxTotalWeeks = 30;
  static const minDailySections = 4;
  static const maxDailySections = 16;
  static const minSectionDuration = 20;
  static const maxSectionDuration = 120;
  final String id;
  final String name;
  final DateTime? semesterStart;
  final int totalWeeks;
  final int dailySections;
  final List<String> sectionStartTimes;
  final int sectionDuration;

  Schedule({
    required this.id,
    required this.name,
    this.semesterStart,
    int totalWeeks = 20,
    int dailySections = 12,
    List<String>? sectionStartTimes,
    int sectionDuration = 45,
  })  : totalWeeks = totalWeeks.clamp(minTotalWeeks, maxTotalWeeks).toInt(),
        dailySections = dailySections.clamp(minDailySections, maxDailySections).toInt(),
        sectionStartTimes = normalizeSectionStartTimes(
            sectionStartTimes, dailySections.clamp(minDailySections, maxDailySections).toInt()),
        sectionDuration =
            sectionDuration.clamp(minSectionDuration, maxSectionDuration).toInt();

  static List<String> normalizeSectionStartTimes(
      List<String>? raw, int dailySections) {
    final defaults = List<String>.from(defaultSectionStartTimes);
    final values = raw ?? <String>[];
    return List<String>.generate(dailySections, (index) {
      final value = index < values.length ? values[index] : null;
      return _isValidTime(value) ? value! : (index < defaults.length ? defaults[index] : '08:00');
    });
  }

  static bool _isValidTime(String? value) {
    if (value == null) return false;
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
    return match != null;
  }

  Schedule copyWith({
    String? id,
    String? name,
    DateTime? semesterStart,
    bool clearSemesterStart = false,
    int? totalWeeks,
    int? dailySections,
    List<String>? sectionStartTimes,
    int? sectionDuration,
  }) {
    return Schedule(
      id: id ?? this.id,
      name: name ?? this.name,
      semesterStart:
          clearSemesterStart ? null : (semesterStart ?? this.semesterStart),
      totalWeeks: totalWeeks ?? this.totalWeeks,
      dailySections: dailySections ?? this.dailySections,
      sectionStartTimes: sectionStartTimes ?? List.from(this.sectionStartTimes),
      sectionDuration: sectionDuration ?? this.sectionDuration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'semesterStart': semesterStart?.toIso8601String(),
        'totalWeeks': totalWeeks,
        'dailySections': dailySections,
        'sectionStartTimes': sectionStartTimes,
        'sectionDuration': sectionDuration,
      };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String readString(String key, {String fallback = ''}) =>
        (json[key] ?? fallback).toString();

    final rawStart = json['semesterStart'];
    DateTime? start;
    if (rawStart is String && rawStart.isNotEmpty) {
      start = DateTime.tryParse(rawStart);
    }

    final rawTimes = json['sectionStartTimes'];
    final times = rawTimes is List
        ? rawTimes.map((e) => e.toString()).toList()
        : List<String>.from(defaultSectionStartTimes);

    return Schedule(
      id: readString('id', fallback: const Uuid().v4()),
      name: readString('name', fallback: '未命名课表'),
      semesterStart: start,
      totalWeeks: readInt('totalWeeks', 20),
      dailySections: readInt('dailySections', 12),
      sectionStartTimes: times,
      sectionDuration: readInt('sectionDuration', 45),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Schedule.fromJsonString(String s) => Schedule.fromJson(jsonDecode(s));
}

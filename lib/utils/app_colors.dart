import 'package:flutter/material.dart';

/// 全局颜色常量：与 app.dart 的主题保持一致。
///
/// UI 组件应优先引用这里的常量（或 `Theme.of(context).colorScheme`），
/// 避免散落的魔法色值在改主题时漏改。
abstract final class AppColors {
  /// 主色（紫）
  static const Color primary = Color(0xFF6C63FF);

  /// 次色（粉）
  static const Color secondary = Color(0xFFFF6584);

  /// 页面背景
  static const Color background = Color(0xFFF8F7FF);

  /// 主要文字
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// 次要文字（正文）
  static const Color textBody = Color(0xFF4A4A6A);

  /// 辅助文字 / 说明
  static const Color textSecondary = Color(0xFF8888AA);

  /// 输入框填充
  static const Color inputFill = Color(0xFFF0EFFF);

  /// 分隔线 / 网格线
  static const Color borderLight = Color(0xFFEEEEF5);
}

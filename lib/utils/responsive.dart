import 'package:flutter/material.dart';

/// 设备断点（基于 Material 3 的 adaptive breakpoints）
///
/// - compact  : 手机窄屏（宽度 < 600）
/// - medium   : 中等宽度（600 ~ 840），大屏手机 / 小平板竖屏
/// - expanded : 平板 / 横屏（宽度 >= 840）
enum DeviceBreakpoint { compact, medium, expanded }

/// 响应式布局常用常量与工具方法。
///
/// 所有判断基于 logical width / shortestSide，而不是具体设备型号，
/// 因此可以自适应 16:9、16:10、4:3 等任意屏幕比例。
class Responsive {
  /// 手机 / 平板分界（Material 规范）：shortestSide >= 600 视为平板
  static const double tabletBreakpoint = 600;

  /// expanded 布局断点
  static const double expandedBreakpoint = 840;

  /// 是否为平板：短边 >= 600dp。
  /// 使用最短边而不是宽度，可避免把横屏手机误判为平板。
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

  /// 是否为横屏
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// 根据当前宽度返回断点
  static DeviceBreakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < tabletBreakpoint) return DeviceBreakpoint.compact;
    if (width < expandedBreakpoint) return DeviceBreakpoint.medium;
    return DeviceBreakpoint.expanded;
  }

  /// 建议的内容最大宽度，避免内容在超宽屏 / 4:3 横屏上无限拉伸。
  /// 手机（窄屏）返回全宽，保持现有单栏布局。
  static double contentMaxWidth(BuildContext context, {double maxWidth = 900}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletBreakpoint) return width.clamp(0.0, maxWidth);
    return width;
  }
}

/// 居中并限制最大宽度，避免平板横屏下内容横跨整个屏幕。
///
/// 用法：将原本「全宽」的内容包一层即可，手机端不受影响。
class ResponsiveContainer extends StatelessWidget {
  /// 内容
  final Widget child;

  /// 最大宽度；默认取 [Responsive.contentMaxWidth]（900）
  final double? maxWidth;

  /// 水平方向留白
  final double horizontalPadding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? Responsive.contentMaxWidth(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

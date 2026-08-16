/// 响应式布局常用常量与工具方法。
///
/// 所有判断基于 logical width / shortestSide，而不是具体设备型号，
/// 因此可以自适应 16:9、16:10、4:3 等任意屏幕比例。
class Responsive {
  /// 手机 / 平板分界（Material 规范）：shortestSide >= 600 视为平板
  static const double tabletBreakpoint = 600;

  /// 平板下内容整体最大宽度，避免横屏时内容横跨整屏
  static const double contentMaxWidth = 960;
}

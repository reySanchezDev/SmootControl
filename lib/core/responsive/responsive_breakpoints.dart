/// Official responsive breakpoints for SmooControl.
abstract final class ResponsiveBreakpoints {
  /// Width below this value is treated as mobile.
  static const double mobileMax = 599;

  /// Width below this value is treated as tablet.
  static const double tabletMax = 1023;
}

/// Device layout categories supported by the UI.
enum ResponsiveSize {
  /// Compact mobile layout.
  mobile,

  /// Medium tablet layout.
  tablet,

  /// Expanded desktop or web layout.
  desktop,
}

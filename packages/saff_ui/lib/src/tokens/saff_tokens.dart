/// Spacing, radii and motion tokens.
abstract final class SaffSpacing {
  /// 4.
  static const double xs = 4;

  /// 8.
  static const double sm = 8;

  /// 12.
  static const double md = 12;

  /// 16.
  static const double lg = 16;

  /// 24.
  static const double xl = 24;

  /// 32.
  static const double xxl = 32;
}

/// Corner radii.
abstract final class SaffRadii {
  /// Chips and small controls.
  static const double sm = 10;

  /// Cards.
  static const double md = 16;

  /// Sheets and big buttons.
  static const double lg = 24;

  /// Pills.
  static const double pill = 999;
}

/// Animation durations.
abstract final class SaffMotion {
  /// Quick feedback.
  static const fast = Duration(milliseconds: 150);

  /// Standard transitions.
  static const normal = Duration(milliseconds: 250);

  /// Reveals and count-ups.
  static const slow = Duration(milliseconds: 600);
}

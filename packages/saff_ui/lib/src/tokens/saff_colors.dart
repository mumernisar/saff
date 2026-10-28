import 'package:flutter/material.dart';

/// Colour tokens from the mockups (`docs/design/flows.md` §0).
@immutable
final class SaffColors extends ThemeExtension<SaffColors> {
  /// Creates a palette.
  const SaffColors({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    required this.soft,
    required this.accent,
    required this.asleep,
    required this.done,
    required this.playing,
    required this.error,
  });

  /// Light palette.
  static const light = SaffColors(
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF161A22),
    muted: Color(0xFF646B7A),
    line: Color(0xFFE3E6EC),
    soft: Color(0xFFFDF3DC),
    accent: Color(0xFFF2B33D),
    asleep: Color(0xFFA7AEBB),
    done: Color(0xFF2F9E6E),
    playing: Color(0xFF7FA7E6),
    error: Color(0xFFD64B4B),
  );

  /// Dark palette.
  static const dark = SaffColors(
    bg: Color(0xFF0F1524),
    surface: Color(0xFF172033),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFAEB6C6),
    line: Color(0xFF26304A),
    soft: Color(0xFF4A4232),
    accent: Color(0xFFF2B33D),
    asleep: Color(0xFFA7AEBB),
    done: Color(0xFF2F9E6E),
    playing: Color(0xFF7FA7E6),
    error: Color(0xFFD64B4B),
  );

  /// Page background.
  final Color bg;

  /// Cards and sheets.
  final Color surface;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color muted;

  /// Dividers and borders.
  final Color line;

  /// Soft accent fill.
  final Color soft;

  /// The gold accent.
  final Color accent;

  /// Status: asleep / snoozed.
  final Color asleep;

  /// Status: up / done.
  final Color done;

  /// Status: playing.
  final Color playing;

  /// Status: offline / error / missed.
  final Color error;

  @override
  SaffColors copyWith() => this;

  @override
  SaffColors lerp(SaffColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Avatar colours auto-assigned to members.
const avatarColors = <Color>[
  Color(0xFFE8A897),
  Color(0xFFC3A6E0),
  Color(0xFF9FCBB3),
  Color(0xFF7FA7E6),
  Color(0xFFF6D27A),
];

/// The wake palette: night → fajr → dawn → duha (`flows.md` §0).
abstract final class WakePalette {
  /// Stops of the brightening gradient.
  static const night = Color.fromRGBO(15, 21, 36, 1);

  /// Second stop.
  static const fajr = Color.fromRGBO(35, 50, 92, 1);

  /// Third stop.
  static const dawn = Color.fromRGBO(233, 168, 107, 1);

  /// Last stop.
  static const duha = Color.fromRGBO(246, 210, 122, 1);

  /// The background colour at [t] in 0..1 (0 = ring start, 1 = ramp end).
  static Color at(double t) {
    final x = t.clamp(0.0, 1.0);
    if (x < 1 / 3) return Color.lerp(night, fajr, x * 3)!;
    if (x < 2 / 3) return Color.lerp(fajr, dawn, (x - 1 / 3) * 3)!;
    return Color.lerp(dawn, duha, (x - 2 / 3) * 3)!;
  }

  /// Whether text on [at] should be dark.
  static bool darkText(double t) => t > 0.55;
}

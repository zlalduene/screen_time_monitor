import 'package:flutter/material.dart';

/// 全局配色。暖纸感的底色 + 墨绿主色，避免大面积渐变与高饱和色。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color warm;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.warm,
  });

  static const light = AppPalette(
    bg: Color(0xFFF3F0E9),
    surface: Color(0xFFFDFCF8),
    surfaceAlt: Color(0xFFEAE5D9),
    ink: Color(0xFF1D1B15),
    inkMuted: Color(0xFF7C7466),
    line: Color(0xFFE2DBCB),
    accent: Color(0xFF2F6B52),
    accentSoft: Color(0xFFDEE9E1),
    warm: Color(0xFFB96A3D),
  );

  static const dark = AppPalette(
    bg: Color(0xFF12110D),
    surface: Color(0xFF1B1A14),
    surfaceAlt: Color(0xFF25241B),
    ink: Color(0xFFF1ECDF),
    inkMuted: Color(0xFF958D7B),
    line: Color(0xFF322F24),
    accent: Color(0xFF83C2A3),
    accentSoft: Color(0xFF1F2D25),
    warm: Color(0xFFD9915F),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? warm,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      warm: warm ?? this.warm,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: palette.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
    ).copyWith(
      primary: palette.accent,
      surface: palette.surface,
      onSurface: palette.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    ),
    extensions: [palette],
  );
}

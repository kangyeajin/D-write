import 'package:flutter/material.dart';

enum AppPalette { fog, sand, moss, dawn }

extension AppPaletteX on AppPalette {
  String get id {
    switch (this) {
      case AppPalette.fog:  return 'fog';
      case AppPalette.sand: return 'sand';
      case AppPalette.moss: return 'moss';
      case AppPalette.dawn: return 'dawn';
    }
  }

  String get label {
    switch (this) {
      case AppPalette.fog:  return '안개';
      case AppPalette.sand: return '모래';
      case AppPalette.moss: return '이끼';
      case AppPalette.dawn: return '새벽';
    }
  }

  static AppPalette fromId(String id) {
    switch (id) {
      case 'sand': return AppPalette.sand;
      case 'moss': return AppPalette.moss;
      case 'dawn': return AppPalette.dawn;
      default:     return AppPalette.fog;
    }
  }
}

/// 팔레트별 색상 토큰 — ThemeExtension으로 ThemeData에 내장됨.
///
/// 위젯에서: `AppColorTokens.of(context).background`
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentMuted,
    required this.divider,
    required this.shimmer,
    required this.error,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color cardSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentMuted;
  final Color divider;
  final Color shimmer;
  final Color error;
  final Color success;

  static AppColorTokens of(BuildContext context) =>
      Theme.of(context).extension<AppColorTokens>()!;

  static AppColorTokens forPalette(AppPalette palette, Brightness brightness) {
    final light = brightness == Brightness.light;
    switch (palette) {
      case AppPalette.fog:  return light ? _fogLight  : _fogDark;
      case AppPalette.sand: return light ? _sandLight : _sandDark;
      case AppPalette.moss: return light ? _mossLight : _mossDark;
      case AppPalette.dawn: return light ? _dawnLight : _dawnDark;
    }
  }

  // ── C. 안개 (Fog) ─────────────────────────────────────────
  static const _fogLight = AppColorTokens(
    background:    Color(0xFFF5F5F3),
    surface:       Color(0xFFEBEBEA),
    cardSurface:   Color(0xFFE4E4E2),
    textPrimary:   Color(0xFF1E1E1E),
    textSecondary: Color(0xFF888888),
    textTertiary:  Color(0xFFAAAAAA),
    accent:        Color(0xFF7B8FA1),
    accentMuted:   Color(0xFF9BAFBF),
    divider:       Color(0xFFDEDEDC),
    shimmer:       Color(0xFFE8E8E6),
    error:         Color(0xFFB00020),
    success:       Color(0xFF388E3C),
  );
  static const _fogDark = AppColorTokens(
    background:    Color(0xFF1A1A1E),
    surface:       Color(0xFF22222A),
    cardSurface:   Color(0xFF2A2A32),
    textPrimary:   Color(0xFFE8E8E8),
    textSecondary: Color(0xFF888888),
    textTertiary:  Color(0xFF555555),
    accent:        Color(0xFF7B8FA1),
    accentMuted:   Color(0xFF5D7085),
    divider:       Color(0xFF2C2C30),
    shimmer:       Color(0xFF282830),
    error:         Color(0xFFCF6679),
    success:       Color(0xFF4CAF50),
  );

  // ── A. 모래 (Sand) ────────────────────────────────────────
  static const _sandLight = AppColorTokens(
    background:    Color(0xFFF8F4EF),
    surface:       Color(0xFFEDE6DC),
    cardSurface:   Color(0xFFE5DDD2),
    textPrimary:   Color(0xFF2A2320),
    textSecondary: Color(0xFF9C8A7A),
    textTertiary:  Color(0xFFBBAAA0),
    accent:        Color(0xFFB5714E),
    accentMuted:   Color(0xFFD4A98A),
    divider:       Color(0xFFDDD5C8),
    shimmer:       Color(0xFFE8E2D8),
    error:         Color(0xFFB00020),
    success:       Color(0xFF388E3C),
  );
  static const _sandDark = AppColorTokens(
    background:    Color(0xFF1E1A16),
    surface:       Color(0xFF26211B),
    cardSurface:   Color(0xFF2E2820),
    textPrimary:   Color(0xFFEDE6DC),
    textSecondary: Color(0xFF9C8A7A),
    textTertiary:  Color(0xFF6B5A50),
    accent:        Color(0xFFB5714E),
    accentMuted:   Color(0xFF8A5540),
    divider:       Color(0xFF352E27),
    shimmer:       Color(0xFF2C2520),
    error:         Color(0xFFCF6679),
    success:       Color(0xFF4CAF50),
  );

  // ── B. 이끼 (Moss) ────────────────────────────────────────
  static const _mossLight = AppColorTokens(
    background:    Color(0xFFF3F4EF),
    surface:       Color(0xFFE6E8DF),
    cardSurface:   Color(0xFFDDE0D5),
    textPrimary:   Color(0xFF252B22),
    textSecondary: Color(0xFF7A8572),
    textTertiary:  Color(0xFFAAB5A0),
    accent:        Color(0xFF697A5E),
    accentMuted:   Color(0xFF8A9D7E),
    divider:       Color(0xFFD8DACD),
    shimmer:       Color(0xFFE0E2DA),
    error:         Color(0xFFB00020),
    success:       Color(0xFF388E3C),
  );
  static const _mossDark = AppColorTokens(
    background:    Color(0xFF181C16),
    surface:       Color(0xFF1E231C),
    cardSurface:   Color(0xFF252B22),
    textPrimary:   Color(0xFFE6E8DF),
    textSecondary: Color(0xFF7A8572),
    textTertiary:  Color(0xFF506048),
    accent:        Color(0xFF8A9D7E),
    accentMuted:   Color(0xFF5D7055),
    divider:       Color(0xFF2A2E27),
    shimmer:       Color(0xFF242820),
    error:         Color(0xFFCF6679),
    success:       Color(0xFF4CAF50),
  );

  // ── D. 새벽 (Dawn) ────────────────────────────────────────
  static const _dawnLight = AppColorTokens(
    background:    Color(0xFFFAF7F4),
    surface:       Color(0xFFF0E9E3),
    cardSurface:   Color(0xFFE8E0D8),
    textPrimary:   Color(0xFF2D2925),
    textSecondary: Color(0xFFA0907E),
    textTertiary:  Color(0xFFBFB0A0),
    accent:        Color(0xFFC4826A),
    accentMuted:   Color(0xFFD8A898),
    divider:       Color(0xFFE0D6CC),
    shimmer:       Color(0xFFEDE6E0),
    error:         Color(0xFFB00020),
    success:       Color(0xFF388E3C),
  );
  static const _dawnDark = AppColorTokens(
    background:    Color(0xFF1E1B18),
    surface:       Color(0xFF26221E),
    cardSurface:   Color(0xFF302A26),
    textPrimary:   Color(0xFFF0E9E3),
    textSecondary: Color(0xFFA0907E),
    textTertiary:  Color(0xFF705E50),
    accent:        Color(0xFFC4826A),
    accentMuted:   Color(0xFF906050),
    divider:       Color(0xFF352F2A),
    shimmer:       Color(0xFF2C2620),
    error:         Color(0xFFCF6679),
    success:       Color(0xFF4CAF50),
  );

  @override
  AppColorTokens copyWith({
    Color? background, Color? surface, Color? cardSurface,
    Color? textPrimary, Color? textSecondary, Color? textTertiary,
    Color? accent, Color? accentMuted, Color? divider,
    Color? shimmer, Color? error, Color? success,
  }) => AppColorTokens(
    background:    background    ?? this.background,
    surface:       surface       ?? this.surface,
    cardSurface:   cardSurface   ?? this.cardSurface,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary:  textTertiary  ?? this.textTertiary,
    accent:        accent        ?? this.accent,
    accentMuted:   accentMuted   ?? this.accentMuted,
    divider:       divider       ?? this.divider,
    shimmer:       shimmer       ?? this.shimmer,
    error:         error         ?? this.error,
    success:       success       ?? this.success,
  );

  @override
  AppColorTokens lerp(AppColorTokens? other, double t) {
    if (other == null) return this;
    return AppColorTokens(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      cardSurface:   Color.lerp(cardSurface,   other.cardSurface,   t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary,  other.textTertiary,  t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
      accentMuted:   Color.lerp(accentMuted,   other.accentMuted,   t)!,
      divider:       Color.lerp(divider,       other.divider,       t)!,
      shimmer:       Color.lerp(shimmer,       other.shimmer,       t)!,
      error:         Color.lerp(error,         other.error,         t)!,
      success:       Color.lerp(success,       other.success,       t)!,
    );
  }
}

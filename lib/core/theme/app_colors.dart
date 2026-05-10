import 'package:flutter/material.dart';

import 'app_palette.dart';

/// D-Write 색상 진입점.
///
/// 새 코드: `AppColorTokens.of(context).background` 사용.
/// 기존 코드 호환을 위해 static 상수는 Fog 라이트 값으로 고정.
class AppColors {
  AppColors._();

  // context-aware shortcut
  static AppColorTokens of(BuildContext context) => AppColorTokens.of(context);

  // ── 하위 호환 상수 (Fog Light 기준) ─────────────────────────
  static const Color backgroundLight   = Color(0xFFF5F5F3);
  static const Color surfaceLight      = Color(0xFFEBEBEA);
  static const Color cardLight         = Color(0xFFE4E4E2);
  static const Color onBackgroundLight = Color(0xFF1E1E1E);
  static const Color onSurfaceLight    = Color(0xFF888888);
  static const Color subtitleLight     = Color(0xFF888888);
  static const Color dividerLight      = Color(0xFFDEDEDC);

  static const Color backgroundDark    = Color(0xFF1A1A1E);
  static const Color surfaceDark       = Color(0xFF22222A);
  static const Color cardDark          = Color(0xFF2A2A32);
  static const Color onBackgroundDark  = Color(0xFFE8E8E8);
  static const Color onSurfaceDark     = Color(0xFF888888);
  static const Color subtitleDark      = Color(0xFF888888);
  static const Color dividerDark       = Color(0xFF2C2C30);

  static const Color like    = Color(0xFF7B8FA1);
  static const Color primary = Color(0xFF1E1E1E);
  static const Color error   = Color(0xFFB00020);
  static const Color success = Color(0xFF388E3C);
  static const Color shimmer = Color(0xFFE8E8E6);
}

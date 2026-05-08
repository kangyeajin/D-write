import 'package:flutter/material.dart';

/// D-Write 색상 팔레트
///
/// 규칙:
/// - 위젯에서 `Colors.xxx` 또는 `Color(0xFF...)` 하드코딩 금지.
/// - 반드시 이 클래스의 상수를 참조할 것.
/// - 다크모드 구현 시: dark 접미사 상수만 채우면 전환 완료.
class AppColors {
  AppColors._();

  // ── 라이트: 배경 ─────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight    = Color(0xFFF7F7F7);
  static const Color cardLight       = Color(0xFFFFFFFF);

  // ── 라이트: 텍스트 ───────────────────────────────────────
  static const Color onBackgroundLight = Color(0xFF1A1A1A);
  static const Color onSurfaceLight    = Color(0xFF3D3D3D);
  static const Color subtitleLight     = Color(0xFF888888);

  // ── 라이트: 구분선 ───────────────────────────────────────
  static const Color dividerLight = Color(0xFFE0E0E0);

  // ── 다크: 배경 (디자인 확정 후 채울 것) ──────────────────
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark    = Color(0xFF1E1E1E);
  static const Color cardDark       = Color(0xFF242424);

  // ── 다크: 텍스트 ─────────────────────────────────────────
  static const Color onBackgroundDark = Color(0xFFE8E8E8);
  static const Color onSurfaceDark    = Color(0xFFCCCCCC);
  static const Color subtitleDark     = Color(0xFF888888);

  // ── 다크: 구분선 ─────────────────────────────────────────
  static const Color dividerDark = Color(0xFF2C2C2C);

  // ── 시맨틱: 라이트·다크 공통 ─────────────────────────────
  static const Color like    = Color(0xFFE53935); // 좋아요 활성
  static const Color primary = Color(0xFF2D2D2D); // 주요 액션 버튼
  static const Color error   = Color(0xFFB00020); // 에러 메시지
  static const Color success = Color(0xFF388E3C); // 성공 (예: 중복확인 통과)
  static const Color shimmer = Color(0xFFEEEEEE); // 로딩 스켈레톤
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// D-Write 타이포그래피
///
/// 규칙:
/// - 위젯에서 `TextStyle(...)` 직접 생성 금지.
/// - 반드시 이 클래스의 상수를 참조할 것.
/// - 다크모드 전환 시: color만 AppColors.dark* 로 교체.
class AppTextStyles {
  AppTextStyles._();

  // ── 메인 화면: 문장 본문 (큰 글씨) ──────────────────────
  static const TextStyle sentenceTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.45,
    color: AppColors.onBackgroundLight,
  );

  // ── 메인 화면: 출처 (작품명·저자) ───────────────────────
  static const TextStyle sentenceSource = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.subtitleLight,
  );

  // ── 메인 화면: 날짜 (MM.DD) ──────────────────────────────
  static const TextStyle dateLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
    color: AppColors.subtitleLight,
  );

  // ── 일반: 본문 ───────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onSurfaceLight,
  );

  // ── 일반: 소제목 (메모 목록 등) ──────────────────────────
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.subtitleLight,
  );

  // ── 버튼 ─────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.onBackgroundLight,
  );

  // ── 입력 필드 레이블 ─────────────────────────────────────
  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleLight,
  );

  // ── 에러 메시지 ───────────────────────────────────────────
  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  // ── 성공 메시지 ───────────────────────────────────────────
  static const TextStyle successText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.success,
  );

  // ── 설정 화면: 섹션 제목 ──────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.onBackgroundLight,
  );

  // ── TextTheme 통합 (ThemeData에 등록) ────────────────────
  static const TextTheme textTheme = TextTheme(
    displayLarge: sentenceTitle,   // 문장 본문
    bodyLarge: body,               // 일반 본문
    bodySmall: bodySmall,          // 소제목
    labelLarge: button,            // 버튼
    labelSmall: inputLabel,        // 입력 레이블
  );
}

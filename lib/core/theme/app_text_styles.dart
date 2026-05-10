import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// D-Write 타이포그래피
///
/// UI 전체: Pretendard (단일 family, weight 400/600/700)
/// 메인 문장: Gowun Batang (세리프, google_fonts)
///
/// 위젯에서 색상 변경: style.copyWith(color: AppColorTokens.of(context).textPrimary)
class AppTextStyles {
  AppTextStyles._();

  // ── 메인 화면: 문장 본문 (고운바탕 세리프) ─────────────────
  static TextStyle sentenceBody({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.80,
    letterSpacing: 0,
    color: color ?? AppColors.onBackgroundLight,
  );

  // ── 메인 화면: 저자 ──────────────────────────────────────
  static const TextStyle sentenceSource = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.subtitleLight,
  );

  // ── 메인 화면: 날짜 (MM.DD) ──────────────────────────────
  static const TextStyle dateLabel = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.0,
    letterSpacing: 1.5,
    color: AppColors.subtitleLight,
  );

  // ── 일반: 본문 (목록, 메모 등) ───────────────────────────
  static const TextStyle body = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.65,
    letterSpacing: 0,
    color: AppColors.onSurfaceLight,
  );

  // ── 일반: 소제목 ──────────────────────────────────────────
  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.subtitleLight,
  );

  // ── 섹션 제목 ─────────────────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.onBackgroundLight,
  );

  // ── 버튼 ─────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: 0.1,
    color: AppColors.onBackgroundLight,
  );

  // ── 입력 필드 레이블 ─────────────────────────────────────
  static const TextStyle inputLabel = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.subtitleLight,
  );

  // ── 에러 / 성공 ───────────────────────────────────────────
  static const TextStyle errorText = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  static const TextStyle successText = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.success,
  );

  // ── TextTheme 통합 ────────────────────────────────────────
  static const TextTheme textTheme = TextTheme(
    bodyLarge:   body,
    bodySmall:   bodySmall,
    labelLarge:  button,
    labelSmall:  inputLabel,
    titleMedium: sectionTitle,
  );
}

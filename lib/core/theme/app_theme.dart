import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(AppPalette palette, Brightness brightness) {
    final c = AppColorTokens.forPalette(palette, brightness);
    final isLight = brightness == Brightness.light;

    return ThemeData(
      brightness: brightness,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:          c.accent,
        onPrimary:        isLight ? Colors.white : Colors.black,
        secondary:        c.accentMuted,
        onSecondary:      isLight ? Colors.white : Colors.black,
        surface:          c.surface,
        onSurface:        c.textPrimary,
        error:            c.error,
        onError:          Colors.white,
        outline:          c.divider,
        outlineVariant:   c.divider,
        shadow:           Colors.black,
        scrim:            Colors.black,
        inverseSurface:   c.textPrimary,
        onInverseSurface: c.background,
        inversePrimary:   c.accentMuted,
        surfaceContainerHighest: c.cardSurface,
      ),
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor:    c.textPrimary,
        displayColor: c.textPrimary,
      ),
      dividerColor: c.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.background,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.textPrimary,
          foregroundColor: c.background,
          textStyle: AppTextStyles.button,
          minimumSize: const Size(double.infinity, 48),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          textStyle: AppTextStyles.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTextStyles.inputLabel.copyWith(color: c.textSecondary),
        hintStyle:  AppTextStyles.inputLabel.copyWith(color: c.textTertiary),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(color: c.background),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  // main.dart에서 사용하는 편의 getter
  static ThemeData light(AppPalette palette) => build(palette, Brightness.light);
  static ThemeData dark(AppPalette palette)  => build(palette, Brightness.dark);

  // 하위 호환 (migration 중 참조 유지)
  static ThemeData get lightTheme => light(AppPalette.fog);
  static ThemeData get darkTheme  => dark(AppPalette.fog);
}

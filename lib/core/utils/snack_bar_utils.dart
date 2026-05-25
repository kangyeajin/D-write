import 'package:d_write/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2500),
}) {
  final bgColor = AppColorTokens.of(context).textPrimary.withValues(alpha: 0.85);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      elevation: 0,
      backgroundColor: bgColor,
    ),
  );
}

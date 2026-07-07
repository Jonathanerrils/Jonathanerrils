import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// KNUST palette: cardinal red, gold and green accents.
class AppColors {
  AppColors._();

  static const Color knustRed = Color(0xFFB5121B);
  static const Color knustGold = Color(0xFFFDB515);
  static const Color knustGreen = Color(0xFF006B3F);

  // Driver dashboard demand colours.
  static const Color demandHigh = Color(0xFFD32F2F);
  static const Color demandMedium = Color(0xFFF9A825);
  static const Color demandLow = Color(0xFF2E7D32);

  /// Shared red/amber/green coding used by the list tiles and map badges.
  static Color demandColor(int waitingCount) =>
      waitingCount >= AppConstants.busyThreshold
          ? demandHigh
          : waitingCount >= AppConstants.moderateThreshold
              ? demandMedium
              : demandLow;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.knustRed,
      secondary: AppColors.knustGold,
      tertiary: AppColors.knustGreen,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? AppColors.knustRed
            : scheme.surface,
        foregroundColor: brightness == Brightness.light
            ? Colors.white
            : scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

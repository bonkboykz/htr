import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HTR design tokens (from the Pencil design system).
abstract class AppColors {
  static const accent = Color(0xFF5B5BD6); // indigo — primary / progress / positive
  static const accentSoft = Color(0xFFEEEEFB);
  static const danger = Color(0xFFE5484D); // red — reserved: reab / negative / disclaimer
  static const dangerSoft = Color(0xFFFDECEC);

  static const bg = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFECEEF1);

  static const textPrimary = Color(0xFF14161A);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9AA1AC);

  static const water = Color(0xFF3B82F6);
  static const sleep = Color(0xFF8B5CF6);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF22C55E);
}

abstract class AppRadii {
  static const card = 20.0;
  static const inner = 14.0;
  static const pill = 999.0;
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    ),
  );

  final display = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
  final body = GoogleFonts.interTextTheme(base.textTheme);
  final textTheme = body
      .copyWith(
        displayLarge: display.displayLarge,
        displayMedium: display.displayMedium,
        displaySmall: display.displaySmall,
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      )
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.textPrimary,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accentSoft,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.inner),
        ),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

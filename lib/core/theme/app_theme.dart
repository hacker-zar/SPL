import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color asphalt = Color(0xFF0B0E10);
  static const Color surface = Color(0xFF15191C);
  static const Color surfaceRaised = Color(0xFF1D2226);
  static const Color outline = Color(0xFF2C3338);

  static const Color roadYellow = Color(0xFFF5C518);
  static const Color roadYellowDim = Color(0xFF8A6F0F);

  static const Color textPrimary = Color(0xFFF4F4F2);
  static const Color textSecondary = Color(0xFFA6ADB2);
  static const Color textOnYellow = Color(0xFF0B0E10);

  static const Color decisionGo = Color(0xFF2ECC71);
  static const Color decisionLow = Color(0xFFFF9F1C);
  static const Color decisionStop = Color(0xFFE74C3C);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => dark();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.roadYellow,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.surface,
      primary: AppColors.roadYellow,
      onPrimary: AppColors.textOnYellow,
      secondary: AppColors.roadYellow,
      error: AppColors.decisionStop,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    final displayFont = GoogleFonts.oswaldTextTheme();
    final bodyFont = GoogleFonts.interTextTheme();
    final textTheme = bodyFont.copyWith(
      headlineSmall: displayFont.headlineSmall?.copyWith(
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      titleLarge: displayFont.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: bodyFont.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      labelLarge: bodyFont.labelLarge?.copyWith(
        color: AppColors.textPrimary,
      ),
      labelMedium: bodyFont.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
      bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.textPrimary),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.asphalt,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.asphalt,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: displayFont.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        helperStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.roadYellow),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.roadYellow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.roadYellow, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.roadYellow,
          foregroundColor: AppColors.textOnYellow,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.roadYellow),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      dividerTheme: const DividerThemeData(color: AppColors.outline),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.roadYellow;
          }
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.roadYellowDim;
          }
          return AppColors.outline;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surfaceRaised,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: AppColors.roadYellow,
          selectedForegroundColor: AppColors.textOnYellow,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
      ),
    );
  }
}

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Resumer's blue product palette.
///
/// Legacy token names are retained so every existing feature inherits the new
/// visual system without changing layout or behavior.
abstract final class AppColors {
  static const Color primaryBlue = Color(0xFF1677E8);
  static const Color darkBlue = Color(0xFF0B3D91);
  static const Color brightBlue = Color(0xFF2196F3);
  static const Color lightBlue = Color(0xFFEAF4FF);
  static const Color veryLightBlue = Color(0xFFF5FAFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color border = Color(0xFFDCE8F5);

  static const Color ink = primaryText;
  static const Color inkSoft = darkBlue;
  static const Color paper = white;
  static const Color canvas = veryLightBlue;
  static const Color stone = secondaryText;
  static const Color line = border;
  static const Color sage = primaryBlue;
  static const Color sageSoft = lightBlue;

  static const Color violet = primaryBlue;
  static const Color violetDeep = darkBlue;
  static const Color violetSoft = brightBlue;
  static const Color cyan = primaryBlue;
  static const Color cyanBright = brightBlue;
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeSoft = Color(0x18F59E0B);

  static const List<Color> prism = [primaryBlue, brightBlue];
  static const List<Color> prismHot = [darkBlue, primaryBlue];

  static const Color darkBg = Color(0xFF071A38);
  static const Color darkSurface = Color(0xFF0B2348);
  static const Color darkSurfaceSubtle = Color(0xFF10315F);
  static const Color darkBorder = Color(0x335B9EF0);
  static const Color darkBorderStrong = Color(0x556EAFF7);
  static const Color darkMuted = Color(0xFFA9BDD6);

  static const Color lightBg = white;
  static const Color lightSurface = white;
  static const Color lightMuted = secondaryText;
  static const Color lightBorder = border;

  static const Color success = Color(0xFF16A34A);
  static const Color successSubtle = Color(0x1816A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSubtle = Color(0x18F59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSubtle = Color(0x18DC2626);
  static const Color info = primaryBlue;
  static const Color infoSubtle = Color(0x181677E8);
}

abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.paper;
    final background = dark ? AppColors.darkBg : AppColors.white;
    final onSurface = dark ? AppColors.white : AppColors.primaryText;
    final muted = dark ? AppColors.darkMuted : AppColors.stone;
    final border = dark ? AppColors.darkBorder : AppColors.line;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppColors.brightBlue : AppColors.primaryBlue,
      onPrimary: AppColors.white,
      secondary: dark ? AppColors.brightBlue : AppColors.primaryBlue,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    const radius = BorderRadius.all(Radius.circular(14));
    final outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dialogTheme: DialogThemeData(backgroundColor: surface),
      dividerColor: border,
      fontFamilyFallback: const [
        'Inter',
        'SF Pro Display',
        'Roboto',
        'sans-serif'
      ],
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 40,
          height: 1.02,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.7,
          color: dark ? AppColors.white : AppColors.darkBlue,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.08,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.0,
          color: dark ? AppColors.white : AppColors.darkBlue,
        ),
        headlineSmall: TextStyle(
          fontSize: 23,
          height: 1.14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: dark ? AppColors.white : AppColors.darkBlue,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
          color: dark ? AppColors.white : AppColors.darkBlue,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: onSurface),
        bodyMedium: TextStyle(fontSize: 14, height: 1.48, color: onSurface),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: dark ? AppColors.white : AppColors.darkBlue,
        ),
        iconTheme: IconThemeData(
          color: dark ? AppColors.brightBlue : AppColors.primaryBlue,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted.withValues(alpha: .8)),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(
          color: dark ? AppColors.brightBlue : AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: dark ? AppColors.brightBlue : AppColors.primaryBlue,
            width: 1.4,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        disabledColor: Colors.transparent,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: onSurface),
        secondaryLabelStyle: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: muted.withValues(alpha: .2),
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
          minimumSize: const Size(48, 50),
          side: BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 1,
        shadowColor: AppColors.primaryBlue.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkBlue : AppColors.primaryText,
        contentTextStyle: const TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? AppColors.brightBlue : AppColors.primaryBlue)
              : muted.withValues(alpha: .3),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dark ? AppColors.brightBlue : AppColors.primaryBlue,
        circularTrackColor: border,
        linearTrackColor: border,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
        thumbColor: dark ? AppColors.brightBlue : AppColors.primaryBlue,
        inactiveTrackColor: border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

class CnTheme {
  const CnTheme._();

  static ThemeData light() => _build(CnColors.light, Brightness.light);
  static ThemeData dark() => _build(CnColors.dark, Brightness.dark);

  static ThemeData _build(CnColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.accent,
      onPrimary: c.accentFg,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accentText,
      secondary: c.accentText,
      onSecondary: c.accentFg,
      error: c.danger,
      onError: c.accentFg,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.fg,
      onSurfaceVariant: c.fg2,
      outline: c.borderStrong,
      outlineVariant: c.border,
      surfaceContainerHighest: c.sunken,
      surfaceContainerLow: c.canvas,
    );

    TextStyle t(
      double size,
      FontWeight w, {
      double? h,
      double? ls,
      Color? color,
    }) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: w,
      height: h,
      letterSpacing: ls,
      color: color ?? c.fg,
    );

    final text = TextTheme(
      headlineMedium: t(26, FontWeight.w600, h: 1.25, ls: -0.5),
      titleLarge: t(20, FontWeight.w600, h: 1.3, ls: -0.3),
      titleMedium: t(16, FontWeight.w600, h: 1.4),
      titleSmall: t(14, FontWeight.w600, h: 1.4),
      bodyLarge: t(16, FontWeight.w400, h: 1.5),
      bodyMedium: t(14, FontWeight.w400, h: 1.5),
      bodySmall: t(12.5, FontWeight.w400, h: 1.45, color: c.muted),
      labelLarge: t(15, FontWeight.w600, h: 1.2),
      labelMedium: t(13, FontWeight.w500, h: 1.2),
      labelSmall: t(12, FontWeight.w500, h: 1.2, color: c.muted),
    );

    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CnSpace.radius),
          borderSide: BorderSide(color: color, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      textTheme: text,
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(c.borderStrong),
        enabledBorder: border(c.borderStrong),
        focusedBorder: border(c.accent, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
        disabledBorder: border(c.border),
        labelStyle: t(14, FontWeight.w400, color: c.muted),
        floatingLabelStyle: t(13, FontWeight.w500, color: c.accentText),
        helperStyle: text.bodySmall,
        errorStyle: t(12.5, FontWeight.w500, color: c.danger),
        hintStyle: t(15, FontWeight.w400, color: c.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.fg,
        contentTextStyle: t(14, FontWeight.w500, color: c.canvas),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnSpace.radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnSpace.radiusLg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => t(
            12,
            s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.accentText : c.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.accentText : c.muted,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: c.borderStrong, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.border,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

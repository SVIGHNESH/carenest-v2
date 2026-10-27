import 'package:flutter/material.dart';

/// CareNest brand tokens. Values are the admin panel's OKLCH palette
/// converted to sRGB (accent hue 258, cool near-neutral surfaces).
/// Light success, info and warning are about 0.03-0.07 darker in lightness
/// than the admin values so text on their soft backgrounds reaches 4.5:1.
@immutable
class CnColors extends ThemeExtension<CnColors> {
  const CnColors({
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.border,
    required this.borderStrong,
    required this.fg,
    required this.fg2,
    required this.muted,
    required this.subtle,
    required this.accent,
    required this.accentHover,
    required this.accentFg,
    required this.accentSoft,
    required this.accentText,
    required this.success,
    required this.successSoft,
    required this.info,
    required this.infoSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color canvas, surface, sunken, border, borderStrong;
  final Color fg, fg2, muted, subtle;
  final Color accent, accentHover, accentFg, accentSoft, accentText;
  final Color success,
      successSoft,
      info,
      infoSoft,
      warning,
      warningSoft,
      danger,
      dangerSoft;

  static const light = CnColors(
    canvas: Color(0xFFFAFBFD),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFF3F5F9),
    border: Color(0xFFE1E4EA),
    borderStrong: Color(0xFFC9CCD3),
    fg: Color(0xFF131720),
    fg2: Color(0xFF444850),
    muted: Color(0xFF6D7078),
    subtle: Color(0xFF91959B),
    accent: Color(0xFF1F70DE),
    accentHover: Color(0xFF005DC9),
    accentFg: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE1F3FF),
    accentText: Color(0xFF005DC9),
    success: Color(0xFF107C40),
    successSoft: Color(0xFFE2F8E7),
    info: Color(0xFF0071A7),
    infoSoft: Color(0xFFDFF5FF),
    warning: Color(0xFF945A00),
    warningSoft: Color(0xFFFFEED7),
    danger: Color(0xFFC5353E),
    dangerSoft: Color(0xFFFFE9E7),
  );

  static const dark = CnColors(
    canvas: Color(0xFF090A0D),
    surface: Color(0xFF101215),
    sunken: Color(0xFF17191C),
    border: Color(0xFF222429),
    borderStrong: Color(0xFF36383E),
    fg: Color(0xFFF3F4F7),
    fg2: Color(0xFFBBBEC3),
    muted: Color(0xFF898C93),
    subtle: Color(0xFF61656C),
    accent: Color(0xFF3483F3),
    accentHover: Color(0xFF4795FF),
    accentFg: Color(0xFF080A0E),
    accentSoft: Color(0xFF102B51),
    accentText: Color(0xFF7AB2FF),
    success: Color(0xFF5FCB82),
    successSoft: Color(0xFF16321F),
    info: Color(0xFF5CB9EC),
    infoSoft: Color(0xFF102F40),
    warning: Color(0xFFF3AE51),
    warningSoft: Color(0xFF3D290E),
    danger: Color(0xFFF66C6D),
    dangerSoft: Color(0xFF481E1D),
  );

  @override
  CnColors copyWith() => this;

  @override
  CnColors lerp(ThemeExtension<CnColors>? other, double t) =>
      t < 0.5 ? this : (other as CnColors? ?? this);
}

extension CnContext on BuildContext {
  CnColors get cn => Theme.of(this).extension<CnColors>()!;
}

/// Spacing and radius scale.
class CnSpace {
  const CnSpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double radius = 12, radiusSm = 8, radiusLg = 16;
  static const double minTap = 48;
  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );
}

import 'dart:math' as math;

import 'package:carenest/ui/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final entry in {
    'light': CnColors.light,
    'dark': CnColors.dark,
  }.entries) {
    final c = entry.value;
    group('${entry.key} contrast >= 4.5', () {
      final pairs = <String, (Color, Color)>{
        'fg on canvas': (c.fg, c.canvas),
        'fg on surface': (c.fg, c.surface),
        'fg2 on surface': (c.fg2, c.surface),
        'muted on surface': (c.muted, c.surface),
        'muted on canvas': (c.muted, c.canvas),
        'muted on sunken': (c.muted, c.sunken),
        'accentFg on accent': (c.accentFg, c.accent),
        'accentText on accentSoft': (c.accentText, c.accentSoft),
        'accentText on surface': (c.accentText, c.surface),
        'success on successSoft': (c.success, c.successSoft),
        'warning on warningSoft': (c.warning, c.warningSoft),
        'danger on dangerSoft': (c.danger, c.dangerSoft),
        'info on infoSoft': (c.info, c.infoSoft),
        'danger on surface': (c.danger, c.surface),
        'fg on warningSoft': (c.fg, c.warningSoft),
        'fg on infoSoft': (c.fg, c.infoSoft),
        'fg on dangerSoft': (c.fg, c.dangerSoft),
        'accentFg on danger': (c.accentFg, c.danger),
        'fg2 on sunken': (c.fg2, c.sunken),
      };
      pairs.forEach((name, p) {
        test(
          name,
          () => expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5)),
        );
      });
    });
  }
}

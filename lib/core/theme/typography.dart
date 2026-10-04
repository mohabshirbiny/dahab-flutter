import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Font families bundled in pubspec.yaml.
abstract final class DFonts {
  static const inter = 'Inter';
  static const arabic = 'IBMPlexSansArabic';
  static const serif = 'InstrumentSerif';
  static const logo = 'PlayfairDisplay';

  /// `body{font-feature-settings:"tnum" 1}` plus the per-language family
  /// (`body.ar{font-family:'IBM Plex Sans Arabic',Inter,...}`).
  static TextStyle base({required bool arabic}) => TextStyle(
    fontFamily: arabic ? DFonts.arabic : inter,
    fontFamilyFallback: arabic ? const [inter] : const [DFonts.arabic],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: DColors.ink,
    fontSize: 14,
  );
}

/// Text styles mirroring the prototype's utility classes. They carry no
/// font family so they inherit the language-specific one from
/// [DefaultTextStyle].
abstract final class DText {
  /// `h2{font-size:19px;font-weight:600;line-height:1.3}`
  static const h2 = TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3);

  /// `h3{font-size:16px;font-weight:600}`
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// `.muted{color:var(--ink-2);font-size:13px;line-height:1.6}`
  static const muted = TextStyle(fontSize: 13, color: DColors.ink2, height: 1.6);

  /// `.muted` at 12px, the most common inline override.
  static const muted12 = TextStyle(fontSize: 12, color: DColors.ink2, height: 1.6);

  /// `.tiny{color:var(--ink-3);font-size:11px;line-height:1.55}`
  static const tiny = TextStyle(fontSize: 11, color: DColors.ink3, height: 1.55);

  /// `.label{font-size:12px;font-weight:500;color:var(--ink-3)}`
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: DColors.ink3);

  /// `.big{font-size:26px;font-weight:600;letter-spacing:-.4px}`
  static const big = TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.4);

  /// `.price{font-size:20px;font-weight:600}`
  static const price = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

  /// 14px/500 — card titles (`font-size:14px;font-weight:500`).
  static const title = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  /// 13px body text used in rows.
  static const body13 = TextStyle(fontSize: 13);

  /// 14px body text.
  static const body14 = TextStyle(fontSize: 14);

  /// Gold inline link, 11px (`.tiny` + `color:var(--gold)`).
  static const linkTiny = TextStyle(fontSize: 11, color: DColors.gold, height: 1.55);

  /// Gold inline link, 13px.
  static const link13 = TextStyle(fontSize: 13, color: DColors.gold);

  /// Gold inline link, 12px.
  static const link12 = TextStyle(fontSize: 12, color: DColors.gold);

  /// Serif accent (`font-family:"Instrument Serif"`).
  static const serif = TextStyle(fontFamily: DFonts.serif, fontFeatures: []);
}

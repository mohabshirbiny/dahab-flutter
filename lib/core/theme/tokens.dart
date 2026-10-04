import 'package:flutter/widgets.dart';

/// Colour tokens, taken 1:1 from the `:root` block of
/// `doc/dahab-app-prototype.html`.
abstract final class DColors {
  static const ink = Color(0xFF1A1A1A);
  static const ink2 = Color(0xFF5F5E5A);
  static const ink3 = Color(0xFF8E8C85);
  static const paper = Color(0xFFF6F5F2);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E0D9);
  static const line2 = Color(0xFFC9C5BC);
  static const gold = Color(0xFF8B6F3D);

  static const ok = Color(0xFF0F6E56);
  static const okDark = Color(0xFF085041);
  static const okBg = Color(0xFFE1F5EE);
  static const wait = Color(0xFF854F0B);
  static const waitBg = Color(0xFFFAEEDA);
  static const bad = Color(0xFFA32D2D);
  static const badBg = Color(0xFFFCEBEB);
  static const warn = Color(0xFF8A5A00);
  static const warnBg = Color(0xFFFBEECF);

  /// Page background behind the phone container on desktop.
  static const desk = Color(0xFFDCDAD4);

  /// Splash (dark) palette.
  static const splashText = Color(0xFFB4B2A9);
  static const splashLine = Color(0xFF33312E);
  static const splashCard = Color(0xFF232220);
  static const splashGhostBorder = Color(0xFF4A4844);
  static const splashFaint = Color(0xFF6E6C67);

  static const logoDot = Color(0xFFD4AF37);
  static const star = Color(0xFFD4A340);
  static const yoursBg = Color(0xFFF1EBDD);
  static const mmTag = Color(0xFF1F6B4C);
  static const modalBarrier = Color(0x73141414); // rgba(20,20,20,.45)
}

/// Radii used across the prototype.
abstract final class DRadius {
  static const phone = 26.0;
  static const card = 14.0;
  static const soft = 12.0;
  static const slot = 11.0;
  static const button = 10.0;
  static const note = 10.0;
  static const input = 9.0;
  static const seg = 9.0;
  static const modal = 16.0;
  static const pill = 6.0;
}

/// Layout constants.
abstract final class DLayout {
  /// `.phone{max-width:390px}`
  static const phoneWidth = 390.0;

  /// `height:min(840px, calc(100vh - 40px))`
  static const phoneHeight = 840.0;

  /// Below this width the phone container goes full-bleed
  /// (`@media (max-width:430px)`).
  static const fullBleedBreakpoint = 430.0;

  /// `.pad{padding:16px}`
  static const pad = 16.0;
}

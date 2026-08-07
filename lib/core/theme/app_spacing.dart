import 'package:flutter/widgets.dart';

/// Escala de espacamento base 4. Nenhuma View usa numero solto em padding/gap.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Alvo minimo de toque. O voluntario opera em pe, no celular, com pressa —
  /// nenhum controle interativo pode ficar abaixo disto.
  static const double touchTarget = 48;

  /// Alvo confortavel para os botoes principais do PDV.
  static const double touchTargetLarge = 64;

  // Gaps prontos (evita SizedBox com numero magico espalhado).
  static const Widget gapXs = SizedBox(width: xs, height: xs);
  static const Widget gapSm = SizedBox(width: sm, height: sm);
  static const Widget gapMd = SizedBox(width: md, height: md);
  static const Widget gapLg = SizedBox(width: lg, height: lg);
  static const Widget gapXl = SizedBox(width: xl, height: xl);
  static const Widget gapXxl = SizedBox(width: xxl, height: xxl);
}

/// Raios de canto.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Duracoes de animacao — consistencia de "peso" entre telas.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

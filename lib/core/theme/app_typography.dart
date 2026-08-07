import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia unica do sistema.
///
/// Nao usamos fonte customizada de proposito: o app roda em Flutter Web dentro da
/// igreja, muitas vezes em rede ruim — a fonte de sistema carrega instantaneamente e
/// nao gera flash de texto invisivel.
abstract final class AppTypography {
  static const String? fontFamily = null; // fonte de sistema

  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );

  /// Valores monetarios — tabular para os digitos nao "dancarem" ao atualizar.
  static const TextStyle money = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  /// Total da venda em destaque no PDV.
  static const TextStyle moneyLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  /// Senha do pedido na TV — precisa ser legivel do outro lado do salao.
  static const TextStyle tvSenha = TextStyle(
    fontSize: 96,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: 2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: label,
  );
}

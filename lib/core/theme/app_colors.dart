import 'package:flutter/material.dart';

/// Paleta unica do sistema, derivada da logo do Espaco Cafe
/// (circulo preto, tracos off-white com leve tom rosado).
///
/// REGRA: nenhuma View pode declarar `Color(0xFF...)` inline.
/// Cor nova entra aqui primeiro, com nome semantico.
abstract final class AppColors {
  // --- Marca -----------------------------------------------------------------
  /// Preto da logo. Fundo principal do app.
  static const Color brandBlack = Color(0xFF0D0D0D);

  /// Off-white levemente rosado dos tracos da logo. Texto e bordas.
  static const Color brandCream = Color(0xFFF5F0F2);

  /// Rosa claro de acento — usado com parcimonia (foco, selecao, destaque).
  static const Color brandRose = Color(0xFFE8B4C8);

  /// Marrom do cafe — acento secundario (graficos, icones de produto).
  static const Color brandCoffee = Color(0xFF8B5E3C);

  // --- Superficies -----------------------------------------------------------
  static const Color background = brandBlack;
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color border = Color(0xFF333333);
  static const Color borderFocus = brandRose;

  // --- Texto -----------------------------------------------------------------
  static const Color textPrimary = brandCream;
  static const Color textSecondary = Color(0xFFA8A0A3);
  static const Color textDisabled = Color(0xFF5C5659);
  static const Color textOnAccent = brandBlack;

  // --- Semanticas ------------------------------------------------------------
  /// Venda concluida, estoque saudavel.
  static const Color success = Color(0xFF4CAF7D);

  /// Estoque no minimo — o alerta que motivou o sistema.
  static const Color warning = Color(0xFFE0A458);

  /// Erro, estoque zerado, falha de rede.
  static const Color danger = Color(0xFFD9534F);

  static const Color info = Color(0xFF5B9BD5);

  // --- Tipos de venda (usado no PDV e no grafico de pizza) --------------------
  static const Color vendaPix = Color(0xFF32BCAD); // verde-agua do Pix
  static const Color vendaDinheiro = success;
  static const Color vendaCartao = info;
  static const Color vendaCortesia = brandRose;

  /// Sequencia para graficos categoricos (ordem estavel = cor estavel).
  static const List<Color> chartSequence = <Color>[
    brandRose,
    vendaPix,
    warning,
    info,
    brandCoffee,
    success,
  ];

  // --- Status de pedido (fase 2 / TV) ----------------------------------------
  static const Color statusRecebido = textSecondary;
  static const Color statusPreparando = warning;
  static const Color statusPronto = success;
  static const Color statusEntregue = textDisabled;
}

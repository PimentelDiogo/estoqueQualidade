import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/money_formatter.dart';

/// Exibe valor monetario com digitos tabulares (nao "dancam" ao atualizar o total).
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.style,
    this.color,
    this.large = false,
    this.compact = false,
  });

  final num value;
  final TextStyle? style;
  final Color? color;

  /// Total da venda em destaque.
  final bool large;

  /// `R$ 1,2 mil` — para cards de relatorio com espaco curto.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        style ?? (large ? AppTypography.moneyLarge : AppTypography.money);

    return Text(
      compact ? Money.compact(value) : Money.format(value),
      style: base.copyWith(color: color ?? base.color),
    );
  }
}

/// Rotulo + valor, o par que aparece em todo card de relatorio e no carrinho.
class MoneyLabelValue extends StatelessWidget {
  const MoneyLabelValue({
    required this.label,
    required this.value,
    super.key,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final num value;

  /// Linha do total — texto maior e mais forte.
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: emphasis
              ? AppTypography.titleMedium
              : AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        MoneyText(value, large: emphasis, color: valueColor),
      ],
    );
  }
}

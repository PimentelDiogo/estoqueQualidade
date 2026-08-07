import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Etiqueta de status (tipo de venda, situacao do estoque, status do pedido).
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Situacao do estoque a partir da quantidade — a leitura que o voluntario
  /// precisa fazer em meio segundo.
  factory AppBadge.estoque({required int quantidade, required int minimo}) {
    if (quantidade <= 0) {
      return const AppBadge(
        label: 'Esgotado',
        color: AppColors.danger,
        icon: Icons.remove_shopping_cart_outlined,
      );
    }
    if (quantidade <= minimo) {
      return const AppBadge(
        label: 'Acabando',
        color: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
    }
    return const AppBadge(
      label: 'Ok',
      color: AppColors.success,
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contador circular para o menu (ex.: "3" alertas de estoque abertos).
class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    super.key,
    this.color = AppColors.danger,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    // Sem `alignment:` no Container de proposito: com ele, o widget se estica
    // para toda a largura disponivel sempre que o pai da constraint frouxa
    // (dentro de um Wrap ou Column, por exemplo). O Row com mainAxisSize.min
    // faz o badge se dimensionar pelo conteudo em qualquer contexto.
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            count > 99 ? '99+' : '$count',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandCream,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

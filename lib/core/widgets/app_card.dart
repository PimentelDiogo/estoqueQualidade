import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Cartao padrao do sistema. Substitui `Container` com `BoxDecoration` avulso —
/// sem isto, cada tela reinventa borda e raio (o erro que o `englishIA` cometeu).
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  /// Destaca com a cor de acento (ex.: produto ja no carrinho do PDV).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color effectiveBorder =
        borderColor ?? (selected ? AppColors.brandRose : AppColors.border);

    return Material(
      color: color ?? AppColors.surface,
      borderRadius: AppRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: effectiveBorder, width: selected ? 2 : 1),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

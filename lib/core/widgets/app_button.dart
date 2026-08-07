import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

enum AppButtonSize {
  /// Altura 48 — padrao.
  normal,

  /// Altura 64 — acoes principais do PDV ("Finalizar venda").
  large,
}

/// Botao unico do sistema.
///
/// Cuida de tres coisas que toda tela erraria sozinha: alvo minimo de toque,
/// estado de carregando (bloqueia clique duplo — caixa com pressa clica duas vezes
/// e registraria duas vendas) e largura total no mobile.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.normal,
    this.loading = false,
    this.expanded = false,
  });

  final String label;

  /// `null` desabilita o botao.
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Enquanto `true`, mostra spinner e **ignora** toques.
  final bool loading;

  /// Ocupa toda a largura disponivel.
  final bool expanded;

  double get _height => switch (size) {
    AppButtonSize.normal => AppSpacing.touchTarget,
    AppButtonSize.large => AppSpacing.touchTargetLarge,
  };

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnPressed = loading ? null : onPressed;

    final Widget content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == AppButtonVariant.primary
                  ? AppColors.textOnAccent
                  : AppColors.textPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: size == AppButtonSize.large ? 24 : 20),
                AppSpacing.gapSm,
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(minimumSize: Size(0, _height)),
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(minimumSize: Size(0, _height)),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.brandCream,
          minimumSize: Size(0, _height),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(minimumSize: Size(0, _height)),
        child: content,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

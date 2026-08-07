import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'responsive_layout.dart';

/// Scaffold padrao de pagina interna.
///
/// Aplica [ResponsiveBody] automaticamente, entao nenhuma tela precisa lembrar de
/// limitar largura e padding — a responsividade vem de graca.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
    this.leading,
    this.scrollable = false,
    this.maxWidth,
    this.padded = true,
  });

  final String title;

  /// Segunda linha do cabecalho — usada para mostrar o ministerio ativo.
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Barra fixa no rodape (ex.: total + "Finalizar venda" no PDV).
  final Widget? bottomBar;
  final Widget? leading;
  final bool scrollable;
  final ResponsiveValue<double>? maxWidth;

  /// `false` quando a propria tela controla o padding (ex.: lista full-bleed).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: AppTypography.titleLarge),
            if (subtitle != null)
              Text(subtitle!, style: AppTypography.bodySmall),
          ],
        ),
        actions: <Widget>[
          ...?actions,
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: padded
            ? ResponsiveBody(
                maxWidth: maxWidth,
                scrollable: scrollable,
                child: body,
              )
            : body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: bottomBar,
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/result.dart';
import 'app_button.dart';

/// Estado vazio / erro / carregando — os tres unicos jeitos de uma lista nao ter
/// conteudo. Centralizado para o app inteiro falar a mesma lingua.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.titulo,
    super.key,
    this.descricao,
    this.icone = Icons.inbox_outlined,
    this.corIcone,
    this.acaoLabel,
    this.onAcao,
  });

  final String titulo;
  final String? descricao;
  final IconData icone;
  final Color? corIcone;
  final String? acaoLabel;
  final VoidCallback? onAcao;

  /// Erro honesto: mostra a mensagem em portugues da [AppFailure] e so oferece
  /// "Tentar de novo" quando faz sentido (falha de rede).
  factory EmptyState.erro(AppFailure failure, {VoidCallback? onTentarDeNovo}) =>
      EmptyState(
        titulo: 'Nao foi possivel carregar',
        descricao: failure.mensagem,
        icone: switch (failure.kind) {
          FailureKind.rede => Icons.wifi_off_outlined,
          FailureKind.permissao => Icons.lock_outline,
          FailureKind.autenticacao => Icons.person_off_outlined,
          _ => Icons.error_outline,
        },
        corIcone: AppColors.danger,
        acaoLabel: failure.podeTentarDeNovo && onTentarDeNovo != null
            ? 'Tentar de novo'
            : null,
        onAcao: failure.podeTentarDeNovo ? onTentarDeNovo : null,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icone, size: 56, color: corIcone ?? AppColors.textDisabled),
            AppSpacing.gapLg,
            Text(
              titulo,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (descricao != null) ...<Widget>[
              AppSpacing.gapSm,
              Text(
                descricao!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (acaoLabel != null && onAcao != null) ...<Widget>[
              AppSpacing.gapXl,
              AppButton(
                label: acaoLabel!,
                onPressed: onAcao,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carregando padrao.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.mensagem});

  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: AppColors.brandRose),
          if (mensagem != null) ...<Widget>[
            AppSpacing.gapLg,
            Text(mensagem!, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

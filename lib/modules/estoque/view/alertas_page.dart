import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/estoque.dart';
import '../viewmodel/estoque_viewmodel.dart';
import 'widgets/movimentacao_dialog.dart';

/// Produtos no minimo ou esgotados — a tela que resolve o problema original:
/// descobrir que o cafe acabou **antes** do culto, nao durante.
class AlertasPage extends GetView<EstoqueViewModel> {
  const AlertasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppShell(
        rotaAtual: Rotas.alertas,
        alertasAbertos: controller.totalAlertas,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Alertas de estoque'),
            actions: <Widget>[
              const ContextoMinisterio(),
              AppSpacing.gapSm,
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh),
                onPressed: controller.carregar,
              ),
              AppSpacing.gapSm,
            ],
          ),
          body: SafeArea(
            child: ResponsiveBody(
              child: Obx(() {
                if (controller.carregando.value && controller.alertas.isEmpty) {
                  return const AppLoading();
                }

                if (controller.alertas.isEmpty) {
                  return const EmptyState(
                    titulo: 'Tudo em ordem',
                    descricao:
                        'Nenhum produto abaixo do estoque minimo. '
                        'Voce sera avisado aqui e por e-mail quando algum ficar.',
                    icone: Icons.check_circle_outline,
                    corIcone: AppColors.success,
                  );
                }

                return ListView.separated(
                  itemCount: controller.alertas.length,
                  separatorBuilder: (BuildContext ctx, int i) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int i) =>
                      _CardAlerta(alerta: controller.alertas[i]),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAlerta extends GetView<EstoqueViewModel> {
  const _CardAlerta({required this.alerta});

  final AlertaEstoque alerta;

  @override
  Widget build(BuildContext context) {
    final Color cor = alerta.esgotado ? AppColors.danger : AppColors.warning;

    return AppCard(
      borderColor: cor.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                alerta.esgotado
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.warning_amber_rounded,
                color: cor,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  alerta.produtoNome,
                  style: AppTypography.titleMedium,
                ),
              ),
              AppBadge.estoque(
                quantidade: alerta.quantidade,
                minimo: alerta.estoqueMinimo,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            'Restam ${alerta.quantidade} '
            '(minimo ${alerta.estoqueMinimo}). '
            'Repor ao menos ${alerta.faltamParaOMinimo} para sair do alerta.',
            style: AppTypography.bodySmall,
          ),
          AppSpacing.gapSm,
          Row(
            children: <Widget>[
              Icon(
                alerta.emailEnviado
                    ? Icons.mark_email_read_outlined
                    : Icons.schedule_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  alerta.emailEnviado
                      ? 'E-mail enviado ao responsavel'
                      : 'Aviso por e-mail ainda nao enviado',
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Repor estoque',
                  icon: Icons.add_box_outlined,
                  onPressed: () {
                    final produto = controller.produtos
                        .where((p) => p.id == alerta.produtoId)
                        .firstOrNull;
                    if (produto == null) return;
                    showDialog<void>(
                      context: context,
                      builder: (_) => MovimentacaoDialog(produto: produto),
                    );
                  },
                ),
              ),
              if (alerta.alertaId != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Ja resolvi',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => controller.resolverAlerta(alerta.alertaId!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

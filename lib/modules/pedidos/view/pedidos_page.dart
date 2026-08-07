import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pedido.dart';
import '../viewmodel/pedidos_viewmodel.dart';

/// Fila de pedidos do lado do caixa: avançar status e cobrar.
class PedidosPage extends GetView<PedidosViewModel> {
  const PedidosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      rotaAtual: Rotas.pedidos,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pedidos'),
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
              if (controller.carregando.value && controller.pedidos.isEmpty) {
                return const AppLoading();
              }

              final falha = controller.falha.value;
              if (falha != null && controller.pedidos.isEmpty) {
                return EmptyState.erro(
                  falha,
                  onTentarDeNovo: controller.carregar,
                );
              }

              if (controller.pedidos.isEmpty) {
                return const EmptyState(
                  titulo: 'Nenhum pedido na fila',
                  descricao:
                      'Os pedidos feitos pelo QR das mesas aparecem aqui.',
                  icone: Icons.receipt_long_outlined,
                );
              }

              return ListView.separated(
                itemCount: controller.pedidos.length,
                separatorBuilder: (BuildContext ctx, int i) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) =>
                    _CardPedido(pedido: controller.pedidos[i]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CardPedido extends GetView<PedidosViewModel> {
  const _CardPedido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: pedido.status.cor.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pedido.status.cor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: pedido.status.cor),
                ),
                child: Text(
                  pedido.senha,
                  style: AppTypography.headlineMedium.copyWith(
                    color: pedido.status.cor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pedido.clienteNome ?? 'Sem nome',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${pedido.mesaIdentificador ?? 'Mesa'} · '
                      '${Datas.hora(pedido.criadoEm)} · '
                      '${pedido.espera.inMinutes} min',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              AppBadge(label: pedido.status.label, color: pedido.status.cor),
            ],
          ),

          const Divider(height: AppSpacing.xl),

          for (final PedidoItem item in pedido.itens)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${item.quantidade}x',
                      style: AppTypography.money,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.produtoNome,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  MoneyText(item.subtotal),
                ],
              ),
            ),

          if (pedido.observacao != null) ...<Widget>[
            AppSpacing.gapSm,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.brSm,
              ),
              child: Text(
                pedido.observacao!,
                style: AppTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const Divider(height: AppSpacing.xl),
          MoneyLabelValue(
            label: 'Total',
            value: pedido.total,
            emphasis: true,
            valueColor: pedido.cobrado ? AppColors.success : null,
          ),

          AppSpacing.gapLg,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              if (pedido.proximoStatus != null)
                AppButton(
                  label: switch (pedido.proximoStatus!) {
                    StatusPedido.preparando => 'Iniciar preparo',
                    StatusPedido.pronto => 'Marcar pronto',
                    StatusPedido.entregue => 'Entregar',
                    _ => 'Avancar',
                  },
                  icon: Icons.arrow_forward,
                  onPressed: () => controller.avancar(pedido),
                ),

              // Cobrar é o passo que baixa o estoque (via fn_registrar_venda).
              if (!pedido.cobrado)
                AppButton(
                  label: 'Cobrar',
                  icon: Icons.point_of_sale,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _abrirCobranca(context),
                )
              else
                const AppBadge(
                  label: 'Cobrado',
                  color: AppColors.success,
                  icon: Icons.check,
                ),

              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                onPressed: () => controller.cancelar(pedido.id),
              ),
            ],
          ),

          Obx(() {
            final falha = controller.falha.value;
            if (falha == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                falha.mensagem,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _abrirCobranca(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _CobrarDialog(pedido: pedido),
    );
  }
}

class _CobrarDialog extends GetView<PedidosViewModel> {
  const _CobrarDialog({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Cobrar senha ${pedido.senha}',
                style: AppTypography.headlineMedium,
              ),
              AppSpacing.gapMd,
              MoneyLabelValue(
                label: 'Total',
                value: pedido.total,
                emphasis: true,
              ),
              AppSpacing.gapXl,
              Text('Como o cliente pagou?', style: AppTypography.label),
              AppSpacing.gapSm,
              for (final TipoVenda t in TipoVenda.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppButton(
                    label: t.label,
                    icon: t.icone,
                    variant: AppButtonVariant.secondary,
                    expanded: true,
                    onPressed: () async {
                      final String? vendaId = await controller.cobrar(
                        pedidoId: pedido.id,
                        tipo: t,
                      );
                      if (vendaId != null && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

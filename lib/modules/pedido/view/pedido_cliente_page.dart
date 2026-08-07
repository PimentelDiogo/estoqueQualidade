import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pedido.dart';
import '../viewmodel/pedido_cliente_viewmodel.dart';

/// Cardápio e pedido do cliente, aberto pelo QR da mesa.
///
/// **Sem login.** Praticamente sempre no celular de um visitante que nunca viu
/// este sistema — então zero explicação necessária: lista, toque, enviar.
class PedidoClientePage extends GetView<PedidoClienteViewModel> {
  const PedidoClientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espaco Cafe'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.carregando.value) {
            return const AppLoading(mensagem: 'Carregando cardapio...');
          }

          final falha = controller.falha.value;
          if (falha != null && controller.cardapio.isEmpty) {
            return EmptyState.erro(
              falha,
              onTentarDeNovo: controller.carregarCardapio,
            );
          }

          // Depois de enviar, a tela inteira vira o acompanhamento da senha.
          if (controller.enviado) return const _Acompanhamento();

          return const _Cardapio();
        }),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.enviado || controller.carrinhoVazio) {
          return const SizedBox.shrink();
        }
        return const _BarraCarrinho();
      }),
    );
  }
}

// =============================================================================
// Cardápio
// =============================================================================

class _Cardapio extends GetView<PedidoClienteViewModel> {
  const _Cardapio();

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: const ResponsiveValue<double>(
        mobile: double.infinity,
        tablet: 700,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Cardapio', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Toque para adicionar. O pedido vai direto para o caixa.',
            style: AppTypography.bodySmall,
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Obx(
              () => ListView.separated(
                itemCount: controller.cardapio.length,
                separatorBuilder: (BuildContext ctx, int i) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) =>
                    _LinhaCardapio(item: controller.cardapio[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaCardapio extends GetView<PedidoClienteViewModel> {
  const _LinhaCardapio({required this.item});

  final ItemCardapio item;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int qtd = controller.quantidadeNoCarrinho(item.id);

      return Opacity(
        opacity: item.disponivel ? 1 : 0.45,
        child: AppCard(
          selected: qtd > 0,
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: item.disponivel ? () => controller.adicionar(item) : null,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.nome, style: AppTypography.titleMedium),
                    if (item.descricao != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(item.descricao!, style: AppTypography.bodySmall),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    if (item.disponivel)
                      MoneyText(item.preco)
                    else
                      Text(
                        'Esgotado',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (qtd > 0) ...<Widget>[
                SizedBox(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => controller.remover(item.id),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$qtd',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge,
                  ),
                ),
              ],
              if (item.disponivel)
                SizedBox(
                  width: AppSpacing.touchTarget,
                  height: AppSpacing.touchTarget,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => controller.adicionar(item),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _BarraCarrinho extends GetView<PedidoClienteViewModel> {
  const _BarraCarrinho();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${controller.quantidadeTotal} item(ns)',
                  style: AppTypography.bodySmall,
                ),
                MoneyText(controller.total, large: true),
              ],
            ),
            const Spacer(),
            AppButton(
              label: 'Fazer pedido',
              icon: Icons.send,
              size: AppButtonSize.large,
              onPressed: () => _abrirConfirmacao(context),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirConfirmacao(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => Padding(
        // Sobe com o teclado: o sheet tem campo de texto e no celular o teclado
        // cobriria o botão de enviar.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _ConfirmarPedido(),
      ),
    );
  }
}

class _ConfirmarPedido extends GetView<PedidoClienteViewModel> {
  const _ConfirmarPedido();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Confirmar pedido', style: AppTypography.headlineMedium),
            AppSpacing.gapLg,

            Obx(
              () => Column(
                children: <Widget>[
                  for (final ItemPedidoCliente i in controller.carrinho)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${i.quantidade}x',
                              style: AppTypography.money,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              i.nome,
                              style: AppTypography.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          MoneyText(i.subtotal),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: AppSpacing.xl),
            Obx(
              () => MoneyLabelValue(
                label: 'Total',
                value: controller.total,
                emphasis: true,
              ),
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: 'Seu nome (opcional)',
              hint: 'Para chamarmos voce',
              onChanged: controller.definirNome,
            ),
            AppSpacing.gapMd,
            AppTextField(
              label: 'Observacao (opcional)',
              hint: 'Sem acucar, pouco leite...',
              maxLines: 2,
              onChanged: controller.definirObservacao,
            ),

            AppSpacing.gapLg,
            Obx(() {
              final falha = controller.falha.value;
              if (falha == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  falha.mensagem,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              );
            }),

            Obx(
              () => AppButton(
                label: 'Enviar pedido',
                icon: Icons.send,
                size: AppButtonSize.large,
                expanded: true,
                loading: controller.enviando.value,
                onPressed: () async {
                  final bool ok = await controller.enviarPedido();
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            AppSpacing.gapSm,
            Text(
              'O pagamento e feito no caixa.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Acompanhamento da senha
// =============================================================================

class _Acompanhamento extends GetView<PedidoClienteViewModel> {
  const _Acompanhamento();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final StatusPedido s = controller.status.value;
      final bool pronto = s == StatusPedido.pronto;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  pronto
                      ? Icons.check_circle_outline
                      : Icons.hourglass_top_outlined,
                  size: 64,
                  color: s.cor,
                ),
                AppSpacing.gapLg,
                Text('Sua senha', style: AppTypography.bodyLarge),
                Text(
                  controller.senha.value ?? '--',
                  style: AppTypography.tvSenha.copyWith(color: s.cor),
                ),
                AppSpacing.gapLg,

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: s.cor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.brPill,
                    border: Border.all(color: s.cor),
                  ),
                  child: Text(switch (s) {
                    StatusPedido.recebido => 'Pedido recebido',
                    StatusPedido.preparando => 'Preparando',
                    StatusPedido.pronto => 'Pronto! Retire no balcao',
                    StatusPedido.entregue => 'Entregue',
                    StatusPedido.cancelado => 'Cancelado',
                  }, style: AppTypography.titleLarge.copyWith(color: s.cor)),
                ),

                AppSpacing.gapXl,
                Text(
                  pronto
                      ? 'Vá ao caixa retirar e pagar seu pedido.'
                      : 'Acompanhe pela TV do salao ou por esta tela.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                AppSpacing.gapXxl,
                AppButton(
                  label: 'Fazer outro pedido',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: controller.novoPedido,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/venda.dart';
import '../../viewmodel/pdv_viewmodel.dart';
import 'comprovante_dialog.dart';
import 'pix_qr_dialog.dart';

/// Carrinho + escolha do meio de pagamento + finalizacao.
///
/// Mesmo widget nos dois layouts: painel lateral no tablet+, bottom sheet no
/// celular. So o [emSheet] muda (fecha a folha ao concluir).
class CarrinhoPanel extends GetView<PdvViewModel> {
  const CarrinhoPanel({super.key, this.emSheet = false});

  final bool emSheet;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Carrinho', style: AppTypography.titleLarge),
              Obx(
                () => controller.carrinhoVazio
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Limpar'),
                        onPressed: controller.limparCarrinho,
                      ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Flexible(
            child: Obx(() {
              if (controller.carrinhoVazio) {
                return const EmptyState(
                  titulo: 'Carrinho vazio',
                  descricao: 'Toque num produto para adicionar.',
                  icone: Icons.shopping_cart_outlined,
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: controller.carrinho.length,
                separatorBuilder: (BuildContext ctx, int index) =>
                    const Divider(height: AppSpacing.lg),
                itemBuilder: (BuildContext context, int i) =>
                    _LinhaCarrinho(item: controller.carrinho[i]),
              );
            }),
          ),
          const Divider(height: AppSpacing.xl),
          const _SeletorTipoVenda(),
          AppSpacing.gapLg,
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MoneyLabelValue(label: 'Subtotal', value: controller.subtotal),
                if (controller.desconto.value > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  MoneyLabelValue(
                    label: 'Desconto',
                    value: -controller.desconto.value,
                    valueColor: AppColors.warning,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                MoneyLabelValue(
                  label: 'Total',
                  value: controller.total,
                  emphasis: true,
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          const _AcoesFinalizacao(),
        ],
      ),
    );
  }
}

class _LinhaCarrinho extends GetView<PdvViewModel> {
  const _LinhaCarrinho({required this.item});

  final ItemCarrinho item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.produto.nome,
                style: AppTypography.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${item.quantidade} x R\$ '
                '${item.produto.precoVenda.toStringAsFixed(2)}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        // Alvos de 48dp: o voluntario ajusta quantidade com o cliente esperando.
        _BotaoQuantidade(
          icone: Icons.remove,
          onPressed: () => controller.remover(item.produto.id),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${item.quantidade}',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium,
          ),
        ),
        _BotaoQuantidade(
          icone: Icons.add,
          // Trava no estoque disponivel: melhor impedir aqui do que deixar a
          // RPC recusar a venda inteira na frente do cliente.
          onPressed: item.quantidade >= item.produto.quantidade
              ? null
              : () => controller.adicionar(item.produto),
        ),
        SizedBox(
          width: 88,
          child: MoneyText(item.subtotal, style: AppTypography.money),
        ),
      ],
    );
  }
}

class _BotaoQuantidade extends StatelessWidget {
  const _BotaoQuantidade({required this.icone, required this.onPressed});

  final IconData icone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: IconButton(
        icon: Icon(icone, size: 20),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          disabledBackgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),
    );
  }
}

class _SeletorTipoVenda extends GetView<PdvViewModel> {
  const _SeletorTipoVenda();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Tipo da venda', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        Obx(
          () => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final TipoVenda t in TipoVenda.values)
                ChoiceChip(
                  selected: controller.tipoVenda.value == t,
                  avatar: Icon(
                    t.icone,
                    size: 16,
                    color: controller.tipoVenda.value == t
                        ? AppColors.textOnAccent
                        : t.cor,
                  ),
                  label: Text(t.label),
                  // Pix sem QR cadastrado nao e opcao real.
                  onSelected: t == TipoVenda.pix && !controller.podeCobrarPix
                      ? null
                      : (_) => controller.definirTipo(t),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcoesFinalizacao extends GetView<PdvViewModel> {
  const _AcoesFinalizacao();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool pix = controller.tipoVenda.value == TipoVenda.pix;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (controller.falha.value case final falha?
              when !controller.carrinhoVazio)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                ),
                child: Text(
                  falha.mensagem,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),

          // Cobrar por Pix: mostra o QR do ministerio em tela cheia. A baixa do
          // pagamento NAO e automatica (ADR-005) — o caixa confere e confirma.
          if (pix && controller.podeCobrarPix) ...<Widget>[
            AppButton(
              label: 'Mostrar QR Pix',
              icon: Icons.qr_code_2,
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: controller.carrinhoVazio
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => PixQrDialog(
                        ministerio: controller.ministerio.value!,
                        valor: controller.total,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          AppButton(
            label: 'Finalizar venda',
            icon: Icons.check_circle_outline,
            size: AppButtonSize.large,
            expanded: true,
            loading: controller.registrando.value,
            onPressed: controller.carrinhoVazio
                ? null
                : () => _finalizar(context),
          ),
        ],
      );
    });
  }

  Future<void> _finalizar(BuildContext context) async {
    final bool ok = await controller.finalizarVenda();
    if (!ok || !context.mounted) return;

    final Venda? venda = controller.ultimaVenda.value;
    if (venda == null) return;

    // Fecha o bottom sheet do celular antes de abrir o comprovante.
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ComprovanteDialog(venda: venda),
    );
    controller.limparUltimaVenda();
  }
}

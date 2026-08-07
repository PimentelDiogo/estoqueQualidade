import 'dart:async';

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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/produto.dart';
import '../../../data/models/venda.dart';
import '../viewmodel/pdv_viewmodel.dart';
import 'widgets/carrinho_panel.dart';
import 'widgets/comprovante_dialog.dart';

/// Tela do caixa.
///
/// Mobile: catalogo em tela cheia + barra de total fixa que abre o carrinho.
/// Tablet+: catalogo a esquerda, carrinho sempre visivel a direita.
class PdvPage extends GetView<PdvViewModel> {
  const PdvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      rotaAtual: Rotas.pdv,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Caixa'),
          actions: <Widget>[
            const ContextoMinisterio(),
            AppSpacing.gapSm,
            IconButton(
              tooltip: 'Vendas do turno',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => _mostrarVendasDoDia(context),
            ),
            AppSpacing.gapSm,
          ],
        ),
        body: SafeArea(
          child: ResponsiveLayout(
            mobile: (_) => const _LayoutMobile(),
            tablet: (_) => const _LayoutLargo(),
          ),
        ),
      ),
    );
  }

  void _mostrarVendasDoDia(BuildContext context) {
    unawaited(controller.carregarVendasDoDia());
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => const _VendasDoDiaSheet(),
    );
  }
}

// =============================================================================
// Layouts
// =============================================================================

class _LayoutLargo extends GetView<PdvViewModel> {
  const _LayoutLargo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Expanded(flex: 3, child: _Catalogo()),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: context.isDesktop || context.isTv ? 400 : 320,
            child: const CarrinhoPanel(),
          ),
        ],
      ),
    );
  }
}

class _LayoutMobile extends GetView<PdvViewModel> {
  const _LayoutMobile();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: _Catalogo(),
          ),
        ),
        // Barra fixa: o total sempre visivel e um toque para o carrinho.
        Obx(() {
          if (controller.carrinhoVazio) return const SizedBox.shrink();

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                    label: 'Ver carrinho',
                    icon: Icons.shopping_cart_outlined,
                    size: AppButtonSize.large,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: AppColors.surface,
                      isScrollControlled: true,
                      builder: (_) => const FractionallySizedBox(
                        heightFactor: 0.9,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CarrinhoPanel(emSheet: true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// =============================================================================
// Catalogo
// =============================================================================

class _Catalogo extends GetView<PdvViewModel> {
  const _Catalogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                label: 'Buscar produto',
                hint: 'Nome ou codigo de barras',
                prefixIcon: Icons.search,
                onChanged: controller.aoBuscar,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              // Alinha com o campo, que tem o label acima.
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: IconButton.filledTonal(
                tooltip: 'Ler codigo de barras',
                icon: const Icon(Icons.qr_code_scanner),
                iconSize: 26,
                onPressed: () => _abrirScanner(context),
              ),
            ),
          ],
        ),
        AppSpacing.gapLg,
        Expanded(
          child: Obx(() {
            if (controller.carregando.value && controller.produtos.isEmpty) {
              return const AppLoading(mensagem: 'Carregando produtos...');
            }

            final AppFailureView? erro = _erroSeHouver(controller);
            if (erro != null) return erro.widget;

            final List<Produto> lista = controller.produtosFiltrados;
            if (lista.isEmpty) {
              return EmptyState(
                titulo: controller.busca.value.isEmpty
                    ? 'Nenhum produto cadastrado'
                    : 'Nada encontrado',
                descricao: controller.busca.value.isEmpty
                    ? 'Cadastre os produtos na tela de Estoque.'
                    : 'Tente outro termo de busca.',
                icone: Icons.coffee_outlined,
              );
            }

            return ResponsiveGrid(
              columns: const ResponsiveValue<int>(
                mobile: 2,
                tablet: 2,
                desktop: 3,
                tv: 4,
              ),
              childAspectRatio: const ResponsiveValue<double>(
                mobile: 0.95,
                tablet: 1.05,
              ),
              children: <Widget>[
                for (final Produto p in lista) _CardProduto(produto: p),
              ],
            );
          }),
        ),
      ],
    );
  }

  Future<void> _abrirScanner(BuildContext context) async {
    final String? codigo = await Get.toNamed<String?>(Rotas.scanner);
    if (codigo == null || codigo.isEmpty) return;

    final bool achou = await controller.adicionarPorCodigoBarras(codigo);
    if (!achou && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Codigo $codigo nao esta cadastrado.'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    }
  }
}

class _CardProduto extends GetView<PdvViewModel> {
  const _CardProduto({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int noCarrinho = controller.quantidadeNoCarrinho(produto.id);
      final bool esgotado = !produto.disponivel;

      return Opacity(
        opacity: esgotado ? 0.45 : 1,
        child: AppCard(
          selected: noCarrinho > 0,
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: esgotado ? null : () => controller.adicionar(produto),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: AppBadge.estoque(
                      quantidade: produto.quantidade,
                      minimo: produto.estoqueMinimo,
                    ),
                  ),
                  if (noCarrinho > 0)
                    CountBadge(count: noCarrinho, color: AppColors.brandRose),
                ],
              ),
              const Spacer(),
              Text(
                produto.nome,
                style: AppTypography.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${produto.quantidade} ${produto.unidade} em estoque',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  MoneyText(produto.precoVenda),
                  if (noCarrinho > 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      color: AppColors.textSecondary,
                      onPressed: () => controller.remover(produto.id),
                      tooltip: 'Remover uma unidade',
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

// =============================================================================
// Vendas do turno
// =============================================================================

class _VendasDoDiaSheet extends GetView<PdvViewModel> {
  const _VendasDoDiaSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Obx(() {
          final List<Venda> vendas = controller.vendasDoDia;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Vendas de hoje', style: AppTypography.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${vendas.length} venda(s) registrada(s)',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapLg,
              MoneyLabelValue(
                label: 'Total do turno',
                value: controller.totalDoDia,
                emphasis: true,
                valueColor: AppColors.success,
              ),
              AppSpacing.gapLg,
              if (vendas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: EmptyState(
                    titulo: 'Nenhuma venda ainda',
                    descricao: 'As vendas do turno aparecem aqui.',
                    icone: Icons.receipt_long_outlined,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vendas.length,
                    separatorBuilder: (BuildContext ctx, int index) =>
                        const Divider(),
                    itemBuilder: (BuildContext context, int i) {
                      final Venda v = vendas[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(v.tipo.icone, color: v.tipo.cor),
                        title: Text('${v.quantidadeItens} item(ns)'),
                        subtitle: Text(
                          '${v.tipo.label} - ${Datas.hora(v.criadoEm)}',
                        ),
                        trailing: MoneyText(v.valorTotal),
                        onTap: () {
                          Navigator.of(context).pop();
                          showDialog<void>(
                            context: context,
                            builder: (_) => ComprovanteDialog(venda: v),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Wrapper minimo para reaproveitar [EmptyState.erro] dentro de um Obx.
class AppFailureView {
  const AppFailureView(this.widget);
  final Widget widget;
}

AppFailureView? _erroSeHouver(PdvViewModel c) {
  final falha = c.falha.value;
  if (falha == null || c.produtos.isNotEmpty) return null;
  return AppFailureView(EmptyState.erro(falha, onTentarDeNovo: c.carregar));
}

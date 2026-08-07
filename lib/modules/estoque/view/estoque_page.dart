import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/produto.dart';
import '../viewmodel/estoque_viewmodel.dart';
import 'widgets/movimentacao_dialog.dart';
import 'widgets/produto_form_dialog.dart';

class EstoquePage extends GetView<EstoqueViewModel> {
  const EstoquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppShell(
        rotaAtual: Rotas.estoque,
        alertasAbertos: controller.totalAlertas,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Estoque'),
            actions: const <Widget>[ContextoMinisterio(), AppSpacing.gapSm],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Novo produto'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const ProdutoFormDialog(),
            ),
          ),
          body: SafeArea(
            child: ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Resumo(),
                  AppSpacing.gapLg,
                  AppTextField(
                    label: 'Buscar',
                    hint: 'Nome ou codigo de barras',
                    prefixIcon: Icons.search,
                    onChanged: controller.aoBuscar,
                  ),
                  AppSpacing.gapMd,
                  const _Filtros(),
                  AppSpacing.gapLg,
                  const Expanded(child: _ListaProdutos()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Resumo extends GetView<EstoqueViewModel> {
  const _Resumo();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ResponsiveRow(
        spacing: AppSpacing.md,
        // Empilhar 3 cards no celular gastaria a tela toda antes da lista.
        // Aqui eles ficam lado a lado em qualquer largura, so menores.
        stackBelow: Breakpoint.mobile,
        children: <Widget>[
          _CardResumo(
            titulo: 'Produtos',
            valor: '${controller.produtos.length}',
            icone: Icons.inventory_2_outlined,
            cor: AppColors.info,
          ),
          _CardResumo(
            titulo: 'Acabando',
            valor: '${controller.totalAlertas}',
            icone: Icons.warning_amber_rounded,
            cor: AppColors.warning,
          ),
          _CardResumo(
            titulo: 'Esgotados',
            valor: '${controller.totalEsgotados}',
            icone: Icons.remove_shopping_cart_outlined,
            cor: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  const _CardResumo({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, color: cor, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(valor, style: AppTypography.headlineMedium),
          Text(titulo, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _Filtros extends GetView<EstoqueViewModel> {
  const _Filtros();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSpacing.sm,
        children: <Widget>[
          for (final FiltroEstoque f in FiltroEstoque.values)
            ChoiceChip(
              label: Text(f.label),
              selected: controller.filtro.value == f,
              onSelected: (_) => controller.definirFiltro(f),
            ),
        ],
      ),
    );
  }
}

class _ListaProdutos extends GetView<EstoqueViewModel> {
  const _ListaProdutos();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.carregando.value && controller.produtos.isEmpty) {
        return const AppLoading(mensagem: 'Carregando estoque...');
      }

      final falha = controller.falha.value;
      if (falha != null && controller.produtos.isEmpty) {
        return EmptyState.erro(falha, onTentarDeNovo: controller.carregar);
      }

      final List<Produto> lista = controller.produtosFiltrados;
      if (lista.isEmpty) {
        return const EmptyState(
          titulo: 'Nenhum produto',
          descricao: 'Cadastre o primeiro produto no botao abaixo.',
          icone: Icons.inventory_2_outlined,
        );
      }

      return RefreshIndicator(
        onRefresh: controller.carregar,
        child: ListView.separated(
          itemCount: lista.length,
          separatorBuilder: (BuildContext ctx, int i) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int i) =>
              _LinhaProduto(produto: lista[i]),
        ),
      );
    });
  }
}

class _LinhaProduto extends GetView<EstoqueViewModel> {
  const _LinhaProduto({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => ProdutoFormDialog(produto: produto),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        produto.nome,
                        style: AppTypography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge.estoque(
                      quantidade: produto.quantidade,
                      minimo: produto.estoqueMinimo,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${produto.quantidade} ${produto.unidade} '
                  '(minimo ${produto.estoqueMinimo})',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          MoneyText(produto.precoVenda),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Movimentar estoque',
            icon: const Icon(Icons.swap_vert),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MovimentacaoDialog(produto: produto),
            ),
          ),
        ],
      ),
    );
  }
}

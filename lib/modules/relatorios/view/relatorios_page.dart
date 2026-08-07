import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/csv_download.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/venda.dart';
import '../viewmodel/relatorios_viewmodel.dart';

class RelatoriosPage extends GetView<RelatoriosViewModel> {
  const RelatoriosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      rotaAtual: Rotas.relatorios,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatorios'),
          actions: <Widget>[
            const ContextoMinisterio(),
            AppSpacing.gapSm,
            IconButton(
              tooltip: 'Baixar CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => baixarCsv(
                conteudo: controller.gerarCsv(),
                nomeArquivo: controller.nomeArquivoCsv,
              ),
            ),
            AppSpacing.gapSm,
          ],
        ),
        body: SafeArea(
          child: ResponsiveBody(
            scrollable: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _SeletorPeriodo(),
                AppSpacing.gapLg,
                const _Cards(),
                AppSpacing.gapLg,
                ResponsiveRow(
                  flex: const <int>[3, 2],
                  children: const <Widget>[_GraficoBarras(), _GraficoPizza()],
                ),
                AppSpacing.gapLg,
                const _MaisVendidos(),
                AppSpacing.gapXl,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeletorPeriodo extends GetView<RelatoriosViewModel> {
  const _SeletorPeriodo();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        children: <Widget>[
          SegmentedButton<Periodo>(
            segments: const <ButtonSegment<Periodo>>[
              ButtonSegment<Periodo>(value: Periodo.dia, label: Text('Dia')),
              ButtonSegment<Periodo>(
                value: Periodo.semana,
                label: Text('Semana'),
              ),
              ButtonSegment<Periodo>(value: Periodo.mes, label: Text('Mes')),
            ],
            selected: <Periodo>{controller.periodo.value},
            onSelectionChanged: (Set<Periodo> s) =>
                controller.definirPeriodo(s.first),
          ),
          AppSpacing.gapMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'Periodo anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.deslocar(-1),
              ),
              Expanded(
                child: Text(
                  controller.rotulo,
                  style: AppTypography.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Proximo periodo',
                icon: const Icon(Icons.chevron_right),
                // Nao deixa navegar para o futuro: relatorio de amanha nao
                // existe e so confundiria.
                onPressed: controller.noPeriodoAtual
                    ? null
                    : () => controller.deslocar(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cards extends GetView<RelatoriosViewModel> {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ResumoPeriodo r = controller.resumo.value;

      return ResponsiveGrid(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        columns: const ResponsiveValue<int>(mobile: 2, tablet: 4),
        childAspectRatio: const ResponsiveValue<double>(
          mobile: 1.5,
          tablet: 1.4,
        ),
        children: <Widget>[
          _CardMetrica(
            titulo: 'Arrecadado',
            valor: controller.totalArrecadado,
            icone: Icons.payments_outlined,
            cor: AppColors.success,
            destaque: true,
          ),
          _CardMetrica(
            titulo: 'Vendas',
            texto: '${r.qtdVendas}',
            icone: Icons.receipt_long_outlined,
            cor: AppColors.info,
          ),
          _CardMetrica(
            titulo: 'Ticket medio',
            valor: r.ticketMedio,
            icone: Icons.trending_up,
            cor: AppColors.brandRose,
          ),
          _CardMetrica(
            titulo: 'Itens vendidos',
            texto: '${r.qtdItens}',
            icone: Icons.coffee_outlined,
            cor: AppColors.brandCoffee,
          ),
        ],
      );
    });
  }
}

class _CardMetrica extends StatelessWidget {
  const _CardMetrica({
    required this.titulo,
    required this.icone,
    required this.cor,
    this.valor,
    this.texto,
    this.destaque = false,
  });

  final String titulo;
  final double? valor;
  final String? texto;
  final IconData icone;
  final Color cor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: destaque ? cor.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(icone, color: cor, size: 20),
          if (texto != null)
            Text(
              texto!,
              style: AppTypography.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(valor ?? 0, large: true, color: cor),
            ),
          Text(titulo, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _GraficoBarras extends GetView<RelatoriosViewModel> {
  const _GraficoBarras();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Vendas por dia', style: AppTypography.titleMedium),
          AppSpacing.gapLg,
          SizedBox(
            height: 220,
            child: Obx(() {
              final List<({DateTime dia, double valor})> dados =
                  controller.serieDiaria;

              if (dados.every(
                (({DateTime dia, double valor}) d) => d.valor == 0,
              )) {
                return const EmptyState(
                  titulo: 'Sem vendas no periodo',
                  icone: Icons.bar_chart_outlined,
                );
              }

              final double maxY = dados
                  .map((({DateTime dia, double valor}) d) => d.valor)
                  .reduce((double a, double b) => a > b ? a : b);

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  // 20% de folga no topo para o rotulo nao encostar na borda.
                  maxY: maxY * 1.2,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (double v) =>
                        const FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int i = value.toInt();
                          if (i < 0 || i >= dados.length) {
                            return const SizedBox.shrink();
                          }
                          // Num mes com 31 dias nao cabe um rotulo por barra:
                          // mostra um a cada 5.
                          final int passo = dados.length > 14 ? 5 : 1;
                          if (i % passo != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              Datas.diaCurto(dados[i].dia),
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: <BarChartGroupData>[
                    for (int i = 0; i < dados.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: dados[i].valor,
                            color: AppColors.brandRose,
                            width: dados.length > 14 ? 8 : 16,
                            borderRadius: AppRadius.brSm,
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _GraficoPizza extends GetView<RelatoriosViewModel> {
  const _GraficoPizza();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Por tipo de venda', style: AppTypography.titleMedium),
          AppSpacing.gapLg,
          Obx(() {
            final Map<TipoVenda, double> mapa = controller.porTipo;
            final double total = mapa.values.fold(
              0,
              (double a, double b) => a + b,
            );

            if (total <= 0) {
              return const SizedBox(
                height: 180,
                child: EmptyState(
                  titulo: 'Sem vendas',
                  icone: Icons.pie_chart_outline,
                ),
              );
            }

            return Column(
              children: <Widget>[
                SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: <PieChartSectionData>[
                        for (final MapEntry<TipoVenda, double> e
                            in mapa.entries)
                          PieChartSectionData(
                            value: e.value,
                            // A cor de cada tipo e a mesma do PDV e do
                            // comprovante — o mesmo significado, a mesma cor.
                            color: e.key.cor,
                            radius: 42,
                            title:
                                '${(e.value / total * 100).toStringAsFixed(0)}%',
                            titleStyle: AppTypography.bodySmall.copyWith(
                              color: AppColors.brandBlack,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapLg,
                for (final MapEntry<TipoVenda, double> e in mapa.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: e.key.cor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            e.key.label,
                            style: AppTypography.bodySmall,
                          ),
                        ),
                        MoneyText(e.value, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                if (controller.totalCortesias > 0) ...<Widget>[
                  AppSpacing.gapSm,
                  Text(
                    'Cortesias baixam estoque mas nao contam como arrecadacao.',
                    style: AppTypography.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MaisVendidos extends GetView<RelatoriosViewModel> {
  const _MaisVendidos();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mais vendidos', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Use para planejar a reposicao do proximo culto.',
            style: AppTypography.bodySmall,
          ),
          AppSpacing.gapLg,
          Obx(() {
            if (controller.maisVendidos.isEmpty) {
              return Text(
                'Sem dados no periodo.',
                style: AppTypography.bodySmall,
              );
            }

            return Column(
              children: <Widget>[
                for (final ProdutoMaisVendido p in controller.maisVendidos)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.surfaceElevated,
                      child: Text(
                        '${p.qtdVendida}',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                    title: Text(p.produtoNome, style: AppTypography.bodyMedium),
                    trailing: MoneyText(p.valorTotal),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

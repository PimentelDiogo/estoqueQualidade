import 'package:get/get.dart';

import '../../../core/utils/date_range.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/result.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/venda.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';

class RelatoriosViewModel extends GetxController {
  RelatoriosViewModel({
    required RelatorioRepository relatorioRepo,
    required ContextoOperacional session,
  }) : _relatorioRepo = relatorioRepo,
       _session = session;

  final RelatorioRepository _relatorioRepo;
  final ContextoOperacional _session;

  final Rx<Periodo> periodo = Periodo.dia.obs;
  final Rx<DateTime> referencia = DateTime.now().obs;

  final Rx<ResumoPeriodo> resumo = const ResumoPeriodo().obs;
  final RxList<VendaAgregada> serie = <VendaAgregada>[].obs;
  final RxList<ProdutoMaisVendido> maisVendidos = <ProdutoMaisVendido>[].obs;

  final RxBool carregando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  String? get _ministerioId => _session.ministerioAtivoId.value;

  DateRange get intervalo =>
      DateRange.doPeriodo(periodo.value, referencia: referencia.value);

  String get rotulo => intervalo.rotulo(periodo.value);

  /// Serie do grafico de barras: um valor por dia dentro do intervalo.
  ///
  /// Preenche os dias sem venda com zero — sem isso, o grafico "pula" datas e
  /// da a impressao de que o cafe vendeu todo dia.
  List<({DateTime dia, double valor})> get serieDiaria {
    final Map<DateTime, double> porDia = <DateTime, double>{};
    for (final VendaAgregada a in serie) {
      final DateTime d = DateTime(
        a.periodo.year,
        a.periodo.month,
        a.periodo.day,
      );
      porDia[d] = (porDia[d] ?? 0) + a.valorTotal;
    }

    final List<({DateTime dia, double valor})> saida =
        <({DateTime dia, double valor})>[];
    DateTime cursor = intervalo.inicio;
    while (cursor.isBefore(intervalo.fim)) {
      saida.add((dia: cursor, valor: porDia[cursor] ?? 0));
      cursor = cursor.add(const Duration(days: 1));
    }
    return saida;
  }

  /// Total por tipo de venda — alimenta o grafico de pizza.
  Map<TipoVenda, double> get porTipo {
    final Map<TipoVenda, double> mapa = <TipoVenda, double>{};
    for (final VendaAgregada a in serie) {
      mapa[a.tipo] = (mapa[a.tipo] ?? 0) + a.valorTotal;
    }
    return mapa;
  }

  /// Arrecadacao real: cortesia baixa estoque mas nao entra como receita.
  double get totalArrecadado => porTipo.entries
      .where((MapEntry<TipoVenda, double> e) => e.key.contabilizaReceita)
      .fold(0, (double s, MapEntry<TipoVenda, double> e) => s + e.value);

  double get totalCortesias => porTipo[TipoVenda.cortesia] ?? 0;

  @override
  void onInit() {
    super.onInit();
    carregar();
  }

  Future<void> carregar() async {
    final String? id = _ministerioId;
    if (id == null) return;

    carregando.value = true;
    falha.value = null;

    final DateRange r = intervalo;

    final List<dynamic> resultados = await Future.wait(<Future<dynamic>>[
      _relatorioRepo.resumo(ministerioId: id, periodo: r),
      _relatorioRepo.serie(
        ministerioId: id,
        // A serie e sempre por dia: mesmo no relatorio mensal, o grafico util
        // e "quanto vendeu em cada dia do mes".
        granularidade: Periodo.dia,
        periodo: r,
      ),
      _relatorioRepo.maisVendidos(ministerioId: id, periodo: r),
    ]);

    (resultados[0] as Result<ResumoPeriodo>).fold(
      onOk: (ResumoPeriodo v) => resumo.value = v,
      onFailure: (AppFailure f) => falha.value = f,
    );
    (resultados[1] as Result<List<VendaAgregada>>).fold(
      onOk: serie.assignAll,
      onFailure: (AppFailure f) => falha.value = f,
    );
    (resultados[2] as Result<List<ProdutoMaisVendido>>).fold(
      onOk: maisVendidos.assignAll,
      onFailure: (_) {},
    );

    carregando.value = false;
  }

  void definirPeriodo(Periodo p) {
    periodo.value = p;
    referencia.value = DateTime.now();
    carregar();
  }

  /// Navega para o periodo anterior/seguinte mantendo a granularidade.
  void deslocar(int passos) {
    final DateTime base = referencia.value;
    referencia.value = switch (periodo.value) {
      Periodo.dia => base.add(Duration(days: passos)),
      Periodo.semana => base.add(Duration(days: 7 * passos)),
      Periodo.mes => DateTime(base.year, base.month + passos, 1),
    };
    carregar();
  }

  /// `true` quando ja estamos no periodo atual — desabilita o "proximo".
  bool get noPeriodoAtual => intervalo.contem(DateTime.now());

  /// CSV do periodo, para o tesoureiro abrir no Excel.
  ///
  /// Separador `;` e decimal com virgula: e o que o Excel em pt_BR entende sem
  /// pedir importacao manual.
  String gerarCsv() {
    final StringBuffer b = StringBuffer()
      ..writeln('sep=;')
      ..writeln('Data;Tipo;Vendas;Itens;Valor total');

    for (final VendaAgregada a in serie) {
      b.writeln(
        <String>[
          Datas.data(a.periodo),
          a.tipo.label,
          '${a.qtdVendas}',
          '${a.qtdItens}',
          Money.plain(a.valorTotal),
        ].join(';'),
      );
    }

    b
      ..writeln()
      ..writeln('Resumo do periodo;$rotulo')
      ..writeln('Total de vendas;${resumo.value.qtdVendas}')
      ..writeln('Itens vendidos;${resumo.value.qtdItens}')
      ..writeln('Arrecadado;${Money.plain(totalArrecadado)}')
      ..writeln('Cortesias;${Money.plain(totalCortesias)}')
      ..writeln('Ticket medio;${Money.plain(resumo.value.ticketMedio)}')
      ..writeln('Descontos;${Money.plain(resumo.value.descontos)}');

    return b.toString();
  }

  String get nomeArquivoCsv {
    final DateTime i = intervalo.inicio;
    final String data =
        '${i.year}-${i.month.toString().padLeft(2, '0')}'
        '-${i.day.toString().padLeft(2, '0')}';
    return 'espaco-cafe-${periodo.value.name}-$data.csv';
  }
}

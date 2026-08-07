import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/estoque.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';

/// Filtro da lista de produtos.
enum FiltroEstoque {
  todos('Todos'),
  acabando('Acabando'),
  esgotados('Esgotados');

  const FiltroEstoque(this.label);

  final String label;
}

class EstoqueViewModel extends GetxController {
  EstoqueViewModel({
    required ProdutoRepository produtoRepo,
    required AlertaRepository alertaRepo,
    required ContextoOperacional session,
  }) : _produtoRepo = produtoRepo,
       _alertaRepo = alertaRepo,
       _session = session;

  final ProdutoRepository _produtoRepo;
  final AlertaRepository _alertaRepo;
  final ContextoOperacional _session;

  final RxList<Produto> produtos = <Produto>[].obs;
  final RxList<AlertaEstoque> alertas = <AlertaEstoque>[].obs;
  final RxList<MovimentacaoEstoque> historico = <MovimentacaoEstoque>[].obs;

  final RxString busca = ''.obs;
  final Rx<FiltroEstoque> filtro = FiltroEstoque.todos.obs;

  final RxBool carregando = false.obs;
  final RxBool salvando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  String? get _ministerioId => _session.ministerioAtivoId.value;

  /// Contador do badge no menu.
  int get totalAlertas => alertas.length;

  int get totalEsgotados =>
      alertas.where((AlertaEstoque a) => a.esgotado).length;

  /// Valor imobilizado no estoque, a custo — pergunta recorrente do tesoureiro.
  double get valorTotalEmEstoque =>
      produtos.fold(0, (double s, Produto p) => s + p.valorEmEstoque);

  List<Produto> get produtosFiltrados {
    return produtos.where((Produto p) {
      if (!p.combina(busca.value)) return false;
      return switch (filtro.value) {
        FiltroEstoque.todos => true,
        FiltroEstoque.acabando => p.precisaRepor,
        FiltroEstoque.esgotados => p.quantidade <= 0,
      };
    }).toList();
  }

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

    final Result<List<Produto>> rProdutos = await _produtoRepo.listar(
      ministerioId: id,
    );
    rProdutos.fold(
      onOk: produtos.assignAll,
      onFailure: (AppFailure f) => falha.value = f,
    );

    await carregarAlertas();
    carregando.value = false;
  }

  Future<void> carregarAlertas() async {
    final String? id = _ministerioId;
    if (id == null) return;

    final Result<List<AlertaEstoque>> r = await _alertaRepo.listar(id);
    r.fold(onOk: alertas.assignAll, onFailure: (_) {});
  }

  void aoBuscar(String termo) => busca.value = termo;
  void definirFiltro(FiltroEstoque f) => filtro.value = f;

  // --- CRUD ------------------------------------------------------------------

  Future<bool> salvarProduto(Produto produto, {required bool novo}) async {
    if (salvando.value) return false;

    salvando.value = true;
    falha.value = null;

    final Result<Produto> r = novo
        ? await _produtoRepo.criar(produto)
        : await _produtoRepo.atualizar(produto);

    salvando.value = false;

    return r.fold(
      onOk: (Produto p) {
        // Recarrega em vez de mexer na lista local: criar/editar produto pode
        // ter disparado o trigger de alerta, e o badge precisa refletir isso.
        carregar();
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  Future<bool> desativarProduto(String produtoId) async {
    final Result<void> r = await _produtoRepo.desativar(produtoId);
    return r.fold(
      onOk: (_) {
        produtos.removeWhere((Produto p) => p.id == produtoId);
        carregarAlertas();
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  // --- Movimentacao ----------------------------------------------------------

  /// Entrada, ajuste ou perda. Saida por venda so pela RPC do caixa.
  Future<bool> movimentar({
    required String produtoId,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  }) async {
    if (salvando.value) return false;

    salvando.value = true;
    falha.value = null;

    final Result<int> r = await _produtoRepo.movimentarEstoque(
      produtoId: produtoId,
      tipo: tipo,
      quantidade: quantidade,
      observacao: observacao,
    );

    salvando.value = false;

    return r.fold(
      onOk: (int novoSaldo) {
        // Atualiza a linha na hora (feedback imediato) e recarrega os alertas,
        // porque o trigger pode ter aberto ou fechado um.
        final int i = produtos.indexWhere((Produto p) => p.id == produtoId);
        if (i >= 0) {
          produtos[i] = produtos[i].copyWith(quantidade: novoSaldo);
        }
        carregarAlertas();
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  Future<void> carregarHistorico(String produtoId) async {
    final Result<List<MovimentacaoEstoque>> r = await _produtoRepo
        .historicoMovimentacoes(produtoId: produtoId);
    r.fold(onOk: historico.assignAll, onFailure: (_) => historico.clear());
  }

  Future<bool> resolverAlerta(String alertaId) async {
    final Result<void> r = await _alertaRepo.resolver(alertaId);
    return r.fold(
      onOk: (_) {
        carregarAlertas();
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  void limparFalha() => falha.value = null;
}

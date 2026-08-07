import 'package:get/get.dart';

import '../../../core/utils/date_range.dart';
import '../../../core/utils/result.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/ministerio.dart';
import '../../../data/models/produto.dart';
import '../../../data/models/venda.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';

/// ViewModel do caixa.
///
/// Depende so de interfaces de Repository — testavel sem rede.
class PdvViewModel extends GetxController {
  PdvViewModel({
    required ProdutoRepository produtoRepo,
    required VendaRepository vendaRepo,
    required MinisterioRepository ministerioRepo,
    required ContextoOperacional session,
  }) : _produtoRepo = produtoRepo,
       _vendaRepo = vendaRepo,
       _ministerioRepo = ministerioRepo,
       _session = session;

  final ProdutoRepository _produtoRepo;
  final VendaRepository _vendaRepo;
  final MinisterioRepository _ministerioRepo;
  final ContextoOperacional _session;

  // --- Catalogo --------------------------------------------------------------
  final RxList<Produto> produtos = <Produto>[].obs;
  final RxString busca = ''.obs;
  final RxBool carregando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  // --- Carrinho --------------------------------------------------------------
  final RxList<ItemCarrinho> carrinho = <ItemCarrinho>[].obs;
  final Rx<TipoVenda> tipoVenda = TipoVenda.pix.obs;
  final RxDouble desconto = 0.0.obs;

  // --- Finalizacao -----------------------------------------------------------
  final RxBool registrando = false.obs;
  final Rxn<Venda> ultimaVenda = Rxn<Venda>();
  final Rxn<Ministerio> ministerio = Rxn<Ministerio>();

  /// Vendas ja registradas no turno — o caixa confere no fim do culto.
  final RxList<Venda> vendasDoDia = <Venda>[].obs;

  String? get _ministerioId => _session.ministerioAtivoId.value;

  List<Produto> get produtosFiltrados =>
      produtos.where((Produto p) => p.combina(busca.value)).toList();

  double get subtotal =>
      carrinho.fold(0, (double s, ItemCarrinho i) => s + i.subtotal);

  double get total => (subtotal - desconto.value).clamp(0, double.infinity);

  int get quantidadeTotal =>
      carrinho.fold(0, (int s, ItemCarrinho i) => s + i.quantidade);

  bool get carrinhoVazio => carrinho.isEmpty;

  /// Pix so aparece como opcao se o ministerio tiver QR cadastrado.
  bool get podeCobrarPix => ministerio.value?.temPix ?? false;

  /// Total do turno — o numero que o tesoureiro pede no fim.
  double get totalDoDia => vendasDoDia
      .where((Venda v) => v.tipo.contabilizaReceita)
      .fold(0, (double s, Venda v) => s + v.valorTotal);

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

    final Result<List<Produto>> r = await _produtoRepo.listar(ministerioId: id);

    r.fold(
      onOk: produtos.assignAll,
      onFailure: (AppFailure f) => falha.value = f,
    );

    await Future.wait(<Future<void>>[
      _carregarMinisterio(id),
      carregarVendasDoDia(),
    ]);

    carregando.value = false;
  }

  Future<void> _carregarMinisterio(String id) async {
    final Result<Ministerio> r = await _ministerioRepo.porId(id);
    r.fold(
      onOk: (Ministerio m) {
        ministerio.value = m;
        // Sem QR cadastrado, Pix nao e uma opcao real — o padrao vira dinheiro
        // para o caixa nao selecionar um meio que nao consegue cobrar.
        if (!m.temPix && tipoVenda.value == TipoVenda.pix) {
          tipoVenda.value = TipoVenda.dinheiro;
        }
      },
      onFailure: (_) {},
    );
  }

  Future<void> carregarVendasDoDia() async {
    final String? id = _ministerioId;
    if (id == null) return;

    final Result<List<Venda>> r = await _vendaRepo.listar(
      ministerioId: id,
      periodo: DateRange.doPeriodo(Periodo.dia),
    );
    r.fold(onOk: vendasDoDia.assignAll, onFailure: (_) {});
  }

  // --- Carrinho --------------------------------------------------------------

  /// Adiciona (ou incrementa) um produto.
  ///
  /// A checagem de estoque aqui e otimista, so para feedback imediato. A
  /// validacao que vale acontece dentro da transacao da RPC.
  void adicionar(Produto produto) {
    if (!produto.disponivel) return;

    final int i = carrinho.indexWhere(
      (ItemCarrinho c) => c.produto.id == produto.id,
    );

    if (i < 0) {
      carrinho.add(ItemCarrinho(produto: produto, quantidade: 1));
      return;
    }

    final ItemCarrinho atual = carrinho[i];
    if (atual.quantidade >= produto.quantidade) return; // acabou o estoque
    carrinho[i] = atual.comQuantidade(atual.quantidade + 1);
  }

  void remover(String produtoId) {
    final int i = carrinho.indexWhere(
      (ItemCarrinho c) => c.produto.id == produtoId,
    );
    if (i < 0) return;

    final ItemCarrinho atual = carrinho[i];
    if (atual.quantidade <= 1) {
      carrinho.removeAt(i);
    } else {
      carrinho[i] = atual.comQuantidade(atual.quantidade - 1);
    }
  }

  void removerItem(String produtoId) =>
      carrinho.removeWhere((ItemCarrinho c) => c.produto.id == produtoId);

  int quantidadeNoCarrinho(String produtoId) => carrinho
      .where((ItemCarrinho c) => c.produto.id == produtoId)
      .fold(0, (int s, ItemCarrinho c) => s + c.quantidade);

  void limparCarrinho() {
    carrinho.clear();
    desconto.value = 0;
  }

  void definirTipo(TipoVenda tipo) => tipoVenda.value = tipo;

  void definirDesconto(double valor) =>
      desconto.value = valor.clamp(0, subtotal);

  void aoBuscar(String termo) => busca.value = termo;

  /// Chamado pelo scanner de codigo de barras.
  /// Retorna `false` quando o codigo nao esta cadastrado — a tela avisa.
  Future<bool> adicionarPorCodigoBarras(String codigo) async {
    final String? id = _ministerioId;
    if (id == null) return false;

    // Tenta na lista ja carregada antes de ir a rede: no caixa, cada ida ao
    // servidor e um segundo parado na frente do cliente.
    final Produto? local = produtos
        .where((Produto p) => p.codigoBarras == codigo.trim())
        .firstOrNull;

    if (local != null) {
      adicionar(local);
      return true;
    }

    final Result<Produto?> r = await _produtoRepo.porCodigoBarras(
      ministerioId: id,
      codigo: codigo,
    );

    return r.fold(
      onOk: (Produto? p) {
        if (p == null) return false;
        adicionar(p);
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  // --- Finalizacao -----------------------------------------------------------

  /// Registra a venda pela RPC transacional.
  ///
  /// Retorna `true` em sucesso. O guard de [registrando] impede a venda dupla
  /// por duplo toque — situacao real com caixa apressado.
  Future<bool> finalizarVenda({String? observacao}) async {
    if (registrando.value || carrinhoVazio) return false;

    final String? id = _ministerioId;
    if (id == null) {
      falha.value = const AppFailure.negocio(
        'Nenhum ministerio selecionado. Escolha antes de vender.',
      );
      return false;
    }

    registrando.value = true;
    falha.value = null;

    final Result<String> r = await _vendaRepo.registrar(
      ministerioId: id,
      tipo: tipoVenda.value,
      itens: carrinho.toList(),
      desconto: desconto.value,
      observacao: observacao,
    );

    final bool ok = await r.fold(
      onOk: (String vendaId) async {
        final Result<Venda> detalhe = await _vendaRepo.porId(vendaId);
        detalhe.fold(
          onOk: (Venda v) => ultimaVenda.value = v,
          onFailure: (_) {},
        );

        limparCarrinho();
        // Recarrega o catalogo: as quantidades mudaram e o proximo cliente
        // ja chega. Sem isso o caixa venderia sobre um estoque desatualizado.
        await carregar();
        return true;
      },
      onFailure: (AppFailure f) async {
        // Estoque insuficiente costuma significar que o dado local envelheceu
        // (outro caixa vendeu). Recarregar mostra a verdade na hora.
        //
        // A ordem importa: `carregar()` zera `falha` no inicio, entao atribuir
        // antes faria a mensagem sumir da tela sem o voluntario ler.
        if (f.kind == FailureKind.negocio) await carregar();
        falha.value = f;
        return false;
      },
    );

    registrando.value = false;
    return ok;
  }

  void limparUltimaVenda() => ultimaVenda.value = null;
  void limparFalha() => falha.value = null;
}

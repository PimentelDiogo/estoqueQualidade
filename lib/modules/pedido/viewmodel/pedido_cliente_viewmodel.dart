import 'dart:async';

import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/repositories.dart';

/// ViewModel do pedido feito pelo cliente, via QR da mesa.
///
/// Sem login: quem tem o token do QR está fisicamente no salão. Todo o resto
/// (preço, senha, ministério) é decidido pelo banco.
class PedidoClienteViewModel extends GetxController {
  PedidoClienteViewModel({
    required PedidoRepository repo,
    required String qrToken,
  }) : _repo = repo,
       _qrToken = qrToken;

  final PedidoRepository _repo;
  final String _qrToken;

  final RxList<ItemCardapio> cardapio = <ItemCardapio>[].obs;
  final RxList<ItemPedidoCliente> carrinho = <ItemPedidoCliente>[].obs;

  final RxString nomeCliente = ''.obs;
  final RxString observacao = ''.obs;

  final RxBool carregando = true.obs;
  final RxBool enviando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  /// Preenchidos após o envio — a tela vira o acompanhamento da senha.
  final RxnString pedidoId = RxnString();
  final RxnString senha = RxnString();
  final Rx<StatusPedido> status = StatusPedido.recebido.obs;

  Timer? _acompanhamento;

  bool get enviado => pedidoId.value != null;
  bool get carrinhoVazio => carrinho.isEmpty;

  double get total =>
      carrinho.fold(0, (double s, ItemPedidoCliente i) => s + i.subtotal);

  int get quantidadeTotal =>
      carrinho.fold(0, (int s, ItemPedidoCliente i) => s + i.quantidade);

  @override
  void onInit() {
    super.onInit();
    carregarCardapio();
  }

  @override
  void onClose() {
    _acompanhamento?.cancel();
    super.onClose();
  }

  Future<void> carregarCardapio() async {
    carregando.value = true;
    falha.value = null;

    final Result<List<ItemCardapio>> r = await _repo.cardapio(_qrToken);
    r.fold(
      onOk: cardapio.assignAll,
      onFailure: (AppFailure f) => falha.value = f,
    );

    carregando.value = false;
  }

  // --- Carrinho --------------------------------------------------------------

  void adicionar(ItemCardapio item) {
    if (!item.disponivel) return;

    final int i = carrinho.indexWhere(
      (ItemPedidoCliente c) => c.produtoId == item.id,
    );

    if (i < 0) {
      carrinho.add(
        ItemPedidoCliente(
          produtoId: item.id,
          nome: item.nome,
          preco: item.preco,
          quantidade: 1,
        ),
      );
      return;
    }

    // Teto por item espelha o da RPC: melhor barrar aqui do que a chamada
    // inteira ser recusada depois de o cliente montar o pedido.
    if (carrinho[i].quantidade >= 50) return;
    carrinho[i] = carrinho[i].comQuantidade(carrinho[i].quantidade + 1);
  }

  void remover(String produtoId) {
    final int i = carrinho.indexWhere(
      (ItemPedidoCliente c) => c.produtoId == produtoId,
    );
    if (i < 0) return;

    if (carrinho[i].quantidade <= 1) {
      carrinho.removeAt(i);
    } else {
      carrinho[i] = carrinho[i].comQuantidade(carrinho[i].quantidade - 1);
    }
  }

  int quantidadeNoCarrinho(String produtoId) => carrinho
      .where((ItemPedidoCliente c) => c.produtoId == produtoId)
      .fold(0, (int s, ItemPedidoCliente c) => s + c.quantidade);

  void limparCarrinho() => carrinho.clear();

  void definirNome(String v) => nomeCliente.value = v;
  void definirObservacao(String v) => observacao.value = v;

  // --- Envio -----------------------------------------------------------------

  /// Envia o pedido. O guard de [enviando] impede duplicata por toque duplo —
  /// aqui vale ainda mais, porque a rede do celular do cliente é imprevisível.
  Future<bool> enviarPedido() async {
    if (enviando.value || carrinhoVazio) return false;

    enviando.value = true;
    falha.value = null;

    final Result<PedidoCriado> r = await _repo.criar(
      qrToken: _qrToken,
      itens: carrinho.toList(),
      clienteNome: nomeCliente.value.trim().isEmpty
          ? null
          : nomeCliente.value.trim(),
      observacao: observacao.value.trim().isEmpty
          ? null
          : observacao.value.trim(),
    );

    enviando.value = false;

    return r.fold(
      onOk: (PedidoCriado p) {
        pedidoId.value = p.id;
        senha.value = p.senha;
        _iniciarAcompanhamento();
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  /// Depois de enviar, a tela vira "acompanhe sua senha".
  ///
  /// Usa polling de 10s em vez de Realtime de propósito: o cliente é anônimo e
  /// abre a página por poucos minutos. Manter um WebSocket por cliente para
  /// observar uma única linha custaria mais conexões do que vale.
  void _iniciarAcompanhamento() {
    _acompanhamento?.cancel();
    _acompanhamento = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_conferirStatus()),
    );
  }

  Future<void> _conferirStatus() async {
    final String? id = pedidoId.value;
    if (id == null) return;

    final Result<StatusPedido> r = await _repo.statusDoPedido(id);
    r.fold(
      onOk: (StatusPedido s) {
        status.value = s;
        // Entregue ou cancelado: não há mais o que acompanhar.
        if (!s.naFila) _acompanhamento?.cancel();
      },
      onFailure: (_) {},
    );
  }

  /// "Fazer outro pedido" — volta ao cardápio zerando o estado.
  void novoPedido() {
    _acompanhamento?.cancel();
    pedidoId.value = null;
    senha.value = null;
    status.value = StatusPedido.recebido;
    carrinho.clear();
    observacao.value = '';
  }

  void limparFalha() => falha.value = null;
}

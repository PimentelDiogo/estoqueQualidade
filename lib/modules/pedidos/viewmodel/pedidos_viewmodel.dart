import 'dart:async';

import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/pedido.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';

/// Gestão da fila pelo caixa: avançar status e cobrar o pedido.
class PedidosViewModel extends GetxController {
  PedidosViewModel({
    required PedidoRepository repo,
    required ContextoOperacional session,
  }) : _repo = repo,
       _session = session;

  final PedidoRepository _repo;
  final ContextoOperacional _session;

  final RxList<Pedido> pedidos = <Pedido>[].obs;
  final RxBool carregando = false.obs;
  final RxBool salvando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  Timer? _atualizacao;

  String? get _ministerioId => _session.ministerioAtivoId.value;

  List<Pedido> porStatus(StatusPedido s) =>
      pedidos.where((Pedido p) => p.status == s).toList();

  int get totalNaFila => pedidos.length;

  @override
  void onInit() {
    super.onInit();
    carregar();

    // Polling em vez de Realtime: o caixa já está com a tela aberta e toca nela
    // o tempo todo. 15s é suficiente e evita mais uma inscrição de WebSocket
    // concorrendo com a da TV.
    _atualizacao = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(carregar(silencioso: true)),
    );
  }

  @override
  void onClose() {
    _atualizacao?.cancel();
    super.onClose();
  }

  Future<void> carregar({bool silencioso = false}) async {
    final String? id = _ministerioId;
    if (id == null) return;

    if (!silencioso) carregando.value = true;
    final Result<List<Pedido>> r = await _repo.filaDoMinisterio(id);

    r.fold(
      onOk: pedidos.assignAll,
      onFailure: (AppFailure f) {
        // Falha no polling de fundo não substitui a fila na tela por um erro.
        if (!silencioso) falha.value = f;
      },
    );

    carregando.value = false;
  }

  /// Avança o pedido para o próximo passo do fluxo.
  Future<bool> avancar(Pedido pedido) async {
    final StatusPedido? proximo = pedido.proximoStatus;
    if (proximo == null || salvando.value) return false;

    // "Entregue" fecha o pedido sem cobrar. Só faz sentido se ele já foi
    // cobrado; senão o caixa deve usar "Cobrar", que registra a venda.
    if (proximo == StatusPedido.entregue && !pedido.cobrado) {
      falha.value = const AppFailure.negocio(
        'Cobre o pedido antes de marcar como entregue.',
      );
      return false;
    }

    return _mudar(pedido.id, proximo);
  }

  Future<bool> cancelar(String pedidoId) =>
      _mudar(pedidoId, StatusPedido.cancelado);

  Future<bool> _mudar(String pedidoId, StatusPedido status) async {
    salvando.value = true;
    falha.value = null;

    final Result<void> r = await _repo.mudarStatus(
      pedidoId: pedidoId,
      status: status,
    );

    salvando.value = false;

    return r.fold(
      onOk: (_) {
        carregar(silencioso: true);
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  /// Cobra o pedido: cria a venda e baixa o estoque numa transação.
  ///
  /// É aqui que o estoque sai — não na criação do pedido. Um pedido abandonado
  /// no salão não pode segurar estoque que nunca foi vendido.
  Future<String?> cobrar({
    required String pedidoId,
    required TipoVenda tipo,
    double desconto = 0,
  }) async {
    if (salvando.value) return null;

    salvando.value = true;
    falha.value = null;

    final Result<String> r = await _repo.converterEmVenda(
      pedidoId: pedidoId,
      tipo: tipo,
      desconto: desconto,
    );

    salvando.value = false;

    return r.fold(
      onOk: (String vendaId) {
        carregar(silencioso: true);
        return vendaId;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return null;
      },
    );
  }

  void limparFalha() => falha.value = null;
}

import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/pedido.dart';
import '../../../data/services/order_queue_service.dart';

/// ViewModel do telão do salão.
///
/// Só lê. A TV não tem interação: fica ligada num canto, e ninguém toca nela.
class TvViewModel extends GetxController {
  TvViewModel({required OrderQueueService fila, required String qrToken})
    : _fila = fila,
      _qrToken = qrToken;

  final OrderQueueService _fila;
  final String _qrToken;

  final RxList<Pedido> pedidos = <Pedido>[].obs;
  final RxBool carregando = true.obs;

  /// `true` quando o stream falhou. A tela continua exibindo a última fila
  /// conhecida e mostra um aviso discreto — telão em branco no meio do culto
  /// seria pior que uma fila alguns segundos desatualizada.
  final RxBool semConexao = false.obs;

  /// Atualiza o relógio e o tempo de espera dos cards.
  final Rx<DateTime> agora = DateTime.now().obs;

  StreamSubscription<List<Pedido>>? _sub;
  Timer? _relogio;

  /// Prontos primeiro e em ordem de chegada: é a informação que o cliente
  /// procura ao olhar para o telão.
  List<Pedido> get prontos =>
      pedidos.where((Pedido p) => p.status == StatusPedido.pronto).toList();

  List<Pedido> get emPreparo => pedidos
      .where(
        (Pedido p) =>
            p.status == StatusPedido.recebido ||
            p.status == StatusPedido.preparando,
      )
      .toList();

  bool get vazia => pedidos.isEmpty;

  @override
  void onInit() {
    super.onInit();

    _sub = _fila
        .filaPorToken(_qrToken)
        .listen(
          (List<Pedido> lista) {
            pedidos.assignAll(lista);
            carregando.value = false;
            semConexao.value = false;
          },
          onError: (Object _) {
            carregando.value = false;
            semConexao.value = true;
          },
        );

    _relogio = Timer.periodic(
      const Duration(seconds: 20),
      (_) => agora.value = DateTime.now(),
    );
  }

  @override
  void onClose() {
    _relogio?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_fila.encerrar());
    super.onClose();
  }
}

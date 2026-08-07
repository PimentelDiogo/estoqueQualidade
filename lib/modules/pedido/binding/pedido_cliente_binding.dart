import 'package:get/get.dart';

import '../../../data/repositories/repositories.dart';
import '../viewmodel/pedido_cliente_viewmodel.dart';

/// DI do pedido do cliente. Sem login: o token do QR da mesa é a credencial.
class PedidoClienteBinding extends Bindings {
  @override
  void dependencies() {
    final String token = Get.parameters['token'] ?? '';

    Get.lazyPut<PedidoClienteViewModel>(
      () => PedidoClienteViewModel(
        repo: Get.find<PedidoRepository>(),
        qrToken: token,
      ),
    );
  }
}

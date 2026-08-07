import 'package:get/get.dart';

import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';
import '../../../data/services/session_service.dart';
import '../viewmodel/pedidos_viewmodel.dart';

class PedidosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PedidosViewModel>(
      () => PedidosViewModel(
        repo: Get.find<PedidoRepository>(),
        // SessionService implementa ContextoOperacional: a ViewModel so
        // conhece a interface, mas em producao recebe o service real.
        session: Get.find<SessionService>() as ContextoOperacional,
      ),
    );
  }
}

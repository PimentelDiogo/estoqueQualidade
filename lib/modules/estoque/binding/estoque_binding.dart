import 'package:get/get.dart';

import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';
import '../../../data/services/session_service.dart';
import '../viewmodel/estoque_viewmodel.dart';

/// Compartilhado entre `/estoque` e `/estoque/alertas`: as duas telas leem o
/// mesmo estado (produtos + alertas), e duplicar a ViewModel faria o badge de
/// alertas divergir entre elas.
class EstoqueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EstoqueViewModel>(
      () => EstoqueViewModel(
        produtoRepo: Get.find<ProdutoRepository>(),
        alertaRepo: Get.find<AlertaRepository>(),
        // SessionService implementa ContextoOperacional: a ViewModel so
        // conhece a interface, mas em producao recebe o service real.
        session: Get.find<SessionService>() as ContextoOperacional,
      ),
      fenix: true,
    );
  }
}

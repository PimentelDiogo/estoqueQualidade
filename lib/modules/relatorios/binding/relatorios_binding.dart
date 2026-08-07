import 'package:get/get.dart';

import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';
import '../../../data/services/session_service.dart';
import '../viewmodel/relatorios_viewmodel.dart';

class RelatoriosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RelatoriosViewModel>(
      () => RelatoriosViewModel(
        relatorioRepo: Get.find<RelatorioRepository>(),
        // SessionService implementa ContextoOperacional: a ViewModel so
        // conhece a interface, mas em producao recebe o service real.
        session: Get.find<SessionService>() as ContextoOperacional,
      ),
    );
  }
}

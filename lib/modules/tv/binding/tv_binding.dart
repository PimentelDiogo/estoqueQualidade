import 'package:get/get.dart';

import '../../../data/services/order_queue_service.dart';
import '../../../data/services/supabase_service.dart';
import '../viewmodel/tv_viewmodel.dart';

/// DI da TV. O token vem da URL (`/tv/:token`) — é o que identifica o
/// ministério, já que esta rota não tem login.
class TvBinding extends Bindings {
  @override
  void dependencies() {
    final String token = Get.parameters['token'] ?? '';

    // O service é criado por rota, não global: cada TV tem seu próprio canal de
    // Realtime, e sair da rota precisa encerrar a inscrição.
    Get.lazyPut<OrderQueueService>(
      () => OrderQueueServiceSupabase(Get.find<SupabaseService>()),
    );

    Get.lazyPut<TvViewModel>(
      () => TvViewModel(fila: Get.find<OrderQueueService>(), qrToken: token),
    );
  }
}

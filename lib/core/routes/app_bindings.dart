import 'package:get/get.dart';

import '../../data/repositories/ministerio_repository_supabase.dart';
import '../../data/repositories/pedido_repository_supabase.dart';
import '../../data/repositories/produto_repository_supabase.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/venda_repository_supabase.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferencias_service.dart';
import '../../data/services/session_service.dart';
import '../../data/services/supabase_service.dart';

/// DI global — services e repositories que vivem o app inteiro.
///
/// Repositories entram como `lazyPut` **permanente** com a interface como tipo:
/// as ViewModels pedem `Get.find<ProdutoRepository>()` e nunca conhecem a
/// implementacao Supabase. E o que permite trocar por um fake no teste.
class AppBinding extends Bindings {
  AppBinding(this._preferencias);

  final PreferenciasService _preferencias;

  @override
  void dependencies() {
    final SupabaseService supabase = Get.put(
      SupabaseService(),
      permanent: true,
    );

    // Ordem importa: SessionService le PreferenciasService e AuthService no
    // seu construtor.
    Get.put(_preferencias, permanent: true);
    Get.put(AuthService(), permanent: true);
    Get.put(SessionService(), permanent: true);

    Get.lazyPut<MinisterioRepository>(
      () => MinisterioRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<ProdutoRepository>(
      () => ProdutoRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<VendaRepository>(
      () => VendaRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<RelatorioRepository>(
      () => RelatorioRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<AlertaRepository>(
      () => AlertaRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<PedidoRepository>(
      () => PedidoRepositorySupabase(supabase),
      fenix: true,
    );
    Get.lazyPut<UsuarioRepository>(
      () => UsuarioRepositorySupabase(supabase),
      fenix: true,
    );
  }
}

import 'package:get/get.dart';

import '../../data/models/enums.dart';
import '../../modules/auth/binding/login_binding.dart';
import '../../modules/auth/view/login_page.dart';
import '../../modules/estoque/binding/estoque_binding.dart';
import '../../modules/estoque/view/alertas_page.dart';
import '../../modules/estoque/view/estoque_page.dart';
import '../../modules/estoque/view/scanner_page.dart';
import '../../modules/ministerios/binding/ministerios_binding.dart';
import '../../modules/ministerios/view/escolher_ministerio_page.dart';
import '../../modules/ministerios/view/ministerios_page.dart';
import '../../modules/pdv/binding/pdv_binding.dart';
import '../../modules/pdv/view/pdv_page.dart';
import '../../modules/pedido/binding/pedido_cliente_binding.dart';
import '../../modules/pedido/view/pedido_cliente_page.dart';
import '../../modules/pedidos/binding/pedidos_binding.dart';
import '../../modules/pedidos/view/pedidos_page.dart';
import '../../modules/relatorios/binding/relatorios_binding.dart';
import '../../modules/relatorios/view/relatorios_page.dart';
import '../../modules/showcase/showcase_page.dart';
import '../../modules/tv/binding/tv_binding.dart';
import '../../modules/tv/view/tv_page.dart';
import '../config/env.dart';
import 'app_routes.dart';
import 'rbac_middleware.dart';

/// Mapa de rotas do GetX.
///
/// Cada rota carrega **seu proprio binding** (regra 3): a ViewModel nasce ao
/// entrar na tela e morre ao sair, sem `Get.put` solto no `main`.
abstract final class AppPages {
  static const String inicial = Rotas.login;

  static final List<GetPage<dynamic>> paginas = <GetPage<dynamic>>[
    GetPage<void>(
      name: Rotas.login,
      page: () => const LoginPage(),
      binding: LoginBinding(),
    ),

    // Escolha de ministerio: exige login, mas nao exige ministerio ativo —
    // seria um ciclo de redirecionamento.
    GetPage<void>(
      name: Rotas.escolherMinisterio,
      page: () => const EscolherMinisterioPage(),
      binding: MinisteriosBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware()],
    ),

    // --- Operacao: exigem ministerio em foco ---------------------------------
    GetPage<void>(
      name: Rotas.pdv,
      page: () => const PdvPage(),
      binding: PdvBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware(exigeMinisterioAtivo: true)],
    ),
    GetPage<void>(
      name: Rotas.estoque,
      page: () => const EstoquePage(),
      binding: EstoqueBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware(exigeMinisterioAtivo: true)],
    ),
    GetPage<void>(
      name: Rotas.alertas,
      page: () => const AlertasPage(),
      binding: EstoqueBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware(exigeMinisterioAtivo: true)],
    ),
    GetPage<void>(
      name: Rotas.relatorios,
      page: () => const RelatoriosPage(),
      binding: RelatoriosBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware(exigeMinisterioAtivo: true)],
    ),

    GetPage<void>(
      name: Rotas.pedidos,
      page: () => const PedidosPage(),
      binding: PedidosBinding(),
      middlewares: <GetMiddleware>[RbacMiddleware(exigeMinisterioAtivo: true)],
    ),

    // --- Publicas: sem login, identificadas pelo token do QR ----------------
    //
    // NAO tem RbacMiddleware de proposito. A protecao e a RLS + as RPCs
    // SECURITY DEFINER, que so devolvem o que o token autoriza (ADR-004).
    GetPage<void>(
      name: Rotas.tv,
      page: () => const TvPage(),
      binding: TvBinding(),
    ),
    GetPage<void>(
      name: Rotas.pedidoCliente,
      page: () => const PedidoClientePage(),
      binding: PedidoClienteBinding(),
    ),

    // Scanner: sem binding proprio (nao tem ViewModel) e sem exigir ministerio,
    // porque tambem e usado no cadastro de produto.
    GetPage<String>(
      name: Rotas.scanner,
      page: () => const ScannerPage(),
      middlewares: <GetMiddleware>[RbacMiddleware()],
    ),

    // --- Somente admin -------------------------------------------------------
    GetPage<void>(
      name: Rotas.ministerios,
      page: () => const MinisteriosPage(),
      binding: MinisteriosBinding(),
      middlewares: <GetMiddleware>[
        RbacMiddleware(papeisPermitidos: <PapelUsuario>{PapelUsuario.admin}),
      ],
    ),

    // --- Dev -----------------------------------------------------------------
    GetPage<void>(
      name: Rotas.showcase,
      page: () => const ShowcasePage(),
      middlewares: <GetMiddleware>[
        DevOnlyMiddleware(habilitado: Env.showcaseEnabled),
      ],
    ),
  ];
}

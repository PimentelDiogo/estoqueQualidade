import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/models/enums.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';
import 'app_routes.dart';

/// Middleware de navegacao por papel.
///
/// ⚠️ Isto **nao e controle de acesso**. Flutter Web e codigo aberto no
/// navegador: qualquer pessoa pode chamar a API direto com a anon key. Quem
/// autoriza de verdade e a RLS do Postgres (ADR-004). O middleware existe para
/// o voluntario nao ver uma tela que ele nunca conseguiria usar.
class RbacMiddleware extends GetMiddleware {
  RbacMiddleware({this.papeisPermitidos, this.exigeMinisterioAtivo = false});

  /// `null` = qualquer usuario logado.
  final Set<PapelUsuario>? papeisPermitidos;

  /// Telas operacionais (PDV, estoque) precisam de um ministerio em foco.
  final bool exigeMinisterioAtivo;

  @override
  RouteSettings? redirect(String? route) {
    final AuthService auth = Get.find<AuthService>();
    final perfil = auth.perfil.value;

    // Ainda restaurando a sessao: nao redireciona, senao pisca o login numa
    // simples recarga de aba.
    if (auth.carregando.value) return null;

    if (perfil == null) {
      return const RouteSettings(name: Rotas.login);
    }

    if (!perfil.podeOperar) {
      // Cadastrado mas ainda nao liberado por um admin.
      return const RouteSettings(name: Rotas.login);
    }

    if (papeisPermitidos != null && !papeisPermitidos!.contains(perfil.papel)) {
      // Sem permissao: manda para a tela inicial do papel dele, nao para o
      // login — deslogar quem esta logado seria confuso.
      return RouteSettings(name: rotaInicialDe(perfil.papel));
    }

    if (exigeMinisterioAtivo &&
        Get.find<SessionService>().ministerioAtivoId.value == null) {
      return const RouteSettings(name: Rotas.escolherMinisterio);
    }

    return null;
  }

  /// Onde cada papel comeca depois do login.
  static String rotaInicialDe(PapelUsuario papel) => switch (papel) {
    // Admin gerencia; a visao dele comeca nos relatorios.
    PapelUsuario.admin => Rotas.relatorios,
    // Caixa cai direto no PDV: e o que ele faz 95% do tempo.
    PapelUsuario.caixa => Rotas.pdv,
  };
}

/// Bloqueia rotas de dev (ex.: `/showcase`) em producao.
class DevOnlyMiddleware extends GetMiddleware {
  DevOnlyMiddleware({required this.habilitado});

  final bool habilitado;

  @override
  RouteSettings? redirect(String? route) =>
      habilitado ? null : const RouteSettings(name: Rotas.login);
}

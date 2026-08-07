import 'dart:async';

import 'package:get/get.dart';

import '../models/perfil_usuario.dart';
import 'auth_service.dart';
import 'contexto_operacional.dart';
import 'preferencias_service.dart';

/// Contexto operacional da sessao: **qual ministerio esta em foco**.
///
/// Para o caixa isso e fixo (o proprio). Para o admin e uma escolha — ele
/// enxerga todos, mas opera um de cada vez, senao "vender um cafe" ficaria
/// ambiguo entre ministerios.
class SessionService extends GetxService implements ContextoOperacional {
  static SessionService get to => Get.find<SessionService>();

  final PreferenciasService _prefs = PreferenciasService.to;
  final AuthService _auth = AuthService.to;

  /// Ministerio em foco. Persistido para o admin nao ter que reescolher
  /// a cada recarga da aba.
  @override
  final RxnString ministerioAtivoId = RxnString();

  @override
  final RxnString ministerioAtivoNome = RxnString();

  PerfilUsuario? get perfil => _auth.perfil.value;

  bool get isAdmin => perfil?.isAdmin ?? false;

  /// O admin pode trocar de ministerio; o caixa esta preso ao seu.
  @override
  bool get podeTrocarMinisterio => isAdmin;

  /// Pronto para operar o PDV/estoque: logado, liberado e com ministerio em foco.
  bool get pronto =>
      (perfil?.podeOperar ?? false) && ministerioAtivoId.value != null;

  @override
  void onInit() {
    super.onInit();

    // O ministerio ativo segue o perfil: ao logar/deslogar, recalcula.
    ever<PerfilUsuario?>(_auth.perfil, _sincronizarComPerfil);
    _sincronizarComPerfil(_auth.perfil.value);
  }

  void _sincronizarComPerfil(PerfilUsuario? p) {
    if (p == null) {
      ministerioAtivoId.value = null;
      ministerioAtivoNome.value = null;
      return;
    }

    if (p.isCaixa) {
      // Caixa nao escolhe: e sempre o ministerio do seu vinculo. Persistir a
      // escolha aqui seria abrir espaco para operar no ministerio errado.
      ministerioAtivoId.value = p.ministerioId;
      ministerioAtivoNome.value = p.ministerioNome;
      return;
    }

    // Admin: retoma a ultima escolha, se houver.
    final String? salvo = _prefs.ministerioAtivoId;
    ministerioAtivoId.value = salvo;
    if (salvo == null) ministerioAtivoNome.value = null;
  }

  /// Troca o ministerio em foco. Ignorado para caixa (defesa em profundidade —
  /// a RLS ja barraria a operacao no servidor).
  @override
  void definirMinisterioAtivo({required String id, required String nome}) {
    if (!podeTrocarMinisterio) return;
    ministerioAtivoId.value = id;
    ministerioAtivoNome.value = nome;
    unawaited(_prefs.definirMinisterioAtivo(id));
  }

  void limparMinisterioAtivo() {
    ministerioAtivoId.value = null;
    ministerioAtivoNome.value = null;
    unawaited(_prefs.limparMinisterioAtivo());
  }

  /// Subtitulo do cabecalho: o voluntario precisa enxergar em que ministerio
  /// esta operando antes de registrar qualquer venda.
  String get descricaoContexto {
    final PerfilUsuario? p = perfil;
    if (p == null) return '';
    final String ministerio = ministerioAtivoNome.value ?? 'Nenhum ministerio';
    return '${p.nome} - $ministerio';
  }
}

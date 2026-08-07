import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/result.dart';
import '../models/perfil_usuario.dart';
import 'supabase_service.dart';

/// Autenticacao e carga do perfil (papel + ministerio).
///
/// Guarda o estado reativo de "quem esta logado". Quem consome e o
/// [SessionService] e o `RbacMiddleware` — as Views nunca chamam isto direto.
class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  final SupabaseService _supabase = SupabaseService.to;

  /// Perfil do usuario atual. `null` = deslogado (ou sessao invalidada).
  final Rxn<PerfilUsuario> perfil = Rxn<PerfilUsuario>();

  /// `true` enquanto restaura a sessao no boot — evita piscar o login.
  final RxBool carregando = true.obs;

  StreamSubscription<AuthState>? _authSub;

  bool get logado => perfil.value != null;

  @override
  void onInit() {
    super.onInit();

    // Reage a login/logout/refresh vindos do SDK (inclusive de outra aba).
    _authSub = _supabase.auth.onAuthStateChange.listen((AuthState state) async {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          await _carregarPerfil();
        case AuthChangeEvent.signedOut:
          perfil.value = null;
        default:
          break;
      }
    });

    unawaited(_restaurarSessao());
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  Future<void> _restaurarSessao() async {
    carregando.value = true;
    if (_supabase.auth.currentSession != null) {
      await _carregarPerfil();
    }
    carregando.value = false;
  }

  /// Le `perfil_usuario` do proprio usuario (a RLS ja limita a ele mesmo).
  Future<Result<PerfilUsuario>> _carregarPerfil() async {
    final String? uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      perfil.value = null;
      return const Failure<PerfilUsuario>(AppFailure.autenticacao());
    }

    final Result<PerfilUsuario> resultado = await _supabase
        .executar<PerfilUsuario>(() async {
          final Map<String, dynamic> row = await _supabase.client
              .from('perfil_usuario')
              .select(
                'id, nome, papel, ministerio_id, ativo, '
                'ministerio:ministerio_id ( nome )',
              )
              .eq('id', uid)
              .single();
          return PerfilUsuario.fromMap(row);
        }, contexto: 'carregarPerfil');

    resultado.fold(
      onOk: (PerfilUsuario p) => perfil.value = p,
      onFailure: (_) => perfil.value = null,
    );

    return resultado;
  }

  /// Login por e-mail e senha (admin e caixa).
  ///
  /// Recusa quem ainda nao foi liberado pelo admin: o perfil nasce inativo de
  /// proposito, entao autenticar no Supabase nao basta para entrar no sistema.
  Future<Result<PerfilUsuario>> entrar({
    required String email,
    required String senha,
  }) async {
    final Result<void> login = await _supabase.executar<void>(() async {
      await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: senha,
      );
    }, contexto: 'entrar');

    if (login case Failure<void>(:final AppFailure failure)) {
      return Failure<PerfilUsuario>(
        failure.kind == FailureKind.autenticacao
            ? const AppFailure(
                mensagem: 'E-mail ou senha incorretos.',
                kind: FailureKind.autenticacao,
              )
            : failure,
      );
    }

    final Result<PerfilUsuario> comPerfil = await _carregarPerfil();

    if (comPerfil case Ok<PerfilUsuario>(
      value: final PerfilUsuario p,
    ) when !p.podeOperar) {
      await sair();
      return const Failure<PerfilUsuario>(
        AppFailure.negocio(
          'Seu acesso ainda nao foi liberado. '
          'Peca a um administrador para ativar seu usuario.',
        ),
      );
    }

    return comPerfil;
  }

  Future<Result<void>> sair() async {
    final Result<void> r = await _supabase.executar<void>(
      () => _supabase.auth.signOut(),
      contexto: 'sair',
    );
    perfil.value = null;
    return r;
  }

  /// Reconfere o perfil no servidor (ex.: admin mudou o papel durante a sessao).
  Future<Result<PerfilUsuario>> recarregarPerfil() => _carregarPerfil();

  Future<Result<void>> enviarRecuperacaoDeSenha(String email) =>
      _supabase.executar<void>(
        () => _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase()),
        contexto: 'recuperarSenha',
      );
}

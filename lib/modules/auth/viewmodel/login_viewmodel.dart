import 'package:get/get.dart';

import '../../../core/routes/rbac_middleware.dart';
import '../../../core/utils/result.dart';
import '../../../data/models/perfil_usuario.dart';
import '../../../data/services/auth_service.dart';

/// ViewModel do login.
///
/// Nao importa `supabase_flutter` (regra 2): fala apenas com o [AuthService].
class LoginViewModel extends GetxController {
  LoginViewModel(this._auth);

  final AuthService _auth;

  final RxString email = ''.obs;
  final RxString senha = ''.obs;
  final RxBool ocultarSenha = true.obs;
  final RxBool carregando = false.obs;

  /// Erro geral (credencial errada, acesso nao liberado, rede fora).
  final RxnString erro = RxnString();

  /// Erros por campo — mostrados sob o proprio input.
  final RxnString erroEmail = RxnString();
  final RxnString erroSenha = RxnString();

  final RxnString mensagemSucesso = RxnString();

  bool get formularioValido =>
      email.value.trim().isNotEmpty && senha.value.isNotEmpty;

  void aoDigitarEmail(String v) {
    email.value = v;
    erroEmail.value = null;
    erro.value = null;
  }

  void aoDigitarSenha(String v) {
    senha.value = v;
    erroSenha.value = null;
    erro.value = null;
  }

  void alternarVisibilidadeSenha() => ocultarSenha.value = !ocultarSenha.value;

  bool _validar() {
    erroEmail.value = null;
    erroSenha.value = null;

    final String e = email.value.trim();
    if (e.isEmpty) {
      erroEmail.value = 'Informe o e-mail';
    } else if (!e.contains('@') || !e.contains('.')) {
      erroEmail.value = 'E-mail invalido';
    }

    if (senha.value.isEmpty) {
      erroSenha.value = 'Informe a senha';
    }

    return erroEmail.value == null && erroSenha.value == null;
  }

  Future<void> entrar() async {
    if (carregando.value) return; // ignora duplo toque
    if (!_validar()) return;

    carregando.value = true;
    erro.value = null;

    final Result<PerfilUsuario> resultado = await _auth.entrar(
      email: email.value,
      senha: senha.value,
    );

    carregando.value = false;

    resultado.fold(
      onOk: (PerfilUsuario perfil) {
        senha.value = '';
        // offAllNamed: limpa a pilha para o botao "voltar" do navegador nao
        // trazer o usuario de volta ao login ja autenticado.
        Get.offAllNamed<void>(RbacMiddleware.rotaInicialDe(perfil.papel));
      },
      onFailure: (AppFailure f) => erro.value = f.mensagem,
    );
  }

  /// Envia o e-mail de redefinicao. Nao revela se a conta existe.
  Future<void> recuperarSenha() async {
    final String e = email.value.trim();
    if (e.isEmpty) {
      erroEmail.value = 'Informe o e-mail para recuperar a senha';
      return;
    }

    carregando.value = true;
    final Result<void> r = await _auth.enviarRecuperacaoDeSenha(e);
    carregando.value = false;

    r.fold(
      onOk: (_) => mensagemSucesso.value =
          'Se este e-mail estiver cadastrado, enviamos um link de recuperacao.',
      onFailure: (AppFailure f) => erro.value = f.mensagem,
    );
  }
}

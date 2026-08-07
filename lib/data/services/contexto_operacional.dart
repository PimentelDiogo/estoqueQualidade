import 'package:get/get.dart';

/// O que as ViewModels precisam saber sobre a sessao: **qual ministerio esta em
/// foco**.
///
/// Existe como interface pelo mesmo motivo dos Repositories (regra 2 do
/// CLAUDE.md): o `SessionService` concreto depende de `AuthService`, que depende
/// de `SupabaseService`. Sem esta abstracao, testar a logica do caixa exigiria
/// subir o SDK do Supabase inteiro.
abstract interface class ContextoOperacional {
  /// Ministerio em foco. `null` = nenhum escolhido ainda.
  RxnString get ministerioAtivoId;

  RxnString get ministerioAtivoNome;

  /// So o admin troca de ministerio; o caixa esta preso ao seu.
  bool get podeTrocarMinisterio;

  void definirMinisterioAtivo({required String id, required String nome});
}

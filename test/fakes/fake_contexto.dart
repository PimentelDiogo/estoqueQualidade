import 'package:espaco_cafe/data/services/contexto_operacional.dart';
import 'package:get/get.dart';

import 'fake_repositories.dart';

/// Contexto operacional em memoria, sem `AuthService` nem Supabase.
class FakeContexto implements ContextoOperacional {
  FakeContexto({String? ministerioId = kMinisterioId, this.admin = true}) {
    ministerioAtivoId.value = ministerioId;
    ministerioAtivoNome.value = ministerioId == null ? null : 'Espaco Cafe';
  }

  final bool admin;

  @override
  final RxnString ministerioAtivoId = RxnString();

  @override
  final RxnString ministerioAtivoNome = RxnString();

  @override
  bool get podeTrocarMinisterio => admin;

  @override
  void definirMinisterioAtivo({required String id, required String nome}) {
    if (!podeTrocarMinisterio) return;
    ministerioAtivoId.value = id;
    ministerioAtivoNome.value = nome;
  }
}

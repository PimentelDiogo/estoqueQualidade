import 'package:get/get.dart';

import '../../../core/utils/result.dart';
import '../../../data/models/ministerio.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/services/contexto_operacional.dart';

class MinisteriosViewModel extends GetxController {
  MinisteriosViewModel({
    required MinisterioRepository repo,
    required ContextoOperacional session,
  }) : _repo = repo,
       _session = session;

  final MinisterioRepository _repo;
  final ContextoOperacional _session;

  final RxList<Ministerio> ministerios = <Ministerio>[].obs;
  final RxList<Mesa> mesas = <Mesa>[].obs;

  final RxBool carregando = false.obs;
  final RxBool salvando = false.obs;
  final Rxn<AppFailure> falha = Rxn<AppFailure>();

  @override
  void onInit() {
    super.onInit();
    carregar();
  }

  Future<void> carregar() async {
    carregando.value = true;
    falha.value = null;

    // A RLS ja limita: admin recebe todos, caixa so o proprio.
    final Result<List<Ministerio>> r = await _repo.listar(apenasAtivos: false);
    r.fold(
      onOk: ministerios.assignAll,
      onFailure: (AppFailure f) => falha.value = f,
    );

    carregando.value = false;
  }

  Future<bool> salvar(Ministerio m, {required bool novo}) async {
    if (salvando.value) return false;

    salvando.value = true;
    falha.value = null;

    final Result<Ministerio> r = novo
        ? await _repo.criar(m)
        : await _repo.atualizar(m);

    salvando.value = false;

    return r.fold(
      onOk: (Ministerio salvo) {
        carregar();
        // Se o ministerio editado e o que esta em foco, atualiza o rotulo do
        // cabecalho na hora.
        if (_session.ministerioAtivoId.value == salvo.id) {
          _session.definirMinisterioAtivo(id: salvo.id, nome: salvo.nome);
        }
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  Future<bool> enviarImagemQr({
    required String ministerioId,
    required List<int> bytes,
    required String extensao,
  }) async {
    salvando.value = true;
    final Result<String> r = await _repo.enviarImagemQrPix(
      ministerioId: ministerioId,
      bytes: bytes,
      extensao: extensao,
    );
    salvando.value = false;

    return r.fold(
      onOk: (String url) async {
        final Ministerio? atual = ministerios
            .where((Ministerio m) => m.id == ministerioId)
            .firstOrNull;
        if (atual == null) return false;
        return salvar(atual.copyWith(pixQrImageUrl: url), novo: false);
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  void selecionarComoAtivo(Ministerio m) =>
      _session.definirMinisterioAtivo(id: m.id, nome: m.nome);

  // --- Mesas (QR de identificacao, Fase 2) -----------------------------------

  Future<void> carregarMesas(String ministerioId) async {
    final Result<List<Mesa>> r = await _repo.listarMesas(ministerioId);
    r.fold(onOk: mesas.assignAll, onFailure: (_) => mesas.clear());
  }

  Future<bool> criarMesa({
    required String ministerioId,
    required String identificador,
  }) async {
    if (identificador.trim().isEmpty) return false;

    final Result<Mesa> r = await _repo.criarMesa(
      ministerioId: ministerioId,
      identificador: identificador,
    );

    return r.fold(
      onOk: (Mesa m) {
        mesas.add(m);
        return true;
      },
      onFailure: (AppFailure f) {
        falha.value = f;
        return false;
      },
    );
  }

  void limparFalha() => falha.value = null;
}

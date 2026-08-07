import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local simples (o ministerio que o admin escolheu por ultimo).
///
/// Envolve o `SharedPreferences` para que o resto do app nunca precise lidar
/// com a instancia assincrona: ela e resolvida uma unica vez no boot
/// ([carregar]) e depois lida de forma sincrona.
///
/// Nao guarda nada sensivel — sessao e token sao responsabilidade do SDK do
/// Supabase.
class PreferenciasService extends GetxService {
  PreferenciasService(this._prefs);

  static PreferenciasService get to => Get.find<PreferenciasService>();

  final SharedPreferences _prefs;

  static const String _kMinisterioAtivo = 'ministerio_ativo_id';

  /// Chamado uma vez no `main()`, antes de qualquer tela.
  static Future<PreferenciasService> carregar() async =>
      PreferenciasService(await SharedPreferences.getInstance());

  String? get ministerioAtivoId => _prefs.getString(_kMinisterioAtivo);

  Future<void> definirMinisterioAtivo(String id) =>
      _prefs.setString(_kMinisterioAtivo, id);

  Future<void> limparMinisterioAtivo() => _prefs.remove(_kMinisterioAtivo);
}

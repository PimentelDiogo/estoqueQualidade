/// Configuracao vinda de `--dart-define-from-file=env.json`.
///
/// REGRA DE SEGURANCA: nenhuma chave no codigo. `env.json` esta no `.gitignore`;
/// use `env.example.json` como modelo.
///
/// A `anon key` do Supabase e publica por natureza (vai no bundle do Flutter Web e
/// qualquer um le no navegador). Por isso a autorizacao real mora na **RLS** do
/// Postgres, nunca no cliente — ver ADR-004.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static bool get isDev => appEnv == 'dev';

  /// Rota `/showcase` (galeria de componentes) so existe fora de producao.
  static bool get showcaseEnabled => isDev;

  /// Falha cedo e com mensagem clara, em vez de estourar um erro obscuro do
  /// Supabase na primeira query.
  static void validar() {
    final List<String> faltando = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (faltando.isNotEmpty) {
      throw StateError(
        'Configuracao ausente: ${faltando.join(', ')}.\n'
        'Copie env.example.json para env.json, preencha, e rode com:\n'
        '  fvm flutter run -d chrome --dart-define-from-file=env.json',
      );
    }
  }
}

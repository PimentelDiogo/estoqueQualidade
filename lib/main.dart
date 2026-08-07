import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/routes/app_bindings.dart';
import 'core/routes/app_pages.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'data/services/preferencias_service.dart';
import 'data/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formatos de moeda e data pt_BR usados em todo o app.
  await initializeDateFormatting('pt_BR');
  final PreferenciasService preferencias = await PreferenciasService.carregar();

  // Se as chaves faltarem, mostramos uma tela explicando o que fazer em vez de
  // deixar o app quebrar na primeira query com um erro obscuro do Supabase.
  String? erroDeConfiguracao;
  try {
    await SupabaseService.inicializar();
  } catch (e) {
    erroDeConfiguracao = e.toString();
  }

  runApp(
    erroDeConfiguracao == null
        ? EspacoCafeApp(preferencias: preferencias)
        : _AppComErroDeConfiguracao(mensagem: erroDeConfiguracao),
  );
}

class EspacoCafeApp extends StatelessWidget {
  const EspacoCafeApp({required this.preferencias, super.key});

  /// Resolvido no `main()`: o SharedPreferences e assincrono, mas o resto do
  /// app precisa ler a preferencia de forma sincrona.
  final PreferenciasService preferencias;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Espaco Cafe - PAES Lagoa',
      debugShowCheckedModeBanner: false,

      // Dark-first: o preto vem da logo e da o melhor contraste no celular do
      // voluntario durante o culto, com luz baixa. Nao ha tema claro.
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      initialBinding: AppBinding(preferencias),
      initialRoute: AppPages.inicial,
      getPages: AppPages.paginas,

      defaultTransition: Transition.fadeIn,
      transitionDuration: AppDuration.fast,
    );
  }
}

/// Tela de erro de configuracao (chaves do Supabase ausentes).
class _AppComErroDeConfiguracao extends StatelessWidget {
  const _AppComErroDeConfiguracao({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Espaco Cafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.settings_outlined,
                    size: 56,
                    color: AppColors.warning,
                  ),
                  AppSpacing.gapLg,
                  Text(
                    'Configuracao incompleta',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapLg,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.brMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      mensagem,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

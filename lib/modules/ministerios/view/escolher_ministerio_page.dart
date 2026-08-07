import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/ministerio.dart';
import '../../../data/services/auth_service.dart';
import '../viewmodel/ministerios_viewmodel.dart';

/// Escolha do ministerio em foco.
///
/// So o admin chega aqui: o caixa esta vinculado a um ministerio e nao escolhe.
/// Existe porque "vender um cafe" precisa saber **por qual ministerio** — e
/// registrar no errado e o erro mais caro do sistema.
class EscolherMinisterioPage extends GetView<MinisteriosViewModel> {
  const EscolherMinisterioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher ministerio'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Get.find<AuthService>().sair();
              await Get.offAllNamed<void>(Rotas.login);
            },
          ),
          AppSpacing.gapSm,
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: const ResponsiveValue<double>(
            mobile: double.infinity,
            tablet: 600,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Em qual ministerio voce vai operar?',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'As vendas e o estoque serao registrados neste ministerio.',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapXl,
              Expanded(
                child: Obx(() {
                  if (controller.carregando.value) return const AppLoading();

                  final List<Ministerio> ativos = controller.ministerios
                      .where((Ministerio m) => m.ativo)
                      .toList();

                  if (ativos.isEmpty) {
                    return EmptyState(
                      titulo: 'Nenhum ministerio ativo',
                      descricao:
                          'Cadastre o Espaco Cafe para comecar a registrar vendas.',
                      icone: Icons.groups_outlined,
                      acaoLabel: 'Ir para Ministerios',
                      onAcao: () => Get.offAllNamed<void>(Rotas.ministerios),
                    );
                  }

                  return ListView.separated(
                    itemCount: ativos.length,
                    separatorBuilder: (BuildContext ctx, int i) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final Ministerio m = ativos[i];
                      return AppCard(
                        onTap: () {
                          controller.selecionarComoAtivo(m);
                          Get.offAllNamed<void>(Rotas.pdv);
                        },
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.brandRose,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    m.nome,
                                    style: AppTypography.titleMedium,
                                  ),
                                  Text(
                                    m.responsavelNome ?? 'Sem responsavel',
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'Gerenciar ministerios',
                icon: Icons.settings_outlined,
                variant: AppButtonVariant.secondary,
                expanded: true,
                onPressed: () => Get.offAllNamed<void>(Rotas.ministerios),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

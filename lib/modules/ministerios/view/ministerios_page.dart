import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/ministerio.dart';
import '../viewmodel/ministerios_viewmodel.dart';
import 'widgets/mesas_dialog.dart';
import 'widgets/ministerio_form_dialog.dart';

class MinisteriosPage extends GetView<MinisteriosViewModel> {
  const MinisteriosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      rotaAtual: Rotas.ministerios,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ministerios')),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Novo ministerio'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const MinisterioFormDialog(),
          ),
        ),
        body: SafeArea(
          child: ResponsiveBody(
            child: Obx(() {
              if (controller.carregando.value &&
                  controller.ministerios.isEmpty) {
                return const AppLoading();
              }

              final falha = controller.falha.value;
              if (falha != null && controller.ministerios.isEmpty) {
                return EmptyState.erro(
                  falha,
                  onTentarDeNovo: controller.carregar,
                );
              }

              if (controller.ministerios.isEmpty) {
                return const EmptyState(
                  titulo: 'Nenhum ministerio',
                  descricao:
                      'Cadastre o Espaco Cafe para comecar a registrar vendas.',
                  icone: Icons.groups_outlined,
                );
              }

              return ListView.separated(
                itemCount: controller.ministerios.length,
                separatorBuilder: (BuildContext ctx, int i) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) =>
                    _CardMinisterio(ministerio: controller.ministerios[i]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CardMinisterio extends GetView<MinisteriosViewModel> {
  const _CardMinisterio({required this.ministerio});

  final Ministerio ministerio;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(ministerio.nome, style: AppTypography.titleLarge),
              ),
              if (!ministerio.ativo)
                const AppBadge(label: 'Inativo', color: AppColors.textDisabled),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ministerio.responsavelNome ?? 'Sem responsavel cadastrado',
            style: AppTypography.bodySmall,
          ),
          AppSpacing.gapMd,

          // Os dois pre-requisitos operacionais, visiveis de relance: sem PIX
          // o caixa nao cobra por Pix; sem e-mail o alerta de estoque nao sai.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppBadge(
                label: ministerio.temPix ? 'QR Pix ok' : 'Sem QR Pix',
                color: ministerio.temPix
                    ? AppColors.success
                    : AppColors.warning,
                icon: Icons.qr_code_2,
              ),
              AppBadge(
                label: ministerio.recebeEmailDeAlerta
                    ? 'Alerta por e-mail'
                    : 'Sem e-mail de alerta',
                color: ministerio.recebeEmailDeAlerta
                    ? AppColors.success
                    : AppColors.warning,
                icon: Icons.mail_outline,
              ),
            ],
          ),

          AppSpacing.gapLg,
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MinisterioFormDialog(ministerio: ministerio),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.table_restaurant_outlined, size: 18),
                label: const Text('Mesas / QR'),
                onPressed: () {
                  controller.carregarMesas(ministerio.id);
                  showDialog<void>(
                    context: context,
                    builder: (_) => MesasDialog(ministerio: ministerio),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Operar neste'),
                onPressed: () {
                  controller.selecionarComoAtivo(ministerio);
                  Get.offAllNamed<void>(Rotas.pdv);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

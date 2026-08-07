import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../data/models/pedido.dart';
import '../viewmodel/tv_viewmodel.dart';

/// Telão do salão: senhas prontas à esquerda, em preparo à direita.
///
/// Restrições reais desta tela, diferentes do resto do app:
/// - leitura a **vários metros** de distância → tipografia gigante;
/// - **sem interação** e sem login (rota pública por token);
/// - **sem valores** — a TV nunca mostra dinheiro.
class TvPage extends GetView<TvViewModel> {
  const TvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _Cabecalho(),
            Expanded(
              child: Obx(() {
                if (controller.carregando.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandRose,
                    ),
                  );
                }

                if (controller.vazia) return const _SemPedidos();

                // No salão a TV é sempre larga; o layout empilhado só existe
                // como defesa para quem abrir a rota no celular para conferir.
                return context.isMobile
                    ? const _ColunasEmpilhadas()
                    : const _ColunasLadoALado();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends GetView<TvViewModel> {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.coffee_outlined,
            color: AppColors.brandCream,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            'Espaco Cafe',
            style: context.scaled(AppTypography.headlineLarge),
          ),
          const Spacer(),
          Obx(() {
            if (!controller.semConexao.value) return const SizedBox.shrink();
            // Aviso discreto: a fila exibida pode estar velha, mas continua
            // sendo mais útil que uma tela em branco.
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_outlined,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Reconectando',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(
            () => Text(
              Datas.hora(controller.agora.value),
              style: context.scaled(AppTypography.headlineMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColunasLadoALado extends GetView<TvViewModel> {
  const _ColunasLadoALado();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Pronto ocupa mais espaço: é o que o cliente está procurando.
        Expanded(
          flex: 3,
          child: _Coluna(
            titulo: 'PRONTO',
            cor: AppColors.success,
            pedidos: controller.prontos,
            destaque: true,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _Coluna(
            titulo: 'PREPARANDO',
            cor: AppColors.warning,
            pedidos: controller.emPreparo,
          ),
        ),
      ],
    );
  }
}

class _ColunasEmpilhadas extends GetView<TvViewModel> {
  const _ColunasEmpilhadas();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _Coluna(
            titulo: 'PRONTO',
            cor: AppColors.success,
            pedidos: controller.prontos,
            destaque: true,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _Coluna(
            titulo: 'PREPARANDO',
            cor: AppColors.warning,
            pedidos: controller.emPreparo,
          ),
        ),
      ],
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.titulo,
    required this.cor,
    required this.pedidos,
    this.destaque = false,
  });

  final String titulo;
  final Color cor;
  final List<Pedido> pedidos;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                titulo,
                style: context
                    .scaled(AppTypography.headlineMedium)
                    .copyWith(color: cor, letterSpacing: 3),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${pedidos.length}',
                style: context
                    .scaled(AppTypography.headlineMedium)
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          AppSpacing.gapXl,
          Expanded(
            child: pedidos.isEmpty
                ? Center(
                    child: Text(
                      '—',
                      style: context
                          .scaled(AppTypography.displayLarge)
                          .copyWith(color: AppColors.textDisabled),
                    ),
                  )
                : GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      // Extent máximo em vez de nº fixo de colunas: a TV pode
                      // ser 1080p ou 4K e o card mantém o tamanho legível.
                      maxCrossAxisExtent: destaque ? 320 : 260,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: pedidos.length,
                    itemBuilder: (BuildContext context, int i) => _CardSenha(
                      pedido: pedidos[i],
                      cor: cor,
                      destaque: destaque,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CardSenha extends StatelessWidget {
  const _CardSenha({
    required this.pedido,
    required this.cor,
    required this.destaque,
  });

  final Pedido pedido;
  final Color cor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    // Espera longa vira sinal visual: o voluntário que passa pelo salão
    // percebe o pedido esquecido sem precisar conferir uma lista.
    final bool esperandoDemais =
        !destaque && pedido.espera > const Duration(minutes: 10);

    return Container(
      decoration: BoxDecoration(
        color: destaque ? cor.withValues(alpha: 0.16) : AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: esperandoDemais ? AppColors.danger : cor,
          width: destaque ? 4 : 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pedido.senha,
              style: AppTypography.tvSenha.copyWith(
                color: destaque ? cor : AppColors.textPrimary,
                fontSize: destaque ? 96 : 68,
              ),
            ),
          ),
          if (pedido.clienteNome != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              pedido.clienteNome!,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${pedido.qtdItens} item(ns)'
            '${esperandoDemais ? ' · ${pedido.espera.inMinutes} min' : ''}',
            style: AppTypography.bodyLarge.copyWith(
              color: esperandoDemais
                  ? AppColors.danger
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SemPedidos extends StatelessWidget {
  const _SemPedidos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.coffee_outlined,
            size: 120,
            color: AppColors.textDisabled,
          ),
          AppSpacing.gapXl,
          Text(
            'Nenhum pedido na fila',
            style: context
                .scaled(AppTypography.headlineLarge)
                .copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.gapMd,
          Text(
            'Escaneie o QR da mesa para pedir',
            style: context
                .scaled(AppTypography.bodyLarge)
                .copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

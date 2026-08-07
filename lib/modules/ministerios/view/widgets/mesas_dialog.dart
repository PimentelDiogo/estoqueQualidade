import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/ministerio.dart';
import '../../../../data/repositories/repositories.dart';
import '../../viewmodel/ministerios_viewmodel.dart';

/// Mesas do salao e seus QR de identificacao.
///
/// Cada QR aponta para `/pedido/<token>`: o cliente escaneia e cai no cardapio
/// daquela mesa. As telas de pedido chegam na Fase 2 — os QR ja podem ser
/// impressos e colados agora, porque o token nao muda.
class MesasDialog extends StatefulWidget {
  const MesasDialog({required this.ministerio, super.key});

  final Ministerio ministerio;

  @override
  State<MesasDialog> createState() => _MesasDialogState();
}

class _MesasDialogState extends State<MesasDialog> {
  final MinisteriosViewModel _vm = Get.find<MinisteriosViewModel>();
  final TextEditingController _identificador = TextEditingController();

  @override
  void dispose() {
    _identificador.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final bool ok = await _vm.criarMesa(
      ministerioId: widget.ministerio.id,
      identificador: _identificador.text,
    );
    if (ok) _identificador.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Mesas e QR', style: AppTypography.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(widget.ministerio.nome, style: AppTypography.bodySmall),
              AppSpacing.gapLg,
              Text(
                'Imprima o QR e cole na mesa. O cliente escaneia para abrir o '
                'cardapio e fazer o pedido (telas na proxima fase).',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapXl,

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: 'Nova mesa',
                      controller: _identificador,
                      hint: 'Mesa 04, Balcao...',
                      onSubmitted: (_) => _criar(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(label: 'Adicionar', onPressed: _criar),
                ],
              ),

              const Divider(height: AppSpacing.xxl),

              Obx(() {
                if (_vm.mesas.isEmpty) {
                  return Text(
                    'Nenhuma mesa cadastrada.',
                    style: AppTypography.bodySmall,
                  );
                }

                return Column(
                  children: <Widget>[
                    for (final Mesa m in _vm.mesas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _CardMesa(mesa: m),
                      ),
                  ],
                );
              }),

              AppSpacing.gapLg,
              AppButton(
                label: 'Fechar',
                variant: AppButtonVariant.ghost,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMesa extends StatelessWidget {
  const _CardMesa({required this.mesa});

  final Mesa mesa;

  /// URL absoluta impressa no QR. Usa a origem atual para funcionar tanto em
  /// localhost quanto no dominio de producao, sem configuracao extra.
  String get _url {
    final Uri base = Uri.base;
    return '${base.scheme}://${base.authority}'
        '/#${Rotas.pedidoClienteCom(mesa.qrToken)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.brSm,
            ),
            child: QrImageView(
              data: _url,
              size: 88,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(mesa.identificador, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  _url,
                  style: AppTypography.bodySmall.copyWith(fontSize: 10),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

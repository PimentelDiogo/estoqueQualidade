import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../data/models/venda.dart';

/// Comprovante na tela apos a venda.
///
/// Nao imprime: o Espaco Cafe nao tem impressora. O objetivo e (1) confirmar ao
/// voluntario que a venda entrou e (2) permitir conferir o troco com o cliente
/// ainda no balcao.
class ComprovanteDialog extends StatelessWidget {
  const ComprovanteDialog({required this.venda, super.key});

  final Venda venda;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Center(
                child: Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: AppColors.success,
                ),
              ),
              AppSpacing.gapMd,
              Text(
                'Venda registrada',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Datas.dataHora(venda.criadoEm),
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),

              const Divider(height: AppSpacing.xxl),

              for (final VendaItem item in venda.itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${item.quantidade}x',
                          style: AppTypography.money,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.produtoNome,
                          style: AppTypography.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MoneyText(item.subtotal),
                    ],
                  ),
                ),

              const Divider(height: AppSpacing.xl),

              if (venda.desconto > 0) ...<Widget>[
                MoneyLabelValue(label: 'Subtotal', value: venda.subtotalBruto),
                const SizedBox(height: AppSpacing.xs),
                MoneyLabelValue(
                  label: 'Desconto',
                  value: -venda.desconto,
                  valueColor: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              MoneyLabelValue(
                label: 'Total',
                value: venda.valorTotal,
                emphasis: true,
                valueColor: AppColors.success,
              ),

              AppSpacing.gapLg,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(venda.tipo.icone, size: 18, color: venda.tipo.cor),
                  AppSpacing.gapSm,
                  Text(
                    venda.tipo.label,
                    style: AppTypography.titleMedium.copyWith(
                      color: venda.tipo.cor,
                    ),
                  ),
                ],
              ),

              AppSpacing.gapXl,
              AppButton(
                label: 'Proxima venda',
                icon: Icons.arrow_forward,
                size: AppButtonSize.large,
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

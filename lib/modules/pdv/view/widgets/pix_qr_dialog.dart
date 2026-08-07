import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../data/models/ministerio.dart';

/// QR Pix do ministerio, em tela cheia, para o cliente escanear.
///
/// ⚠️ O QR e **estatico** e nao carrega o valor: o cliente digita o valor no app
/// do banco. Nao ha confirmacao automatica de pagamento (ADR-005) — exigiria um
/// PSP com webhook e conta PJ. O caixa confere o comprovante do cliente e so
/// entao finaliza a venda. Por isso o dialogo diz isso explicitamente, em vez de
/// dar a entender que o sistema "recebeu" o dinheiro.
class PixQrDialog extends StatelessWidget {
  const PixQrDialog({required this.ministerio, required this.valor, super.key});

  final Ministerio ministerio;
  final double valor;

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
              Text(
                'Pagar com Pix',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ministerio.nome,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,

              Center(child: MoneyText(valor, large: true)),
              AppSpacing.gapLg,

              // Fundo branco obrigatorio: leitor de QR precisa do contraste, e
              // o app inteiro e dark.
              Center(child: _QrOuImagem(ministerio: ministerio)),

              AppSpacing.gapLg,
              if (ministerio.pixChave?.isNotEmpty ?? false) ...<Widget>[
                Text('Chave Pix', style: AppTypography.label),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  ministerio.pixChave!,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (ministerio.pixPayloadQr?.isNotEmpty ?? false)
                AppButton(
                  label: 'Copiar codigo Pix',
                  icon: Icons.copy_all_outlined,
                  variant: AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: ministerio.pixPayloadQr!),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Codigo Pix copiado.')),
                    );
                  },
                ),

              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'Confira o comprovante do cliente antes de finalizar. '
                        'O sistema nao confirma o pagamento automaticamente.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

class _QrOuImagem extends StatelessWidget {
  const _QrOuImagem({required this.ministerio});

  final Ministerio ministerio;

  @override
  Widget build(BuildContext context) {
    const double lado = 240;

    if (ministerio.pixPayloadQr?.isNotEmpty ?? false) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.brMd,
        ),
        child: QrImageView(
          data: ministerio.pixPayloadQr!,
          size: lado,
          backgroundColor: Colors.white,
          // Q: tolera ~25% de dano/reflexo — o celular do cliente le o QR na
          // tela de outro celular, muitas vezes com brilho baixo.
          errorCorrectionLevel: QrErrorCorrectLevel.Q,
        ),
      );
    }

    if (ministerio.pixQrImageUrl?.isNotEmpty ?? false) {
      return ClipRRect(
        borderRadius: AppRadius.brMd,
        child: Image.network(
          ministerio.pixQrImageUrl!,
          width: lado,
          height: lado,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext ctx, Object err, StackTrace? st) =>
              const _SemQr(),
        ),
      );
    }

    return const _SemQr();
  }
}

class _SemQr extends StatelessWidget {
  const _SemQr();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.qr_code_2_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          AppSpacing.gapMd,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'QR Pix nao cadastrado para este ministerio.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

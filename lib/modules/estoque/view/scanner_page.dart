import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

/// Leitor de codigo de barras pela camera.
///
/// No Flutter Web isto usa `getUserMedia`, que **exige HTTPS** (ou localhost).
/// Servido por HTTP em rede local, o navegador nega a camera sem explicacao —
/// por isso a tela sempre oferece a digitacao manual como saida.
///
/// Devolve o codigo lido via `Get.back(result: codigo)`.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    // Formatos usados no varejo brasileiro. Restringir acelera a deteccao.
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );

  final TextEditingController _manual = TextEditingController();

  /// Trava contra leitura repetida: a camera dispara varios frames com o mesmo
  /// codigo e sem isto o produto entraria varias vezes no carrinho.
  bool _jaLeu = false;

  bool _falhouCamera = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _devolver(String codigo) {
    if (_jaLeu) return;
    _jaLeu = true;
    Get.back<String>(result: codigo.trim());
  }

  void _aoDetectar(BarcodeCapture captura) {
    final String? valor = captura.barcodes
        .map((Barcode b) => b.rawValue)
        .firstWhere(
          (String? v) => v != null && v.isNotEmpty,
          orElse: () => null,
        );

    if (valor != null) _devolver(valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ler codigo de barras'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Lanterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _controller.toggleTorch,
          ),
          IconButton(
            tooltip: 'Trocar camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _falhouCamera
                ? const _CameraIndisponivel()
                : Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      MobileScanner(
                        controller: _controller,
                        onDetect: _aoDetectar,
                        errorBuilder: (BuildContext ctx, MobileScannerException e) {
                          // setState fora do build: o errorBuilder roda durante
                          // a construcao do frame.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _falhouCamera = true);
                            }
                          });
                          return const _CameraIndisponivel();
                        },
                      ),
                      const _Mira(),
                    ],
                  ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTextField(
                    label: 'Ou digite o codigo',
                    hint: '7891000100103',
                    controller: _manual,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.keyboard_outlined,
                    onSubmitted: _devolver,
                  ),
                  AppSpacing.gapMd,
                  AppButton(
                    label: 'Usar este codigo',
                    icon: Icons.check,
                    expanded: true,
                    onPressed: () {
                      if (_manual.text.trim().isEmpty) return;
                      _devolver(_manual.text);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mira extends StatelessWidget {
  const _Mira();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.brandRose, width: 3),
          borderRadius: AppRadius.brMd,
        ),
      ),
    );
  }
}

class _CameraIndisponivel extends StatelessWidget {
  const _CameraIndisponivel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.videocam_off_outlined,
                size: 56,
                color: AppColors.textDisabled,
              ),
              AppSpacing.gapLg,
              Text(
                'Camera indisponivel',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                'O navegador so libera a camera em HTTPS. '
                'Digite o codigo no campo abaixo.',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

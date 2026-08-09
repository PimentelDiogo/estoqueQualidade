import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

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

/// Status da permissao da camera.
enum _PermissaoCamera { verificando, concedida, negada, bloqueada }

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

  _PermissaoCamera _permissao = _PermissaoCamera.verificando;

  /// Mensagem de erro contextual para ajudar o usuario.
  String _mensagemErro = '';

  @override
  void initState() {
    super.initState();
    _verificarPermissao();
  }

  /// Solicita acesso a camera via `getUserMedia` antes do MobileScanner iniciar.
  /// Isso garante que o prompt do navegador apareca para o usuario.
  Future<void> _verificarPermissao() async {
    try {
      // Verifica se estamos em contexto seguro (HTTPS ou localhost real).
      final bool contextoSeguro = web.window.isSecureContext;

      if (!contextoSeguro) {
        if (mounted) {
          setState(() {
            _permissao = _PermissaoCamera.bloqueada;
            _mensagemErro =
                'A camera so funciona em HTTPS ou localhost.\n'
                'Voce esta acessando por HTTP — o navegador bloqueia '
                'a camera por seguranca.\n\n'
                'Use o campo abaixo para digitar o codigo manualmente.';
          });
        }
        return;
      }

      // Solicita acesso: isso dispara o prompt de "Permitir camera?" no celular.
      final web.MediaStream stream = await web
          .window
          .navigator
          .mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(video: true.toJS),
          )
          .toDart;

      // Permissao concedida. Encerra o stream de teste (o MobileScanner
      // abrira o seu proprio).
      for (final web.MediaStreamTrack track in stream.getTracks().toDart) {
        track.stop();
      }

      if (mounted) {
        setState(() => _permissao = _PermissaoCamera.concedida);
      }
    } catch (e) {
      if (mounted) {
        final String erro = e.toString().toLowerCase();
        final bool negadoPeloUsuario = erro.contains('notallowederror') ||
            erro.contains('permission denied') ||
            erro.contains('permissiondeniederror');

        setState(() {
          if (negadoPeloUsuario) {
            _permissao = _PermissaoCamera.negada;
            _mensagemErro =
                'Voce negou o acesso a camera.\n\n'
                'Para liberar, toque no icone de cadeado/info '
                'na barra de endereco do navegador e ative a permissao '
                'da camera. Depois volte aqui.';
          } else {
            _permissao = _PermissaoCamera.bloqueada;
            _mensagemErro =
                'Nao foi possivel acessar a camera.\n'
                'Verifique se outro app esta usando a camera ou '
                'se o navegador tem permissao no sistema.\n\n'
                'Use o campo abaixo para digitar o codigo manualmente.';
          }
        });
      }
    }
  }

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
          if (_permissao == _PermissaoCamera.concedida && !_falhouCamera) ...<Widget>[
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
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: _buildAreaCamera()),
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

  Widget _buildAreaCamera() {
    switch (_permissao) {
      case _PermissaoCamera.verificando:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.lg),
              Text('Solicitando acesso a camera...'),
            ],
          ),
        );

      case _PermissaoCamera.negada:
        return _CameraIndisponivel(
          icone: Icons.no_photography_outlined,
          titulo: 'Permissao negada',
          mensagem: _mensagemErro,
          mostrarBotaoTentar: true,
          onTentar: _verificarPermissao,
        );

      case _PermissaoCamera.bloqueada:
        return _CameraIndisponivel(
          icone: Icons.videocam_off_outlined,
          titulo: 'Camera indisponivel',
          mensagem: _mensagemErro,
          mostrarBotaoTentar: false,
        );

      case _PermissaoCamera.concedida:
        if (_falhouCamera) {
          return _CameraIndisponivel(
            icone: Icons.videocam_off_outlined,
            titulo: 'Erro ao abrir a camera',
            mensagem: 'A camera abriu mas encontrou um erro.\n'
                'Tente fechar outros apps que usam a camera '
                'e volte aqui.',
            mostrarBotaoTentar: true,
            onTentar: () {
              setState(() => _falhouCamera = false);
              _verificarPermissao();
            },
          );
        }

        return Stack(
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
                return const SizedBox.shrink();
              },
            ),
            const _Mira(),
          ],
        );
    }
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
  const _CameraIndisponivel({
    required this.icone,
    required this.titulo,
    required this.mensagem,
    required this.mostrarBotaoTentar,
    this.onTentar,
  });

  final IconData icone;
  final String titulo;
  final String mensagem;
  final bool mostrarBotaoTentar;
  final VoidCallback? onTentar;

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
              Icon(icone, size: 56, color: AppColors.textDisabled),
              AppSpacing.gapLg,
              Text(
                titulo,
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                mensagem,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (mostrarBotaoTentar) ...<Widget>[
                AppSpacing.gapLg,
                AppButton(
                  label: 'Tentar novamente',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: onTentar,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


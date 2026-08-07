import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/ministerio.dart';
import '../../viewmodel/ministerios_viewmodel.dart';

/// Cadastro/edicao de ministerio, incluindo o **QR Pix de recebimento** e o
/// e-mail que recebe os avisos de estoque baixo.
class MinisterioFormDialog extends StatefulWidget {
  const MinisterioFormDialog({super.key, this.ministerio});

  final Ministerio? ministerio;

  @override
  State<MinisterioFormDialog> createState() => _MinisterioFormDialogState();
}

class _MinisterioFormDialogState extends State<MinisterioFormDialog> {
  final MinisteriosViewModel _vm = Get.find<MinisteriosViewModel>();

  late final TextEditingController _nome;
  late final TextEditingController _responsavel;
  late final TextEditingController _email;
  late final TextEditingController _pixChave;
  late final TextEditingController _pixPayload;

  late bool _ativo;
  String? _erroNome;
  String? _erroEmail;

  bool get _novo => widget.ministerio == null;

  @override
  void initState() {
    super.initState();
    final Ministerio? m = widget.ministerio;

    _nome = TextEditingController(text: m?.nome ?? '');
    _responsavel = TextEditingController(text: m?.responsavelNome ?? '');
    _email = TextEditingController(text: m?.responsavelEmail ?? '');
    _pixChave = TextEditingController(text: m?.pixChave ?? '');
    _pixPayload = TextEditingController(text: m?.pixPayloadQr ?? '');
    _ativo = m?.ativo ?? true;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nome,
      _responsavel,
      _email,
      _pixChave,
      _pixPayload,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _erroNome = _nome.text.trim().isEmpty ? 'Informe o nome' : null;

      final String e = _email.text.trim();
      _erroEmail = e.isNotEmpty && (!e.contains('@') || !e.contains('.'))
          ? 'E-mail invalido'
          : null;
    });
    return _erroNome == null && _erroEmail == null;
  }

  Future<void> _salvar() async {
    if (!_validar()) return;

    final String nome = _nome.text.trim();

    final Ministerio m = Ministerio(
      id: widget.ministerio?.id ?? '',
      nome: nome,
      // Slug so e gerado na criacao: mudar depois quebraria links ja impressos.
      slug: widget.ministerio?.slug ?? Ministerio.gerarSlug(nome),
      responsavelNome: _responsavel.text.trim().isEmpty
          ? null
          : _responsavel.text.trim(),
      responsavelEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
      pixChave: _pixChave.text.trim().isEmpty ? null : _pixChave.text.trim(),
      pixPayloadQr: _pixPayload.text.trim().isEmpty
          ? null
          : _pixPayload.text.trim(),
      pixQrImageUrl: widget.ministerio?.pixQrImageUrl,
      ativo: _ativo,
    );

    final bool ok = await _vm.salvar(m, novo: _novo);
    if (ok && mounted) Navigator.of(context).pop();
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
              Text(
                _novo ? 'Novo ministerio' : 'Editar ministerio',
                style: AppTypography.headlineMedium,
              ),
              AppSpacing.gapXl,

              AppTextField(
                label: 'Nome',
                controller: _nome,
                hint: 'Espaco Cafe',
                errorText: _erroNome,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              if (_novo) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Identificador: ${Ministerio.gerarSlug(_nome.text)}',
                  style: AppTypography.bodySmall,
                ),
              ],
              AppSpacing.gapLg,

              AppTextField(
                label: 'Responsavel',
                controller: _responsavel,
                hint: 'Nome de quem cuida do ministerio',
              ),
              AppSpacing.gapLg,

              AppTextField(
                label: 'E-mail do responsavel',
                controller: _email,
                hint: 'responsavel@paeslagoa.org',
                keyboardType: TextInputType.emailAddress,
                errorText: _erroEmail,
                helper: 'Recebe o aviso quando um produto esta acabando',
                prefixIcon: Icons.mail_outline,
              ),

              const Divider(height: AppSpacing.xxl),
              Text('Recebimento por Pix', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'O QR e estatico e nao leva o valor: o cliente digita no app do '
                'banco. O sistema nao confirma o pagamento automaticamente.',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapLg,

              AppTextField(
                label: 'Chave Pix',
                controller: _pixChave,
                hint: 'cafe@paeslagoa.org, CNPJ, telefone...',
                prefixIcon: Icons.key_outlined,
              ),
              AppSpacing.gapLg,

              AppTextField(
                label: 'Codigo Pix copia-e-cola (BR Code)',
                controller: _pixPayload,
                hint: '00020126...',
                maxLines: 3,
                helper:
                    'Cole aqui o codigo gerado pelo app do banco. E ele que '
                    'vira o QR na tela do caixa.',
              ),

              const Divider(height: AppSpacing.xxl),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _ativo,
                onChanged: (bool v) => setState(() => _ativo = v),
                title: Text('Ativo', style: AppTypography.titleMedium),
                subtitle: Text(
                  'Inativo some das telas de venda',
                  style: AppTypography.bodySmall,
                ),
              ),

              AppSpacing.gapLg,
              Obx(() {
                final falha = _vm.falha.value;
                if (falha == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    falha.mensagem,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                );
              }),

              Obx(
                () => AppButton(
                  label: 'Salvar',
                  icon: Icons.save_outlined,
                  size: AppButtonSize.large,
                  expanded: true,
                  loading: _vm.salvando.value,
                  onPressed: _salvar,
                ),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Cancelar',
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

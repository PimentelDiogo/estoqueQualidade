import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../viewmodel/login_viewmodel.dart';

class LoginPage extends GetView<LoginViewModel> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              // O login nao ganha nada em ficar largo — 420 e confortavel do
              // celular a TV.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _Marca(),
                  AppSpacing.gapXxl,
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text('Entrar', style: AppTypography.headlineMedium),
                        AppSpacing.gapXl,
                        _CampoEmail(controller: controller),
                        AppSpacing.gapLg,
                        _CampoSenha(controller: controller),
                        AppSpacing.gapLg,
                        const _Mensagens(),
                        AppSpacing.gapSm,
                        Obx(
                          () => AppButton(
                            label: 'Entrar',
                            icon: Icons.login,
                            size: AppButtonSize.large,
                            expanded: true,
                            loading: controller.carregando.value,
                            onPressed: controller.entrar,
                          ),
                        ),
                        AppSpacing.gapSm,
                        Obx(
                          () => AppButton(
                            label: 'Esqueci minha senha',
                            variant: AppButtonVariant.ghost,
                            expanded: true,
                            onPressed: controller.carregando.value
                                ? null
                                : controller.recuperarSenha,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapXl,
                  Text(
                    'Acesso liberado por um administrador.',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
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

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.brandBlack,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandCream, width: 2),
          ),
          child: const Icon(
            Icons.coffee_outlined,
            size: 44,
            color: AppColors.brandCream,
          ),
        ),
        AppSpacing.gapLg,
        Text(
          'Espaco Cafe',
          style: context.scaled(AppTypography.headlineLarge),
          textAlign: TextAlign.center,
        ),
        Text(
          'PAES Lagoa',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _CampoEmail extends StatelessWidget {
  const _CampoEmail({required this.controller});

  final LoginViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppTextField(
        label: 'E-mail',
        hint: 'voce@exemplo.org',
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enabled: !controller.carregando.value,
        errorText: controller.erroEmail.value,
        onChanged: controller.aoDigitarEmail,
      ),
    );
  }
}

class _CampoSenha extends StatelessWidget {
  const _CampoSenha({required this.controller});

  final LoginViewModel controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppTextField(
        label: 'Senha',
        prefixIcon: Icons.lock_outline,
        obscureText: controller.ocultarSenha.value,
        textInputAction: TextInputAction.done,
        enabled: !controller.carregando.value,
        errorText: controller.erroSenha.value,
        onChanged: controller.aoDigitarSenha,
        // Enter no teclado ja envia: o voluntario nao precisa mirar no botao.
        onSubmitted: (_) => controller.entrar(),
        suffix: IconButton(
          icon: Icon(
            controller.ocultarSenha.value
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: controller.alternarVisibilidadeSenha,
          tooltip: controller.ocultarSenha.value
              ? 'Mostrar senha'
              : 'Ocultar senha',
        ),
      ),
    );
  }
}

class _Mensagens extends GetView<LoginViewModel> {
  const _Mensagens();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String? erro = controller.erro.value;
      final String? sucesso = controller.mensagemSucesso.value;

      if (erro == null && sucesso == null) return const SizedBox.shrink();

      final bool isErro = erro != null;
      final Color cor = isErro ? AppColors.danger : AppColors.success;

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: AppRadius.brMd,
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isErro ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: cor,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                erro ?? sucesso!,
                style: AppTypography.bodySmall.copyWith(color: cor),
              ),
            ),
          ],
        ),
      );
    });
  }
}

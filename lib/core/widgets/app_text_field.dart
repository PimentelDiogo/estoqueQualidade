import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/money_formatter.dart';

/// Campo de texto padrao. Sempre com label acima (nao floating): o voluntario
/// precisa saber o que e o campo mesmo depois de preencher.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// Campo de dinheiro com mascara da direita para a esquerda.
  /// Ver [MoneyInputFormatter] — evita o caixa digitar `1000` e registrar R$ 1.000.
  factory AppTextField.money({
    required String label,
    Key? key,
    TextEditingController? controller,
    String? helper,
    String? errorText,
    bool enabled = true,
    bool autofocus = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) => AppTextField(
    key: key,
    label: label,
    controller: controller,
    hint: '0,00',
    helper: helper,
    errorText: errorText,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: const <TextInputFormatter>[MoneyInputFormatter()],
    prefixIcon: Icons.attach_money,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );

  /// Campo de quantidade inteira (estoque).
  factory AppTextField.quantidade({
    required String label,
    Key? key,
    TextEditingController? controller,
    String? helper,
    String? errorText,
    bool enabled = true,
    bool autofocus = false,
    int max = 99999,
    ValueChanged<String>? onChanged,
  }) => AppTextField(
    key: key,
    label: label,
    controller: controller,
    hint: '0',
    helper: helper,
    errorText: errorText,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    inputFormatters: <TextInputFormatter>[QuantityInputFormatter(max: max)],
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          style: AppTypography.bodyLarge,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
            suffixIcon: suffix,
          ),
        ),
        if (helper != null && errorText == null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(helper!, style: AppTypography.bodySmall),
        ],
      ],
    );
  }
}

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatacao monetaria pt_BR. Unico lugar do app que sabe o formato de dinheiro.
///
/// Valores trafegam como [double] (reais) no Dart e `numeric(10,2)` no Postgres.
abstract final class Money {
  static final NumberFormat _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  static final NumberFormat _plain = NumberFormat('#,##0.00', 'pt_BR');

  /// `1234.5` -> `R$ 1.234,50`
  static String format(num value) => _brl.format(value);

  /// `1234.5` -> `1.234,50` (sem simbolo — para tabelas e CSV visual)
  static String plain(num value) => _plain.format(value);

  /// Compacto para cards de relatorio: `1234.5` -> `R$ 1,2 mil`
  static String compact(num value) => NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 1,
  ).format(value);

  /// Le o que o usuario digitou (`1.234,50` ou `1234,50` ou `1234.50`).
  /// Retorna `null` se nao for um numero valido — o chamador decide a mensagem.
  static double? parse(String input) {
    final String cleaned = input
        .replaceAll(RegExp(r'[^\d,.\-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}

/// Mascara de entrada de dinheiro: o usuario digita so digitos e o valor
/// vai preenchendo da direita para a esquerda (`5` -> `0,05` -> `0,50`...).
///
/// Isso evita o erro classico do caixa com pressa de digitar `1000` querendo
/// `10,00` e registrar mil reais.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Limite defensivo: nenhuma venda do cafe chega perto disso.
    final String capped = digits.length > 9 ? digits.substring(0, 9) : digits;

    final double value = int.parse(capped) / 100;
    final String text = Money.plain(value);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Entrada de quantidade inteira (estoque). So digitos, sem zeros a esquerda.
class QuantityInputFormatter extends TextInputFormatter {
  const QuantityInputFormatter({this.max = 99999});

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final int parsed = int.tryParse(digits) ?? 0;
    final String text = (parsed > max ? max : parsed).toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

import 'package:espaco_cafe/core/utils/date_range.dart';
import 'package:espaco_cafe/core/utils/money_formatter.dart';
import 'package:espaco_cafe/data/models/ministerio.dart';
import 'package:espaco_cafe/data/models/produto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Money', () {
    test('formata em pt_BR', () {
      expect(Money.format(1234.5), contains('1.234,50'));
      expect(Money.plain(1234.5), '1.234,50');
    });

    test('parse aceita os formatos que o usuario digita', () {
      expect(Money.parse('1.234,50'), 1234.5);
      expect(Money.parse('1234,50'), 1234.5);
      expect(Money.parse(r'R$ 12,00'), 12);
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
    });
  });

  group('MoneyInputFormatter', () {
    /// Este formatter existe para impedir o erro mais caro do caixa: digitar
    /// `1000` querendo R$ 10,00 e registrar mil reais.
    String digitar(String texto) {
      const MoneyInputFormatter f = MoneyInputFormatter();
      return f
          .formatEditUpdate(
            const TextEditingValue(),
            TextEditingValue(text: texto),
          )
          .text;
    }

    test('preenche da direita para a esquerda', () {
      expect(digitar('5'), '0,05');
      expect(digitar('50'), '0,50');
      expect(digitar('500'), '5,00');
      expect(digitar('1000'), '10,00');
      expect(digitar('123456'), '1.234,56');
    });

    test('ignora caracteres nao numericos', () {
      expect(digitar(r'R$ 1a0b0c0'), '10,00');
    });

    test('campo vazio continua vazio', () {
      expect(digitar(''), '');
    });
  });

  group('DateRange', () {
    test('dia vai de 00:00 ate 00:00 do dia seguinte', () {
      final DateRange r = DateRange.doPeriodo(
        Periodo.dia,
        referencia: DateTime(2026, 8, 7, 15, 30),
      );

      expect(r.inicio, DateTime(2026, 8, 7));
      expect(r.fim, DateTime(2026, 8, 8));
    });

    test('semana comeca na segunda', () {
      // 2026-08-07 e uma sexta-feira.
      final DateRange r = DateRange.doPeriodo(
        Periodo.semana,
        referencia: DateTime(2026, 8, 7),
      );

      expect(r.inicio.weekday, DateTime.monday);
      expect(r.inicio, DateTime(2026, 8, 3));
      expect(r.fim, DateTime(2026, 8, 10));
    });

    test('mes cobre o mes inteiro, inclusive virada de ano', () {
      final DateRange r = DateRange.doPeriodo(
        Periodo.mes,
        referencia: DateTime(2026, 12, 20),
      );

      expect(r.inicio, DateTime(2026, 12));
      expect(r.fim, DateTime(2027));
    });

    /// Intervalo fechado-aberto: a venda das 23:59 tem que cair no dia certo.
    test('contem inclui o inicio e exclui o fim', () {
      final DateRange r = DateRange.doPeriodo(
        Periodo.dia,
        referencia: DateTime(2026, 8, 7),
      );

      expect(r.contem(DateTime(2026, 8, 7)), isTrue);
      expect(r.contem(DateTime(2026, 8, 7, 23, 59, 59)), isTrue);
      expect(r.contem(DateTime(2026, 8, 8)), isFalse);
    });

    test('granularidade casa com o date_trunc do Postgres', () {
      expect(Periodo.dia.granularidade, 'day');
      expect(Periodo.semana.granularidade, 'week');
      expect(Periodo.mes.granularidade, 'month');
    });
  });

  group('Ministerio.gerarSlug', () {
    test('respeita a constraint ^[a-z0-9-]+\$ do banco', () {
      expect(Ministerio.gerarSlug('Espaço Café'), 'espaco-cafe');
      expect(
        Ministerio.gerarSlug('  Ministério  de   Louvor '),
        'ministerio-de-louvor',
      );
      expect(Ministerio.gerarSlug('Café & Cia!'), 'cafe-cia');
      expect(Ministerio.gerarSlug('Grupo 12'), 'grupo-12');
    });
  });

  group('Produto', () {
    test('situacao reflete quantidade x minimo', () {
      expect(
        Produto(
          id: '1',
          ministerioId: 'm',
          nome: 'x',
          precoVenda: 1,
          quantidade: 10,
          estoqueMinimo: 5,
        ).precisaRepor,
        isFalse,
      );

      expect(
        Produto(
          id: '1',
          ministerioId: 'm',
          nome: 'x',
          precoVenda: 1,
          quantidade: 5,
          estoqueMinimo: 5,
        ).precisaRepor,
        isTrue,
        reason: 'igual ao minimo ja e alerta',
      );
    });

    test('busca ignora acento, caixa e casa com codigo de barras', () {
      final Produto p = Produto(
        id: '1',
        ministerioId: 'm',
        nome: 'Pão de Queijo',
        precoVenda: 3.5,
        codigoBarras: '7891000100103',
      );

      expect(p.combina('pao'), isTrue);
      expect(p.combina('QUEIJO'), isTrue);
      expect(p.combina('7891000'), isTrue);
      expect(p.combina(''), isTrue);
      expect(p.combina('brownie'), isFalse);
    });

    test('margem percentual nao divide por zero', () {
      final Produto gratis = Produto(
        id: '1',
        ministerioId: 'm',
        nome: 'x',
        precoVenda: 0,
      );
      expect(gratis.margemPercentual, 0);
    });
  });
}

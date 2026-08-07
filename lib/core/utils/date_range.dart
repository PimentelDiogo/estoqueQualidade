import 'package:intl/intl.dart';

/// Os tres recortes de relatorio pedidos: dia, semana e mes.
enum Periodo {
  dia('Dia'),
  semana('Semana'),
  mes('Mes');

  const Periodo(this.label);

  final String label;

  /// Chave enviada a `vw_vendas_periodo` (casa com o `date_trunc` do Postgres).
  String get granularidade => switch (this) {
    Periodo.dia => 'day',
    Periodo.semana => 'week',
    Periodo.mes => 'month',
  };
}

/// Intervalo fechado-aberto `[inicio, fim)` — evita o bug classico de perder a
/// venda das 23:59:59 quando se compara com `<= fim`.
class DateRange {
  const DateRange({required this.inicio, required this.fim});

  final DateTime inicio;
  final DateTime fim;

  /// Intervalo do periodo contendo [referencia] (padrao: agora).
  ///
  /// Semana comeca na **segunda** (padrao brasileiro/ISO).
  factory DateRange.doPeriodo(Periodo periodo, {DateTime? referencia}) {
    final DateTime base = referencia ?? DateTime.now();
    final DateTime dia = DateTime(base.year, base.month, base.day);

    return switch (periodo) {
      Periodo.dia => DateRange(
        inicio: dia,
        fim: dia.add(const Duration(days: 1)),
      ),
      Periodo.semana => () {
        final DateTime segunda = dia.subtract(
          Duration(days: dia.weekday - DateTime.monday),
        );
        return DateRange(
          inicio: segunda,
          fim: segunda.add(const Duration(days: 7)),
        );
      }(),
      Periodo.mes => DateRange(
        inicio: DateTime(base.year, base.month),
        fim: DateTime(base.year, base.month + 1),
      ),
    };
  }

  /// Ultimos [dias] dias, incluindo hoje. Usado no grafico de barras.
  factory DateRange.ultimosDias(int dias, {DateTime? referencia}) {
    final DateTime base = referencia ?? DateTime.now();
    final DateTime hoje = DateTime(base.year, base.month, base.day);
    return DateRange(
      inicio: hoje.subtract(Duration(days: dias - 1)),
      fim: hoje.add(const Duration(days: 1)),
    );
  }

  bool contem(DateTime d) => !d.isBefore(inicio) && d.isBefore(fim);

  /// Enviado ao Postgres em UTC — o banco guarda `timestamptz`.
  String get inicioIso => inicio.toUtc().toIso8601String();
  String get fimIso => fim.toUtc().toIso8601String();

  /// Rotulo humano para o cabecalho do relatorio.
  String rotulo(Periodo periodo) {
    final DateTime ultimoDia = fim.subtract(const Duration(days: 1));
    return switch (periodo) {
      Periodo.dia => DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(inicio),
      Periodo.semana =>
        '${DateFormat('d MMM', 'pt_BR').format(inicio)} - '
            '${DateFormat("d MMM 'de' y", 'pt_BR').format(ultimoDia)}',
      Periodo.mes => DateFormat("MMMM 'de' y", 'pt_BR').format(inicio),
    };
  }

  @override
  String toString() => 'DateRange($inicioIso -> $fimIso)';

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(inicio, fim);
}

/// Formatos de data usados na UI. Centralizados para nao duplicar padrao.
abstract final class Datas {
  static final DateFormat _hora = DateFormat('HH:mm', 'pt_BR');
  static final DateFormat _dataHora = DateFormat('dd/MM/yy HH:mm', 'pt_BR');
  static final DateFormat _data = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _diaCurto = DateFormat('dd/MM', 'pt_BR');

  static String hora(DateTime d) => _hora.format(d.toLocal());
  static String dataHora(DateTime d) => _dataHora.format(d.toLocal());
  static String data(DateTime d) => _data.format(d.toLocal());
  static String diaCurto(DateTime d) => _diaCurto.format(d.toLocal());
}

import 'enums.dart';

/// Uma linha do livro-razao do estoque. Nunca e apagada nem editada — auditoria
/// so faz sentido se for imutavel.
class MovimentacaoEstoque {
  const MovimentacaoEstoque({
    required this.id,
    required this.produtoId,
    required this.tipo,
    required this.quantidade,
    required this.saldoApos,
    required this.criadoEm,
    this.produtoNome,
    this.usuarioId,
    this.usuarioNome,
    this.vendaId,
    this.observacao,
  });

  final String id;
  final String produtoId;
  final String? produtoNome;
  final String? usuarioId;
  final String? usuarioNome;
  final TipoMovimentacao tipo;

  /// Positiva em entrada, negativa em saida/perda.
  final int quantidade;

  /// Saldo depois do movimento — permite auditar sem recalcular a serie.
  final int saldoApos;

  final String? vendaId;
  final String? observacao;
  final DateTime criadoEm;

  bool get isEntrada => quantidade > 0;

  /// `+12` / `-3` — como aparece no historico.
  String get quantidadeFormatada => '${quantidade > 0 ? '+' : ''}$quantidade';

  factory MovimentacaoEstoque.fromMap(Map<String, dynamic> map) {
    final Object? produto = map['produto'];
    final Object? usuario = map['usuario'];
    return MovimentacaoEstoque(
      id: map['id'] as String,
      produtoId: map['produto_id'] as String,
      produtoNome: produto is Map<String, dynamic>
          ? produto['nome'] as String?
          : null,
      usuarioId: map['usuario_id'] as String?,
      usuarioNome: usuario is Map<String, dynamic>
          ? usuario['nome'] as String?
          : null,
      tipo: TipoMovimentacao.fromDb(map['tipo'] as String),
      quantidade: map['quantidade'] as int,
      saldoApos: map['saldo_apos'] as int,
      vendaId: map['venda_id'] as String?,
      observacao: map['observacao'] as String?,
      criadoEm: DateTime.parse(map['criado_em'] as String).toLocal(),
    );
  }
}

/// Produto abaixo do minimo — a tela de Alertas e o badge do menu.
///
/// Vem de `vw_estoque_baixo`, que ja junta produto + alerta aberto.
class AlertaEstoque {
  const AlertaEstoque({
    required this.produtoId,
    required this.ministerioId,
    required this.produtoNome,
    required this.quantidade,
    required this.estoqueMinimo,
    this.alertaId,
    this.criadoEm,
    this.emailEnviadoEm,
  });

  final String produtoId;
  final String ministerioId;
  final String produtoNome;
  final int quantidade;
  final int estoqueMinimo;

  /// Nulo se o trigger ainda nao registrou (ex.: produto cadastrado ja no minimo
  /// numa versao anterior do banco). A tela funciona mesmo assim.
  final String? alertaId;

  final DateTime? criadoEm;

  /// Nulo => e-mail ainda nao saiu (cron pendente ou sem e-mail cadastrado).
  final DateTime? emailEnviadoEm;

  SituacaoEstoque get situacao =>
      SituacaoEstoque.de(quantidade: quantidade, minimo: estoqueMinimo);

  bool get esgotado => quantidade <= 0;
  bool get emailEnviado => emailEnviadoEm != null;

  /// Quanto falta para sair do vermelho.
  int get faltamParaOMinimo =>
      (estoqueMinimo - quantidade).clamp(0, estoqueMinimo);

  factory AlertaEstoque.fromMap(Map<String, dynamic> map) => AlertaEstoque(
    produtoId: map['produto_id'] as String,
    ministerioId: map['ministerio_id'] as String,
    produtoNome: map['nome'] as String,
    quantidade: map['quantidade'] as int,
    estoqueMinimo: map['estoque_minimo'] as int,
    alertaId: map['alerta_id'] as String?,
    criadoEm: map['alerta_criado_em'] == null
        ? null
        : DateTime.parse(map['alerta_criado_em'] as String).toLocal(),
    emailEnviadoEm: map['email_enviado_em'] == null
        ? null
        : DateTime.parse(map['email_enviado_em'] as String).toLocal(),
  );
}

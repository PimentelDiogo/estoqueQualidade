import 'enums.dart';

/// Produto vendido por um ministerio.
///
/// `quantidade` nunca e alterada direto pelo app: passa por
/// `fn_registrar_venda` (venda) ou `fn_movimentar_estoque` (entrada/ajuste/perda),
/// para que toda mudanca deixe rastro em `movimentacao_estoque`.
class Produto {
  const Produto({
    required this.id,
    required this.ministerioId,
    required this.nome,
    required this.precoVenda,
    this.descricao,
    this.codigoBarras,
    this.custo = 0,
    this.unidade = 'un',
    this.quantidade = 0,
    this.estoqueMinimo = 5,
    this.ativo = true,
  });

  final String id;
  final String ministerioId;
  final String nome;
  final String? descricao;

  /// EAN lido pelo scanner. Unico dentro do ministerio.
  final String? codigoBarras;

  final double precoVenda;
  final double custo;

  /// `un`, `fatia`, `kg`... so rotulo; nao entra em calculo.
  final String unidade;

  final int quantidade;

  /// Limite que dispara o alerta — a razao de o sistema existir.
  final int estoqueMinimo;

  final bool ativo;

  SituacaoEstoque get situacao =>
      SituacaoEstoque.de(quantidade: quantidade, minimo: estoqueMinimo);

  bool get disponivel => ativo && quantidade > 0;
  bool get precisaRepor => quantidade <= estoqueMinimo;

  /// Margem por unidade. Informativa — nao entra no relatorio de arrecadacao,
  /// que trabalha com o valor recebido.
  double get margem => precoVenda - custo;

  double get margemPercentual =>
      precoVenda <= 0 ? 0 : (margem / precoVenda) * 100;

  /// Valor imobilizado no estoque, a preco de custo.
  double get valorEmEstoque => custo * quantidade;

  factory Produto.fromMap(Map<String, dynamic> map) => Produto(
    id: map['id'] as String,
    ministerioId: map['ministerio_id'] as String,
    nome: map['nome'] as String,
    descricao: map['descricao'] as String?,
    codigoBarras: map['codigo_barras'] as String?,
    // numeric do Postgres chega como num (int ou double) — normalizamos.
    precoVenda: (map['preco_venda'] as num).toDouble(),
    custo: (map['custo'] as num?)?.toDouble() ?? 0,
    unidade: map['unidade'] as String? ?? 'un',
    quantidade: map['quantidade'] as int? ?? 0,
    estoqueMinimo: map['estoque_minimo'] as int? ?? 5,
    ativo: map['ativo'] as bool? ?? true,
  );

  /// `quantidade` fica de fora de proposito: estoque so muda por RPC.
  Map<String, dynamic> toUpsert() => <String, dynamic>{
    'ministerio_id': ministerioId,
    'nome': nome,
    'descricao': descricao,
    'codigo_barras': (codigoBarras?.isEmpty ?? true) ? null : codigoBarras,
    'preco_venda': precoVenda,
    'custo': custo,
    'unidade': unidade,
    'estoque_minimo': estoqueMinimo,
    'ativo': ativo,
  };

  Produto copyWith({
    String? nome,
    String? descricao,
    String? codigoBarras,
    double? precoVenda,
    double? custo,
    String? unidade,
    int? quantidade,
    int? estoqueMinimo,
    bool? ativo,
  }) => Produto(
    id: id,
    ministerioId: ministerioId,
    nome: nome ?? this.nome,
    descricao: descricao ?? this.descricao,
    codigoBarras: codigoBarras ?? this.codigoBarras,
    precoVenda: precoVenda ?? this.precoVenda,
    custo: custo ?? this.custo,
    unidade: unidade ?? this.unidade,
    quantidade: quantidade ?? this.quantidade,
    estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
    ativo: ativo ?? this.ativo,
  );

  /// Busca do PDV: nome ou codigo de barras, ignorando acento e caixa.
  bool combina(String termo) {
    if (termo.trim().isEmpty) return true;
    final String t = _normalizar(termo);
    return _normalizar(nome).contains(t) ||
        (codigoBarras?.contains(termo.trim()) ?? false);
  }

  static String _normalizar(String s) {
    const String comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const String semAcento = 'aaaaaeeeeiiiiooooouuuuc';
    String r = s.toLowerCase().trim();
    for (int i = 0; i < comAcento.length; i++) {
      r = r.replaceAll(comAcento[i], semAcento[i]);
    }
    return r;
  }

  @override
  bool operator ==(Object other) => other is Produto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

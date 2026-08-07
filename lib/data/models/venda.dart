import 'enums.dart';
import 'produto.dart';

/// Item dentro de uma venda ja registrada.
///
/// `produtoNome` e `precoUnitario` sao congelados no momento da venda: se o
/// produto for renomeado ou reprecificado depois, o historico continua verdadeiro.
class VendaItem {
  const VendaItem({
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
    this.id,
  });

  final String? id;
  final String produtoId;
  final String produtoNome;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;

  factory VendaItem.fromMap(Map<String, dynamic> map) => VendaItem(
    id: map['id'] as String?,
    produtoId: map['produto_id'] as String,
    produtoNome: map['produto_nome'] as String,
    quantidade: map['quantidade'] as int,
    precoUnitario: (map['preco_unitario'] as num).toDouble(),
    subtotal: (map['subtotal'] as num).toDouble(),
  );
}

/// Venda registrada. Criada exclusivamente por `fn_registrar_venda` (ADR-003) —
/// nao existe construtor de "nova venda" aqui de proposito.
class Venda {
  const Venda({
    required this.id,
    required this.ministerioId,
    required this.tipo,
    required this.valorTotal,
    required this.criadoEm,
    this.usuarioId,
    this.desconto = 0,
    this.observacao,
    this.itens = const <VendaItem>[],
  });

  final String id;
  final String ministerioId;
  final String? usuarioId;
  final TipoVenda tipo;
  final double valorTotal;
  final double desconto;
  final String? observacao;
  final DateTime criadoEm;
  final List<VendaItem> itens;

  int get quantidadeItens =>
      itens.fold(0, (int soma, VendaItem i) => soma + i.quantidade);

  double get subtotalBruto =>
      itens.fold(0, (double soma, VendaItem i) => soma + i.subtotal);

  factory Venda.fromMap(Map<String, dynamic> map) => Venda(
    id: map['id'] as String,
    ministerioId: map['ministerio_id'] as String,
    usuarioId: map['usuario_id'] as String?,
    tipo: TipoVenda.fromDb(map['tipo'] as String),
    valorTotal: (map['valor_total'] as num).toDouble(),
    desconto: (map['desconto'] as num?)?.toDouble() ?? 0,
    observacao: map['observacao'] as String?,
    criadoEm: DateTime.parse(map['criado_em'] as String).toLocal(),
    itens:
        (map['venda_item'] as List<dynamic>?)
            ?.map((dynamic e) => VendaItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const <VendaItem>[],
  );
}

/// Linha do carrinho **antes** de virar venda. Vive so na memoria do PDV.
///
/// Guarda o [Produto] inteiro para conseguir validar estoque na hora e mostrar
/// nome/preco sem outra consulta.
class ItemCarrinho {
  const ItemCarrinho({required this.produto, required this.quantidade});

  final Produto produto;
  final int quantidade;

  double get subtotal => produto.precoVenda * quantidade;

  /// Checagem otimista, so para dar feedback imediato na tela. A validacao que
  /// vale e a da RPC, dentro da transacao — aqui o dado pode estar velho.
  bool get temEstoque => quantidade <= produto.quantidade;

  ItemCarrinho comQuantidade(int nova) =>
      ItemCarrinho(produto: produto, quantidade: nova);

  /// Formato aceito pelo parametro `p_itens` de `fn_registrar_venda`.
  /// So id e quantidade: o preco vem do banco, nunca do cliente.
  Map<String, dynamic> toRpcItem() => <String, dynamic>{
    'produto_id': produto.id,
    'quantidade': quantidade,
  };
}

/// Resultado agregado de `fn_resumo_periodo` — os cards do topo do relatorio.
class ResumoPeriodo {
  const ResumoPeriodo({
    this.qtdVendas = 0,
    this.qtdItens = 0,
    this.valorTotal = 0,
    this.ticketMedio = 0,
    this.descontos = 0,
  });

  final int qtdVendas;
  final int qtdItens;
  final double valorTotal;
  final double ticketMedio;
  final double descontos;

  bool get vazio => qtdVendas == 0;

  factory ResumoPeriodo.fromMap(Map<String, dynamic> map) => ResumoPeriodo(
    qtdVendas: (map['qtd_vendas'] as num?)?.toInt() ?? 0,
    qtdItens: (map['qtd_itens'] as num?)?.toInt() ?? 0,
    valorTotal: (map['valor_total'] as num?)?.toDouble() ?? 0,
    ticketMedio: (map['ticket_medio'] as num?)?.toDouble() ?? 0,
    descontos: (map['descontos'] as num?)?.toDouble() ?? 0,
  );
}

/// Uma linha de `fn_vendas_periodo`: um bucket de tempo x tipo de venda.
class VendaAgregada {
  const VendaAgregada({
    required this.periodo,
    required this.tipo,
    required this.qtdVendas,
    required this.qtdItens,
    required this.valorTotal,
  });

  final DateTime periodo;
  final TipoVenda tipo;
  final int qtdVendas;
  final int qtdItens;
  final double valorTotal;

  factory VendaAgregada.fromMap(Map<String, dynamic> map) => VendaAgregada(
    periodo: DateTime.parse(map['periodo'] as String).toLocal(),
    tipo: TipoVenda.fromDb(map['tipo'] as String),
    qtdVendas: (map['qtd_vendas'] as num?)?.toInt() ?? 0,
    qtdItens: (map['qtd_itens'] as num?)?.toInt() ?? 0,
    valorTotal: (map['valor_total'] as num?)?.toDouble() ?? 0,
  );
}

/// Linha de `fn_produtos_mais_vendidos` — guia a reposicao.
class ProdutoMaisVendido {
  const ProdutoMaisVendido({
    required this.produtoId,
    required this.produtoNome,
    required this.qtdVendida,
    required this.valorTotal,
  });

  final String produtoId;
  final String produtoNome;
  final int qtdVendida;
  final double valorTotal;

  factory ProdutoMaisVendido.fromMap(Map<String, dynamic> map) =>
      ProdutoMaisVendido(
        produtoId: map['produto_id'] as String,
        produtoNome: map['produto_nome'] as String,
        qtdVendida: (map['qtd_vendida'] as num?)?.toInt() ?? 0,
        valorTotal: (map['valor_total'] as num?)?.toDouble() ?? 0,
      );
}

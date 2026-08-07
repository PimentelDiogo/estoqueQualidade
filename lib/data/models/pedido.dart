import 'enums.dart';

/// Item de um pedido. Preço congelado no momento do pedido, igual a `venda_item`.
class PedidoItem {
  const PedidoItem({
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
    this.id,
  });

  final String? id;
  final String produtoId;
  final String produtoNome;
  final int quantidade;
  final double precoUnitario;

  double get subtotal => precoUnitario * quantidade;

  factory PedidoItem.fromMap(Map<String, dynamic> map) => PedidoItem(
    id: map['id'] as String?,
    produtoId: map['produto_id'] as String,
    produtoNome: map['produto_nome'] as String,
    quantidade: map['quantidade'] as int,
    precoUnitario: (map['preco_unitario'] as num).toDouble(),
  );
}

/// Pedido feito pelo cliente via QR da mesa.
///
/// **Não movimenta estoque.** A baixa só acontece quando o caixa converte em
/// venda — senão um pedido abandonado no salão seguraria estoque para sempre.
class Pedido {
  const Pedido({
    required this.id,
    required this.ministerioId,
    required this.senha,
    required this.status,
    required this.criadoEm,
    this.mesaId,
    this.mesaIdentificador,
    this.clienteNome,
    this.observacao,
    this.vendaId,
    this.itens = const <PedidoItem>[],
    this.qtdItens = 0,
  });

  final String id;
  final String ministerioId;

  /// Número curto do dia — é o que aparece gigante na TV.
  final String senha;

  final StatusPedido status;
  final String? mesaId;
  final String? mesaIdentificador;
  final String? clienteNome;
  final String? observacao;

  /// Preenchido quando o caixa cobra o pedido.
  final String? vendaId;

  final List<PedidoItem> itens;

  /// Vem agregado de `fn_fila_tv` (a TV não carrega os itens completos).
  final int qtdItens;

  final DateTime criadoEm;

  bool get cobrado => vendaId != null;
  bool get naFila => status.naFila;

  double get total => itens.fold(0, (double s, PedidoItem i) => s + i.subtotal);

  int get quantidadeTotal => itens.isEmpty
      ? qtdItens
      : itens.fold(0, (int s, PedidoItem i) => s + i.quantidade);

  /// Há quanto tempo o pedido está esperando — vira alerta visual na TV.
  Duration get espera => DateTime.now().difference(criadoEm);

  /// Próximo passo natural do fluxo. `null` = fim da linha.
  StatusPedido? get proximoStatus => switch (status) {
    StatusPedido.recebido => StatusPedido.preparando,
    StatusPedido.preparando => StatusPedido.pronto,
    StatusPedido.pronto => StatusPedido.entregue,
    _ => null,
  };

  factory Pedido.fromMap(Map<String, dynamic> map) {
    final Object? mesa = map['mesa'];
    return Pedido(
      id: (map['id'] ?? map['pedido_id']) as String,
      ministerioId: map['ministerio_id'] as String,
      senha: map['senha'] as String,
      status: StatusPedido.fromDb(map['status'] as String),
      mesaId: map['mesa_id'] as String?,
      mesaIdentificador: mesa is Map<String, dynamic>
          ? mesa['identificador'] as String?
          : null,
      clienteNome: map['cliente_nome'] as String?,
      observacao: map['observacao'] as String?,
      vendaId: map['venda_id'] as String?,
      qtdItens: (map['qtd_itens'] as num?)?.toInt() ?? 0,
      itens:
          (map['pedido_item'] as List<dynamic>?)
              ?.map(
                (dynamic e) => PedidoItem.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          const <PedidoItem>[],
      criadoEm: DateTime.parse(map['criado_em'] as String).toLocal(),
    );
  }
}

/// Linha do carrinho do cliente, antes de virar pedido.
class ItemPedidoCliente {
  const ItemPedidoCliente({
    required this.produtoId,
    required this.nome,
    required this.preco,
    required this.quantidade,
  });

  final String produtoId;
  final String nome;
  final double preco;
  final int quantidade;

  double get subtotal => preco * quantidade;

  ItemPedidoCliente comQuantidade(int nova) => ItemPedidoCliente(
    produtoId: produtoId,
    nome: nome,
    preco: preco,
    quantidade: nova,
  );

  /// Formato de `p_itens` da RPC. Só id e quantidade — o preço vem do banco.
  Map<String, dynamic> toRpcItem() => <String, dynamic>{
    'produto_id': produtoId,
    'quantidade': quantidade,
  };
}

/// Item do cardápio público (`vw_cardapio`). Sem custo nem estoque.
class ItemCardapio {
  const ItemCardapio({
    required this.id,
    required this.ministerioId,
    required this.nome,
    required this.preco,
    required this.disponivel,
    this.descricao,
  });

  final String id;
  final String ministerioId;
  final String nome;
  final String? descricao;
  final double preco;
  final bool disponivel;

  factory ItemCardapio.fromMap(Map<String, dynamic> map) => ItemCardapio(
    id: map['id'] as String,
    ministerioId: map['ministerio_id'] as String,
    nome: map['nome'] as String,
    descricao: map['descricao'] as String?,
    preco: (map['preco_venda'] as num).toDouble(),
    disponivel: map['disponivel'] as bool? ?? true,
  );
}

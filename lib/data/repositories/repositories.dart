import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../models/enums.dart';
import '../models/estoque.dart';
import '../models/ministerio.dart';
import '../models/pedido.dart';
import '../models/perfil_usuario.dart';
import '../models/produto.dart';
import '../models/venda.dart';

/// Contratos dos repositories.
///
/// As ViewModels dependem **apenas** destas interfaces (regra 2 do CLAUDE.md).
/// E isso que permite testar ViewModel sem rede: basta um fake implementando
/// a interface.

abstract interface class MinisterioRepository {
  Future<Result<List<Ministerio>>> listar({bool apenasAtivos = true});

  Future<Result<Ministerio>> porId(String id);

  Future<Result<Ministerio>> criar(Ministerio ministerio);

  Future<Result<Ministerio>> atualizar(Ministerio ministerio);

  /// Sobe a imagem do QR PIX para o Storage e devolve a URL publica.
  /// Usado por quem so tem a foto do QR, sem o payload copia-e-cola.
  Future<Result<String>> enviarImagemQrPix({
    required String ministerioId,
    required List<int> bytes,
    required String extensao,
  });

  Future<Result<List<Mesa>>> listarMesas(String ministerioId);

  Future<Result<Mesa>> criarMesa({
    required String ministerioId,
    required String identificador,
  });
}

abstract interface class ProdutoRepository {
  Future<Result<List<Produto>>> listar({
    required String ministerioId,
    bool apenasAtivos = true,
  });

  Future<Result<Produto?>> porCodigoBarras({
    required String ministerioId,
    required String codigo,
  });

  Future<Result<Produto>> criar(Produto produto);

  Future<Result<Produto>> atualizar(Produto produto);

  /// Desativa em vez de apagar: produto apagado levaria o historico de venda
  /// junto. Inativo some das telas e continua no relatorio.
  Future<Result<void>> desativar(String produtoId);

  /// Entrada, ajuste ou perda. Retorna o novo saldo.
  /// Saida por venda NAO passa por aqui — e da RPC de venda.
  Future<Result<int>> movimentarEstoque({
    required String produtoId,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  });

  Future<Result<List<MovimentacaoEstoque>>> historicoMovimentacoes({
    required String produtoId,
    int limite = 50,
  });
}

abstract interface class VendaRepository {
  /// Registra a venda pela RPC transacional. Retorna o id da venda criada.
  ///
  /// Os precos vem do banco: [itens] leva apenas produto e quantidade.
  Future<Result<String>> registrar({
    required String ministerioId,
    required TipoVenda tipo,
    required List<ItemCarrinho> itens,
    double desconto = 0,
    String? observacao,
  });

  Future<Result<Venda>> porId(String vendaId);

  /// Vendas do turno — o caixa confere no fim do culto.
  Future<Result<List<Venda>>> listar({
    required String ministerioId,
    required DateRange periodo,
    int limite = 100,
  });
}

abstract interface class RelatorioRepository {
  Future<Result<ResumoPeriodo>> resumo({
    required String ministerioId,
    required DateRange periodo,
  });

  Future<Result<List<VendaAgregada>>> serie({
    required String ministerioId,
    required Periodo granularidade,
    required DateRange periodo,
  });

  Future<Result<List<ProdutoMaisVendido>>> maisVendidos({
    required String ministerioId,
    required DateRange periodo,
    int limite = 10,
  });
}

abstract interface class AlertaRepository {
  Future<Result<List<AlertaEstoque>>> listar(String ministerioId);

  /// Marca como resolvido manualmente ("ja repus, pode fechar").
  /// A reposicao pelo estoque tambem resolve sozinha, via trigger.
  Future<Result<void>> resolver(String alertaId);
}

/// Retorno de `fn_criar_pedido`: o cliente precisa da senha para acompanhar.
class PedidoCriado {
  const PedidoCriado({required this.id, required this.senha});

  final String id;
  final String senha;
}

/// Pedidos (Fase 2) — cliente anônimo e gestão da fila pelo caixa.
abstract interface class PedidoRepository {
  /// Cardápio público da mesa. Vem de `vw_cardapio`: nome, descrição, preço e
  /// disponibilidade — **nunca** custo nem quantidade em estoque.
  Future<Result<List<ItemCardapio>>> cardapio(String qrToken);

  /// Cria o pedido pela RPC. O preço vem do banco, não do cliente.
  Future<Result<PedidoCriado>> criar({
    required String qrToken,
    required List<ItemPedidoCliente> itens,
    String? clienteNome,
    String? observacao,
  });

  /// "Minha senha já saiu?" — consulta pública por id do pedido.
  Future<Result<StatusPedido>> statusDoPedido(String pedidoId);

  /// Fila completa (com itens) para o caixa gerenciar.
  Future<Result<List<Pedido>>> filaDoMinisterio(String ministerioId);

  Future<Result<void>> mudarStatus({
    required String pedidoId,
    required StatusPedido status,
  });

  /// Cobra o pedido: cria a venda e baixa o estoque numa transação
  /// (reusa `fn_registrar_venda` por dentro).
  Future<Result<String>> converterEmVenda({
    required String pedidoId,
    required TipoVenda tipo,
    double desconto = 0,
  });
}

abstract interface class UsuarioRepository {
  Future<Result<List<PerfilUsuario>>> listar();

  /// Libera o acesso e vincula ao ministerio. So admin (garantido pela RLS).
  Future<Result<PerfilUsuario>> atualizar(PerfilUsuario perfil);
}

/// Mesa do salao — base do QR de identificacao (Fase 2).
class Mesa {
  const Mesa({
    required this.id,
    required this.ministerioId,
    required this.identificador,
    required this.qrToken,
    this.ativo = true,
  });

  final String id;
  final String ministerioId;
  final String identificador;

  /// Token impresso no QR. Publico: so autoriza criar pedido para esta mesa.
  final String qrToken;

  final bool ativo;

  factory Mesa.fromMap(Map<String, dynamic> map) => Mesa(
    id: map['id'] as String,
    ministerioId: map['ministerio_id'] as String,
    identificador: map['identificador'] as String,
    qrToken: map['qr_token'] as String,
    ativo: map['ativo'] as bool? ?? true,
  );
}

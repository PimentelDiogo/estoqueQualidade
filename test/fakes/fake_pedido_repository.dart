import 'package:espaco_cafe/core/utils/result.dart';
import 'package:espaco_cafe/data/models/enums.dart';
import 'package:espaco_cafe/data/models/pedido.dart';
import 'package:espaco_cafe/data/repositories/repositories.dart';

import 'fake_repositories.dart';

/// Fake do fluxo de pedidos (Fase 2), em memória.
///
/// Espelha o comportamento das RPCs: preço vem do "banco" (o cardápio daqui),
/// senha é gerada pelo repositório e um pedido já cobrado recusa nova cobrança.
class FakePedidoRepository implements PedidoRepository {
  FakePedidoRepository() {
    _cardapio = <ItemCardapio>[
      const ItemCardapio(
        id: 'p1',
        ministerioId: kMinisterioId,
        nome: 'Cafe expresso',
        preco: 4,
        disponivel: true,
      ),
      const ItemCardapio(
        id: 'p2',
        ministerioId: kMinisterioId,
        nome: 'Bolo de cenoura',
        preco: 6,
        disponivel: true,
      ),
      const ItemCardapio(
        id: 'p3',
        ministerioId: kMinisterioId,
        nome: 'Brownie',
        preco: 7,
        disponivel: false,
      ),
    ];

    // Fila inicial: um recebido e um pronto — cobre os dois ramos do fluxo.
    final DateTime agora = DateTime.now();
    fila = <Pedido>[
      Pedido(
        id: 'ped-1',
        ministerioId: kMinisterioId,
        senha: '01',
        status: StatusPedido.recebido,
        criadoEm: agora.subtract(const Duration(minutes: 2)),
        itens: const <PedidoItem>[
          PedidoItem(
            produtoId: 'p1',
            produtoNome: 'Cafe expresso',
            quantidade: 2,
            precoUnitario: 4,
          ),
        ],
      ),
      Pedido(
        id: 'ped-2',
        ministerioId: kMinisterioId,
        senha: '02',
        status: StatusPedido.pronto,
        criadoEm: agora.subtract(const Duration(minutes: 8)),
        itens: const <PedidoItem>[
          PedidoItem(
            produtoId: 'p2',
            produtoNome: 'Bolo de cenoura',
            quantidade: 1,
            precoUnitario: 6,
          ),
        ],
      ),
    ];
  }

  late final List<ItemCardapio> _cardapio;
  late List<Pedido> fila;

  AppFailure? falhaForcada;
  int pedidosCriados = 0;
  int conversoes = 0;

  @override
  Future<Result<List<ItemCardapio>>> cardapio(String qrToken) async {
    if (falhaForcada != null) {
      return Failure<List<ItemCardapio>>(falhaForcada!);
    }
    return Ok<List<ItemCardapio>>(_cardapio);
  }

  @override
  Future<Result<PedidoCriado>> criar({
    required String qrToken,
    required List<ItemPedidoCliente> itens,
    String? clienteNome,
    String? observacao,
  }) async {
    if (falhaForcada != null) return Failure<PedidoCriado>(falhaForcada!);
    if (itens.isEmpty) {
      return const Failure<PedidoCriado>(
        AppFailure.negocio('Adicione ao menos um item.'),
      );
    }

    pedidosCriados++;
    final String senha = pedidosCriados.toString().padLeft(2, '0');
    final String id = 'novo-$pedidosCriados';

    fila.add(
      Pedido(
        id: id,
        ministerioId: kMinisterioId,
        senha: senha,
        status: StatusPedido.recebido,
        clienteNome: clienteNome,
        observacao: observacao,
        criadoEm: DateTime.now(),
        itens: itens
            .map(
              // Preço lido do cardápio, não do que o cliente mandou — igual à RPC.
              (ItemPedidoCliente i) => PedidoItem(
                produtoId: i.produtoId,
                produtoNome: i.nome,
                quantidade: i.quantidade,
                precoUnitario: _cardapio
                    .firstWhere((ItemCardapio c) => c.id == i.produtoId)
                    .preco,
              ),
            )
            .toList(),
      ),
    );

    return Ok<PedidoCriado>(PedidoCriado(id: id, senha: senha));
  }

  @override
  Future<Result<StatusPedido>> statusDoPedido(String pedidoId) async {
    final Pedido? p = fila.where((Pedido e) => e.id == pedidoId).firstOrNull;
    return p == null
        ? const Failure<StatusPedido>(
            AppFailure.negocio('Pedido nao encontrado.'),
          )
        : Ok<StatusPedido>(p.status);
  }

  @override
  Future<Result<List<Pedido>>> filaDoMinisterio(String ministerioId) async {
    if (falhaForcada != null) return Failure<List<Pedido>>(falhaForcada!);
    return Ok<List<Pedido>>(fila.where((Pedido p) => p.status.naFila).toList());
  }

  @override
  Future<Result<void>> mudarStatus({
    required String pedidoId,
    required StatusPedido status,
  }) async {
    final int i = fila.indexWhere((Pedido p) => p.id == pedidoId);
    if (i < 0) {
      return const Failure<void>(AppFailure.negocio('Pedido nao encontrado.'));
    }
    fila[i] = _copiar(fila[i], status: status);
    return const Ok<void>(null);
  }

  @override
  Future<Result<String>> converterEmVenda({
    required String pedidoId,
    required TipoVenda tipo,
    double desconto = 0,
  }) async {
    final int i = fila.indexWhere((Pedido p) => p.id == pedidoId);
    if (i < 0) {
      return const Failure<String>(
        AppFailure.negocio('Pedido nao encontrado.'),
      );
    }

    // Mesma trava de `fn_converter_pedido_em_venda`: cobrar duas vezes geraria
    // duas vendas e baixaria o estoque em dobro.
    if (fila[i].cobrado) {
      return const Failure<String>(
        AppFailure.negocio('Este pedido ja foi cobrado.'),
      );
    }

    conversoes++;
    final String vendaId = 'venda-$conversoes';
    fila[i] = _copiar(fila[i], status: StatusPedido.entregue, vendaId: vendaId);
    return Ok<String>(vendaId);
  }

  Pedido _copiar(Pedido p, {StatusPedido? status, String? vendaId}) => Pedido(
    id: p.id,
    ministerioId: p.ministerioId,
    senha: p.senha,
    status: status ?? p.status,
    criadoEm: p.criadoEm,
    mesaId: p.mesaId,
    mesaIdentificador: p.mesaIdentificador,
    clienteNome: p.clienteNome,
    observacao: p.observacao,
    vendaId: vendaId ?? p.vendaId,
    itens: p.itens,
    qtdItens: p.qtdItens,
  );
}

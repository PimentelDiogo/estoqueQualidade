import 'package:espaco_cafe/core/utils/date_range.dart';
import 'package:espaco_cafe/core/utils/result.dart';
import 'package:espaco_cafe/data/models/enums.dart';
import 'package:espaco_cafe/data/models/estoque.dart';
import 'package:espaco_cafe/data/models/ministerio.dart';
import 'package:espaco_cafe/data/models/perfil_usuario.dart';
import 'package:espaco_cafe/data/models/produto.dart';
import 'package:espaco_cafe/data/models/venda.dart';
import 'package:espaco_cafe/data/repositories/repositories.dart';

/// Fakes em memoria dos repositories.
///
/// Isto e o retorno concreto da regra 2 do CLAUDE.md (ViewModel so conhece a
/// interface): da para testar toda a logica do caixa e do estoque sem Supabase,
/// sem rede e sem mock framework.

const String kMinisterioId = 'min-1';

Produto produtoDeTeste({
  String id = 'p1',
  String nome = 'Cafe expresso',
  double preco = 4,
  int quantidade = 10,
  int minimo = 5,
  String? codigoBarras,
  bool ativo = true,
}) => Produto(
  id: id,
  ministerioId: kMinisterioId,
  nome: nome,
  precoVenda: preco,
  quantidade: quantidade,
  estoqueMinimo: minimo,
  codigoBarras: codigoBarras,
  ativo: ativo,
);

class FakeProdutoRepository implements ProdutoRepository {
  FakeProdutoRepository([List<Produto>? iniciais])
    : produtos = <Produto>[...?iniciais];

  final List<Produto> produtos;

  /// Quando setada, toda chamada falha com esta [AppFailure].
  AppFailure? falhaForcada;

  int chamadasListar = 0;

  @override
  Future<Result<List<Produto>>> listar({
    required String ministerioId,
    bool apenasAtivos = true,
  }) async {
    chamadasListar++;
    if (falhaForcada != null) {
      return Failure<List<Produto>>(falhaForcada!);
    }
    return Ok<List<Produto>>(
      produtos
          .where((Produto p) => !apenasAtivos || p.ativo)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<Produto?>> porCodigoBarras({
    required String ministerioId,
    required String codigo,
  }) async {
    if (falhaForcada != null) return Failure<Produto?>(falhaForcada!);
    return Ok<Produto?>(
      produtos
          .where((Produto p) => p.codigoBarras == codigo.trim())
          .firstOrNull,
    );
  }

  @override
  Future<Result<Produto>> criar(Produto produto) async {
    if (falhaForcada != null) return Failure<Produto>(falhaForcada!);
    final Produto criado = produto.copyWith();
    produtos.add(criado);
    return Ok<Produto>(criado);
  }

  @override
  Future<Result<Produto>> atualizar(Produto produto) async {
    if (falhaForcada != null) return Failure<Produto>(falhaForcada!);
    final int i = produtos.indexWhere((Produto p) => p.id == produto.id);
    if (i >= 0) produtos[i] = produto;
    return Ok<Produto>(produto);
  }

  @override
  Future<Result<void>> desativar(String produtoId) async {
    if (falhaForcada != null) return Failure<void>(falhaForcada!);
    final int i = produtos.indexWhere((Produto p) => p.id == produtoId);
    if (i >= 0) produtos[i] = produtos[i].copyWith(ativo: false);
    return const Ok<void>(null);
  }

  @override
  Future<Result<int>> movimentarEstoque({
    required String produtoId,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  }) async {
    if (falhaForcada != null) return Failure<int>(falhaForcada!);

    final int i = produtos.indexWhere((Produto p) => p.id == produtoId);
    if (i < 0) {
      return const Failure<int>(AppFailure.negocio('Produto nao encontrado.'));
    }

    final int delta = switch (tipo) {
      TipoMovimentacao.entrada => quantidade.abs(),
      TipoMovimentacao.perda => -quantidade.abs(),
      _ => quantidade,
    };
    final int saldo = produtos[i].quantidade + delta;

    if (saldo < 0) {
      return const Failure<int>(AppFailure.negocio('Estoque insuficiente.'));
    }

    produtos[i] = produtos[i].copyWith(quantidade: saldo);
    return Ok<int>(saldo);
  }

  @override
  Future<Result<List<MovimentacaoEstoque>>> historicoMovimentacoes({
    required String produtoId,
    int limite = 50,
  }) async => const Ok<List<MovimentacaoEstoque>>(<MovimentacaoEstoque>[]);
}

/// Simula a RPC transacional: valida estoque e da baixa numa operacao so.
class FakeVendaRepository implements VendaRepository {
  FakeVendaRepository(this.produtoRepo);

  final FakeProdutoRepository produtoRepo;
  final List<Venda> vendas = <Venda>[];

  AppFailure? falhaForcada;
  int chamadasRegistrar = 0;

  @override
  Future<Result<String>> registrar({
    required String ministerioId,
    required TipoVenda tipo,
    required List<ItemCarrinho> itens,
    double desconto = 0,
    String? observacao,
  }) async {
    chamadasRegistrar++;
    if (falhaForcada != null) return Failure<String>(falhaForcada!);
    if (itens.isEmpty) {
      return const Failure<String>(
        AppFailure.negocio('Adicione ao menos um item a venda.'),
      );
    }

    // Espelha o comportamento da RPC: valida TODOS os itens antes de gravar
    // qualquer coisa. Ou a venda inteira entra, ou nada entra.
    for (final ItemCarrinho item in itens) {
      final Produto atual = produtoRepo.produtos.firstWhere(
        (Produto p) => p.id == item.produto.id,
      );
      if (atual.quantidade < item.quantidade) {
        return Failure<String>(
          AppFailure.negocio(
            'Estoque insuficiente: ${atual.nome} '
            '(disponivel: ${atual.quantidade}, pedido: ${item.quantidade})',
          ),
        );
      }
    }

    final List<VendaItem> vendaItens = <VendaItem>[];
    for (final ItemCarrinho item in itens) {
      final int i = produtoRepo.produtos.indexWhere(
        (Produto p) => p.id == item.produto.id,
      );
      final Produto atual = produtoRepo.produtos[i];

      produtoRepo.produtos[i] = atual.copyWith(
        quantidade: atual.quantidade - item.quantidade,
      );

      vendaItens.add(
        VendaItem(
          produtoId: atual.id,
          produtoNome: atual.nome,
          quantidade: item.quantidade,
          // Preco do BANCO, nao do cliente — igual a RPC.
          precoUnitario: atual.precoVenda,
          subtotal: atual.precoVenda * item.quantidade,
        ),
      );
    }

    final double bruto = vendaItens.fold(
      0,
      (double s, VendaItem i) => s + i.subtotal,
    );

    final Venda venda = Venda(
      id: 'venda-${vendas.length + 1}',
      ministerioId: ministerioId,
      tipo: tipo,
      valorTotal: (bruto - desconto).clamp(0, double.infinity),
      desconto: desconto,
      observacao: observacao,
      criadoEm: DateTime.now(),
      itens: vendaItens,
    );

    vendas.add(venda);
    return Ok<String>(venda.id);
  }

  @override
  Future<Result<Venda>> porId(String vendaId) async {
    final Venda? v = vendas.where((Venda e) => e.id == vendaId).firstOrNull;
    return v == null
        ? const Failure<Venda>(AppFailure.negocio('Venda nao encontrada.'))
        : Ok<Venda>(v);
  }

  @override
  Future<Result<List<Venda>>> listar({
    required String ministerioId,
    required DateRange periodo,
    int limite = 100,
  }) async => Ok<List<Venda>>(
    vendas.where((Venda v) => periodo.contem(v.criadoEm)).toList(),
  );
}

class FakeMinisterioRepository implements MinisterioRepository {
  FakeMinisterioRepository([Ministerio? unico])
    : ministerios = <Ministerio>[
        unico ??
            const Ministerio(
              id: kMinisterioId,
              nome: 'Espaco Cafe',
              slug: 'espaco-cafe',
              pixPayloadQr: '00020126-payload-de-teste',
            ),
      ];

  final List<Ministerio> ministerios;
  final List<Mesa> mesas = <Mesa>[];

  @override
  Future<Result<List<Ministerio>>> listar({bool apenasAtivos = true}) async =>
      Ok<List<Ministerio>>(
        ministerios.where((Ministerio m) => !apenasAtivos || m.ativo).toList(),
      );

  @override
  Future<Result<Ministerio>> porId(String id) async {
    final Ministerio? m = ministerios
        .where((Ministerio e) => e.id == id)
        .firstOrNull;
    return m == null
        ? const Failure<Ministerio>(
            AppFailure.negocio('Ministerio nao encontrado.'),
          )
        : Ok<Ministerio>(m);
  }

  @override
  Future<Result<Ministerio>> criar(Ministerio ministerio) async {
    ministerios.add(ministerio);
    return Ok<Ministerio>(ministerio);
  }

  @override
  Future<Result<Ministerio>> atualizar(Ministerio ministerio) async {
    final int i = ministerios.indexWhere(
      (Ministerio m) => m.id == ministerio.id,
    );
    if (i >= 0) ministerios[i] = ministerio;
    return Ok<Ministerio>(ministerio);
  }

  @override
  Future<Result<String>> enviarImagemQrPix({
    required String ministerioId,
    required List<int> bytes,
    required String extensao,
  }) async => Ok<String>('https://fake/$ministerioId.$extensao');

  @override
  Future<Result<List<Mesa>>> listarMesas(String ministerioId) async =>
      Ok<List<Mesa>>(mesas);

  @override
  Future<Result<Mesa>> criarMesa({
    required String ministerioId,
    required String identificador,
  }) async {
    final Mesa m = Mesa(
      id: 'mesa-${mesas.length + 1}',
      ministerioId: ministerioId,
      identificador: identificador,
      qrToken: 'token-${mesas.length + 1}',
    );
    mesas.add(m);
    return Ok<Mesa>(m);
  }
}

class FakeAlertaRepository implements AlertaRepository {
  FakeAlertaRepository(this.produtoRepo);

  final FakeProdutoRepository produtoRepo;
  final Set<String> resolvidos = <String>{};

  /// Deriva os alertas do estoque atual — e o que a `vw_estoque_baixo` faz.
  @override
  Future<Result<List<AlertaEstoque>>> listar(String ministerioId) async =>
      Ok<List<AlertaEstoque>>(
        produtoRepo.produtos
            .where((Produto p) => p.ativo && p.precisaRepor)
            .where((Produto p) => !resolvidos.contains('alerta-${p.id}'))
            .map(
              (Produto p) => AlertaEstoque(
                produtoId: p.id,
                ministerioId: ministerioId,
                produtoNome: p.nome,
                quantidade: p.quantidade,
                estoqueMinimo: p.estoqueMinimo,
                alertaId: 'alerta-${p.id}',
              ),
            )
            .toList(),
      );

  @override
  Future<Result<void>> resolver(String alertaId) async {
    resolvidos.add(alertaId);
    return const Ok<void>(null);
  }
}

class FakeRelatorioRepository implements RelatorioRepository {
  ResumoPeriodo resumoRetornado = const ResumoPeriodo();
  List<VendaAgregada> serieRetornada = <VendaAgregada>[];
  List<ProdutoMaisVendido> maisVendidosRetornados = <ProdutoMaisVendido>[];

  @override
  Future<Result<ResumoPeriodo>> resumo({
    required String ministerioId,
    required DateRange periodo,
  }) async => Ok<ResumoPeriodo>(resumoRetornado);

  @override
  Future<Result<List<VendaAgregada>>> serie({
    required String ministerioId,
    required Periodo granularidade,
    required DateRange periodo,
  }) async => Ok<List<VendaAgregada>>(serieRetornada);

  @override
  Future<Result<List<ProdutoMaisVendido>>> maisVendidos({
    required String ministerioId,
    required DateRange periodo,
    int limite = 10,
  }) async => Ok<List<ProdutoMaisVendido>>(maisVendidosRetornados);
}

class FakeUsuarioRepository implements UsuarioRepository {
  final List<PerfilUsuario> usuarios = <PerfilUsuario>[];

  @override
  Future<Result<List<PerfilUsuario>>> listar() async =>
      Ok<List<PerfilUsuario>>(usuarios);

  @override
  Future<Result<PerfilUsuario>> atualizar(PerfilUsuario perfil) async {
    final int i = usuarios.indexWhere((PerfilUsuario u) => u.id == perfil.id);
    if (i >= 0) usuarios[i] = perfil;
    return Ok<PerfilUsuario>(perfil);
  }
}

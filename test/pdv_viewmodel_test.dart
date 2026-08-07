import 'package:espaco_cafe/core/utils/result.dart';
import 'package:espaco_cafe/data/models/enums.dart';
import 'package:espaco_cafe/data/models/ministerio.dart';
import 'package:espaco_cafe/data/models/produto.dart';
import 'package:espaco_cafe/modules/pdv/viewmodel/pdv_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_contexto.dart';
import 'fakes/fake_repositories.dart';

void main() {
  late FakeProdutoRepository produtoRepo;
  late FakeVendaRepository vendaRepo;
  late FakeMinisterioRepository ministerioRepo;
  late PdvViewModel vm;

  PdvViewModel montar({
    List<Produto>? produtos,
    Ministerio? ministerio,
    String? ministerioId = kMinisterioId,
  }) {
    produtoRepo = FakeProdutoRepository(
      produtos ??
          <Produto>[
            produtoDeTeste(
              id: 'p1',
              nome: 'Cafe expresso',
              preco: 4,
              quantidade: 10,
            ),
            produtoDeTeste(
              id: 'p2',
              nome: 'Bolo de cenoura',
              preco: 6,
              quantidade: 2,
            ),
            produtoDeTeste(id: 'p3', nome: 'Brownie', preco: 7, quantidade: 0),
          ],
    );
    vendaRepo = FakeVendaRepository(produtoRepo);
    ministerioRepo = FakeMinisterioRepository(ministerio);

    return PdvViewModel(
      produtoRepo: produtoRepo,
      vendaRepo: vendaRepo,
      ministerioRepo: ministerioRepo,
      session: FakeContexto(ministerioId: ministerioId),
    );
  }

  /// `onInit` dispara o carregamento; esperamos ele terminar antes de assertar.
  Future<void> carregado(PdvViewModel v) async {
    v.onInit();
    await Future<void>.delayed(Duration.zero);
  }

  group('Carrinho', () {
    setUp(() => vm = montar());

    test('adicionar incrementa a quantidade do mesmo produto', () {
      final Produto cafe = produtoDeTeste(quantidade: 10);

      vm
        ..adicionar(cafe)
        ..adicionar(cafe);

      expect(vm.carrinho.length, 1);
      expect(vm.carrinho.first.quantidade, 2);
      expect(vm.quantidadeTotal, 2);
    });

    test('nao adiciona produto esgotado', () {
      vm.adicionar(produtoDeTeste(id: 'x', quantidade: 0));
      expect(vm.carrinho, isEmpty);
    });

    test('nao deixa passar do estoque disponivel', () {
      final Produto bolo = produtoDeTeste(id: 'p2', quantidade: 2);

      vm
        ..adicionar(bolo)
        ..adicionar(bolo)
        ..adicionar(bolo); // terceiro toque nao entra

      expect(vm.carrinho.first.quantidade, 2);
    });

    test('remover decrementa e some quando chega a zero', () {
      final Produto cafe = produtoDeTeste(quantidade: 10);

      vm
        ..adicionar(cafe)
        ..adicionar(cafe)
        ..remover(cafe.id);
      expect(vm.carrinho.first.quantidade, 1);

      vm.remover(cafe.id);
      expect(vm.carrinho, isEmpty);
    });

    test('total desconta o desconto e nunca fica negativo', () {
      vm.adicionar(produtoDeTeste(preco: 4, quantidade: 10)); // 4,00

      vm.definirDesconto(1);
      expect(vm.total, 3);

      // Desconto maior que o subtotal e travado no subtotal.
      vm.definirDesconto(100);
      expect(vm.total, 0);
    });
  });

  group('Finalizar venda', () {
    test('registra, baixa o estoque e limpa o carrinho', () async {
      vm = montar();
      await carregado(vm);

      vm
        ..adicionar(produtoRepo.produtos.first) // Cafe 4,00
        ..adicionar(produtoRepo.produtos.first)
        ..definirTipo(TipoVenda.dinheiro);

      final bool ok = await vm.finalizarVenda();

      expect(ok, isTrue);
      expect(vm.carrinho, isEmpty, reason: 'carrinho deve zerar apos a venda');
      expect(vendaRepo.vendas.single.valorTotal, 8);
      expect(
        produtoRepo.produtos.firstWhere((Produto p) => p.id == 'p1').quantidade,
        8,
        reason: 'estoque deve cair de 10 para 8',
      );
    });

    test('carrinho vazio nao chega a chamar o repository', () async {
      vm = montar();
      await carregado(vm);

      expect(await vm.finalizarVenda(), isFalse);
      expect(vendaRepo.chamadasRegistrar, 0);
    });

    /// Este e o teste que justifica a RPC transacional (ADR-003): dois toques
    /// rapidos no botao nao podem virar duas vendas.
    test('duplo toque nao registra duas vendas', () async {
      vm = montar();
      await carregado(vm);
      vm.adicionar(produtoRepo.produtos.first);

      final List<bool> resultados = await Future.wait(<Future<bool>>[
        vm.finalizarVenda(),
        vm.finalizarVenda(),
      ]);

      expect(resultados.where((bool r) => r).length, 1);
      expect(vendaRepo.chamadasRegistrar, 1);
    });

    test(
      'falha de estoque vira mensagem em portugues e mantem o carrinho vazio '
      'apenas em caso de sucesso',
      () async {
        vm = montar();
        await carregado(vm);

        // Outro caixa esvaziou o estoque entre o carregamento e a finalizacao.
        final int i = produtoRepo.produtos.indexWhere(
          (Produto p) => p.id == 'p1',
        );
        vm.adicionar(produtoRepo.produtos[i]);
        produtoRepo.produtos[i] = produtoRepo.produtos[i].copyWith(
          quantidade: 0,
        );

        final bool ok = await vm.finalizarVenda();

        expect(ok, isFalse);
        expect(vm.falha.value, isNotNull);
        expect(vm.falha.value!.kind, FailureKind.negocio);
        expect(vm.falha.value!.mensagem, contains('Estoque insuficiente'));
      },
    );

    test('sem ministerio em foco, recusa com mensagem clara', () async {
      vm = montar(ministerioId: null);
      vm.adicionar(produtoDeTeste(quantidade: 5));

      expect(await vm.finalizarVenda(), isFalse);
      expect(vm.falha.value!.mensagem, contains('Nenhum ministerio'));
    });
  });

  group('Pix', () {
    test('sem QR cadastrado, o tipo padrao deixa de ser Pix', () async {
      vm = montar(
        ministerio: const Ministerio(
          id: kMinisterioId,
          nome: 'Sem Pix',
          slug: 'sem-pix',
        ),
      );
      await carregado(vm);

      expect(vm.podeCobrarPix, isFalse);
      expect(vm.tipoVenda.value, TipoVenda.dinheiro);
    });

    test('com QR cadastrado, Pix continua disponivel', () async {
      vm = montar();
      await carregado(vm);

      expect(vm.podeCobrarPix, isTrue);
      expect(vm.tipoVenda.value, TipoVenda.pix);
    });
  });

  group('Busca e codigo de barras', () {
    test('busca ignora acento e caixa', () async {
      vm = montar();
      await carregado(vm);

      vm.aoBuscar('CENOURA');
      expect(vm.produtosFiltrados.single.nome, 'Bolo de cenoura');
    });

    test('codigo ja carregado nao vai a rede', () async {
      vm = montar(
        produtos: <Produto>[
          produtoDeTeste(id: 'p9', codigoBarras: '789', quantidade: 5),
        ],
      );
      await carregado(vm);
      final int antes = produtoRepo.chamadasListar;

      expect(await vm.adicionarPorCodigoBarras('789'), isTrue);
      expect(vm.carrinho.single.produto.id, 'p9');
      expect(produtoRepo.chamadasListar, antes);
    });

    test('codigo desconhecido devolve false sem quebrar', () async {
      vm = montar();
      await carregado(vm);

      expect(await vm.adicionarPorCodigoBarras('000'), isFalse);
      expect(vm.carrinho, isEmpty);
    });
  });

  group('Total do turno', () {
    test('cortesia nao entra na arrecadacao', () async {
      vm = montar();
      await carregado(vm);

      vm
        ..adicionar(produtoRepo.produtos.first) // 4,00
        ..definirTipo(TipoVenda.dinheiro);
      await vm.finalizarVenda();

      vm
        ..adicionar(produtoRepo.produtos.first) // 4,00 de cortesia
        ..definirTipo(TipoVenda.cortesia);
      await vm.finalizarVenda();

      expect(vm.vendasDoDia.length, 2);
      expect(
        vm.totalDoDia,
        4,
        reason: 'so a venda em dinheiro conta como arrecadacao',
      );
    });
  });
}

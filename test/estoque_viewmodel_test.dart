import 'package:espaco_cafe/data/models/enums.dart';
import 'package:espaco_cafe/data/models/produto.dart';
import 'package:espaco_cafe/modules/estoque/viewmodel/estoque_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_contexto.dart';
import 'fakes/fake_repositories.dart';

void main() {
  late FakeProdutoRepository produtoRepo;
  late FakeAlertaRepository alertaRepo;
  late EstoqueViewModel vm;

  Future<EstoqueViewModel> montar([List<Produto>? produtos]) async {
    produtoRepo = FakeProdutoRepository(
      produtos ??
          <Produto>[
            // Ok: 10 de 5
            produtoDeTeste(
              id: 'p1',
              nome: 'Cafe expresso',
              quantidade: 10,
              minimo: 5,
            ),
            // Acabando: 4 de 6
            produtoDeTeste(
              id: 'p2',
              nome: 'Pao de queijo',
              quantidade: 4,
              minimo: 6,
            ),
            // Esgotado
            produtoDeTeste(id: 'p3', nome: 'Brownie', quantidade: 0, minimo: 3),
          ],
    );
    alertaRepo = FakeAlertaRepository(produtoRepo);

    final EstoqueViewModel v = EstoqueViewModel(
      produtoRepo: produtoRepo,
      alertaRepo: alertaRepo,
      session: FakeContexto(),
    )..onInit();

    await Future<void>.delayed(Duration.zero);
    return v;
  }

  group('Alertas', () {
    test('conta produtos no minimo e esgotados', () async {
      vm = await montar();

      expect(vm.totalAlertas, 2, reason: 'Pao de queijo e Brownie');
      expect(vm.totalEsgotados, 1, reason: 'so o Brownie');
    });

    test('repor acima do minimo tira o produto do alerta', () async {
      vm = await montar();
      expect(vm.totalAlertas, 2);

      await vm.movimentar(
        produtoId: 'p2',
        tipo: TipoMovimentacao.entrada,
        quantidade: 20,
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.totalAlertas, 1);
      expect(
        produtoRepo.produtos.firstWhere((Produto p) => p.id == 'p2').quantidade,
        24,
      );
    });
  });

  group('Movimentacao', () {
    test('entrada soma ao saldo', () async {
      vm = await montar();

      final bool ok = await vm.movimentar(
        produtoId: 'p1',
        tipo: TipoMovimentacao.entrada,
        quantidade: 5,
      );

      expect(ok, isTrue);
      expect(
        vm.produtos.firstWhere((Produto p) => p.id == 'p1').quantidade,
        15,
      );
    });

    test('perda subtrai do saldo', () async {
      vm = await montar();

      await vm.movimentar(
        produtoId: 'p1',
        tipo: TipoMovimentacao.perda,
        quantidade: 3,
        observacao: 'Vencido',
      );

      expect(vm.produtos.firstWhere((Produto p) => p.id == 'p1').quantidade, 7);
    });

    test('nao deixa o saldo ficar negativo', () async {
      vm = await montar();

      final bool ok = await vm.movimentar(
        produtoId: 'p3', // esgotado
        tipo: TipoMovimentacao.perda,
        quantidade: 1,
      );

      expect(ok, isFalse);
      expect(vm.falha.value, isNotNull);
      expect(
        produtoRepo.produtos.firstWhere((Produto p) => p.id == 'p3').quantidade,
        0,
      );
    });

    test('ajuste negativo aceita sinal', () async {
      vm = await montar();

      await vm.movimentar(
        produtoId: 'p1',
        tipo: TipoMovimentacao.ajuste,
        quantidade: -4,
        observacao: 'Inventario fisico',
      );

      expect(vm.produtos.firstWhere((Produto p) => p.id == 'p1').quantidade, 6);
    });
  });

  group('Filtros', () {
    test('filtro "acabando" traz os que estao no minimo ou abaixo', () async {
      vm = await montar();

      vm.definirFiltro(FiltroEstoque.acabando);
      expect(
        vm.produtosFiltrados.map((Produto p) => p.id),
        containsAll(<String>['p2', 'p3']),
      );
    });

    test('filtro "esgotados" traz so quantidade zero', () async {
      vm = await montar();

      vm.definirFiltro(FiltroEstoque.esgotados);
      expect(vm.produtosFiltrados.single.id, 'p3');
    });

    test('busca combina com o filtro ativo', () async {
      vm = await montar();

      vm
        ..definirFiltro(FiltroEstoque.acabando)
        ..aoBuscar('brownie');

      expect(vm.produtosFiltrados.single.id, 'p3');
    });
  });

  group('Valor em estoque', () {
    test('soma a custo, nao a preco de venda', () async {
      vm = await montar(<Produto>[
        Produto(
          id: 'p1',
          ministerioId: kMinisterioId,
          nome: 'Cafe',
          precoVenda: 4,
          custo: 1.5,
          quantidade: 10,
        ),
      ]);

      expect(vm.valorTotalEmEstoque, 15);
    });
  });
}

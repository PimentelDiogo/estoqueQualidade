import 'package:espaco_cafe/core/utils/result.dart';
import 'package:espaco_cafe/data/models/enums.dart';
import 'package:espaco_cafe/data/models/pedido.dart';
import 'package:espaco_cafe/modules/pedido/viewmodel/pedido_cliente_viewmodel.dart';
import 'package:espaco_cafe/modules/pedidos/viewmodel/pedidos_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_contexto.dart';
import 'fakes/fake_pedido_repository.dart';

void main() {
  const String token = 'token-mesa-1';

  group('Pedido do cliente', () {
    late FakePedidoRepository repo;
    late PedidoClienteViewModel vm;

    Future<void> montar() async {
      repo = FakePedidoRepository();
      vm = PedidoClienteViewModel(repo: repo, qrToken: token)..onInit();
      await Future<void>.delayed(Duration.zero);
    }

    test('carrega o cardapio da mesa', () async {
      await montar();
      expect(vm.cardapio.length, 3);
      expect(vm.carregando.value, isFalse);
    });

    test('adicionar incrementa e respeita item esgotado', () async {
      await montar();

      final ItemCardapio cafe = vm.cardapio.first;
      vm
        ..adicionar(cafe)
        ..adicionar(cafe);
      expect(vm.carrinho.single.quantidade, 2);
      expect(vm.total, cafe.preco * 2);

      final ItemCardapio esgotado = vm.cardapio.firstWhere(
        (ItemCardapio i) => !i.disponivel,
      );
      vm.adicionar(esgotado);
      expect(vm.carrinho.length, 1, reason: 'esgotado nao entra no carrinho');
    });

    test('remover decrementa e some no zero', () async {
      await montar();
      final ItemCardapio cafe = vm.cardapio.first;

      vm
        ..adicionar(cafe)
        ..adicionar(cafe)
        ..remover(cafe.id);
      expect(vm.carrinho.single.quantidade, 1);

      vm.remover(cafe.id);
      expect(vm.carrinho, isEmpty);
    });

    test('enviar devolve senha e muda a tela para acompanhamento', () async {
      await montar();
      vm.adicionar(vm.cardapio.first);

      final bool ok = await vm.enviarPedido();

      expect(ok, isTrue);
      expect(vm.enviado, isTrue);
      expect(vm.senha.value, isNotNull);
      expect(repo.pedidosCriados, 1);
    });

    /// A rede do celular do visitante é imprevisível: dois toques no botão de
    /// enviar não podem virar dois pedidos e duas senhas.
    test('duplo toque nao cria dois pedidos', () async {
      await montar();
      vm.adicionar(vm.cardapio.first);

      final List<bool> r = await Future.wait(<Future<bool>>[
        vm.enviarPedido(),
        vm.enviarPedido(),
      ]);

      expect(r.where((bool e) => e).length, 1);
      expect(repo.pedidosCriados, 1);
    });

    test('carrinho vazio nao chama o repository', () async {
      await montar();
      expect(await vm.enviarPedido(), isFalse);
      expect(repo.pedidosCriados, 0);
    });

    test('token invalido vira erro em portugues', () async {
      repo = FakePedidoRepository()
        ..falhaForcada = const AppFailure.negocio(
          'Mesa invalida. Escaneie o QR de novo.',
        );
      vm = PedidoClienteViewModel(repo: repo, qrToken: 'lixo')..onInit();
      await Future<void>.delayed(Duration.zero);

      expect(vm.falha.value, isNotNull);
      expect(vm.falha.value!.mensagem, contains('Mesa invalida'));
    });

    test('novoPedido volta ao cardapio e zera o carrinho', () async {
      await montar();
      vm.adicionar(vm.cardapio.first);
      await vm.enviarPedido();
      expect(vm.enviado, isTrue);

      vm.novoPedido();

      expect(vm.enviado, isFalse);
      expect(vm.carrinho, isEmpty);
      expect(vm.senha.value, isNull);
    });
  });

  group('Fila do caixa', () {
    late FakePedidoRepository repo;
    late PedidosViewModel vm;

    Future<void> montar() async {
      repo = FakePedidoRepository();
      vm = PedidosViewModel(repo: repo, session: FakeContexto())..onInit();
      await Future<void>.delayed(Duration.zero);
    }

    test('carrega a fila do ministerio', () async {
      await montar();
      expect(vm.pedidos.length, 2);
    });

    test('avancar segue recebido -> preparando -> pronto', () async {
      await montar();
      final Pedido p = vm.pedidos.firstWhere(
        (Pedido e) => e.status == StatusPedido.recebido,
      );

      await vm.avancar(p);
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.pedidos.firstWhere((Pedido e) => e.id == p.id).status,
        StatusPedido.preparando,
      );
    });

    /// Marcar "entregue" sem cobrar deixaria o estoque sem baixa e a venda sem
    /// registro — exatamente o buraco que o sistema existe para fechar.
    test('nao deixa entregar pedido nao cobrado', () async {
      await montar();
      final Pedido pronto = vm.pedidos.firstWhere(
        (Pedido e) => e.status == StatusPedido.pronto,
      );

      final bool ok = await vm.avancar(pronto);

      expect(ok, isFalse);
      expect(vm.falha.value, isNotNull);
      expect(vm.falha.value!.mensagem, contains('Cobre o pedido'));
    });

    test('cobrar gera venda e marca o pedido como cobrado', () async {
      await montar();
      final Pedido p = vm.pedidos.first;

      final String? vendaId = await vm.cobrar(
        pedidoId: p.id,
        tipo: TipoVenda.dinheiro,
      );
      await Future<void>.delayed(Duration.zero);

      expect(vendaId, isNotNull);
      expect(repo.conversoes, 1);

      // Cobrar fecha o pedido: ele vira "entregue" e SAI da fila do caixa.
      // Continuar aparecendo faria o voluntário cobrar de novo.
      expect(
        vm.pedidos.where((Pedido e) => e.id == p.id),
        isEmpty,
        reason: 'pedido cobrado nao fica mais na fila',
      );
      expect(repo.fila.firstWhere((Pedido e) => e.id == p.id).cobrado, isTrue);
    });

    test('nao cobra duas vezes o mesmo pedido', () async {
      await montar();
      final Pedido p = vm.pedidos.first;

      await vm.cobrar(pedidoId: p.id, tipo: TipoVenda.pix);
      await Future<void>.delayed(Duration.zero);
      final String? segunda = await vm.cobrar(
        pedidoId: p.id,
        tipo: TipoVenda.pix,
      );

      expect(segunda, isNull);
      expect(vm.falha.value!.mensagem, contains('ja foi cobrado'));
    });
  });
}

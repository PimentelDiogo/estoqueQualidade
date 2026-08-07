/// Rotas do app. Strings centralizadas para evitar literal solto nas Views.
abstract final class Rotas {
  static const String login = '/login';

  /// Escolha de ministerio (so admin cai aqui).
  static const String escolherMinisterio = '/ministerio-ativo';

  /// Caixa: registrar venda.
  static const String pdv = '/pdv';

  static const String estoque = '/estoque';
  static const String produtoForm = '/estoque/produto';
  static const String alertas = '/estoque/alertas';

  /// Leitor de codigo de barras. Devolve o codigo lido como resultado da rota.
  static const String scanner = '/scanner';

  static const String relatorios = '/relatorios';

  /// Fila de pedidos do lado do caixa (avançar status, cobrar).
  static const String pedidos = '/pedidos';

  /// Admin: cadastro de ministerios, QR PIX, mesas e usuarios.
  static const String ministerios = '/ministerios';
  static const String ministerioForm = '/ministerios/editar';
  static const String usuarios = '/usuarios';

  /// Fila de pedidos na TV — publica, sem login, identificada por token.
  static const String tv = '/tv/:token';
  static String tvCom(String token) => '/tv/$token';

  /// Pedido do cliente pelo QR da mesa (Fase 2).
  static const String pedidoCliente = '/pedido/:token';
  static String pedidoClienteCom(String token) => '/pedido/$token';

  /// Galeria de componentes — so em dev (ver Env.showcaseEnabled).
  static const String showcase = '/showcase';
}

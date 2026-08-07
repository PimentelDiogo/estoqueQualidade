import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Enums espelhando os `type` do Postgres.
///
/// O valor de [db] e o contrato com o banco — mudar aqui sem migration quebra
/// a insercao. Os campos de UI (label/icone/cor) ficam junto de proposito: sao a
/// unica fonte de verdade de como cada valor se apresenta.

enum PapelUsuario {
  admin('admin', 'Administrador'),
  caixa('caixa', 'Caixa');

  const PapelUsuario(this.db, this.label);

  final String db;
  final String label;

  static PapelUsuario fromDb(String value) => PapelUsuario.values.firstWhere(
    (PapelUsuario p) => p.db == value,
    orElse: () => PapelUsuario.caixa,
  );
}

enum TipoVenda {
  pix('pix', 'Pix', Icons.qr_code_2, AppColors.vendaPix),
  dinheiro(
    'dinheiro',
    'Dinheiro',
    Icons.payments_outlined,
    AppColors.vendaDinheiro,
  ),
  cartao('cartao', 'Cartao', Icons.credit_card, AppColors.vendaCartao),
  cortesia(
    'cortesia',
    'Cortesia',
    Icons.volunteer_activism_outlined,
    AppColors.vendaCortesia,
  );

  const TipoVenda(this.db, this.label, this.icone, this.cor);

  final String db;
  final String label;
  final IconData icone;
  final Color cor;

  /// Cortesia baixa o estoque mas nao entra como arrecadacao esperada —
  /// e o cafe oferecido ao visitante. Continua registrado para o estoque bater.
  bool get contabilizaReceita => this != TipoVenda.cortesia;

  static TipoVenda fromDb(String value) => TipoVenda.values.firstWhere(
    (TipoVenda t) => t.db == value,
    orElse: () => TipoVenda.dinheiro,
  );
}

enum TipoMovimentacao {
  entrada('entrada', 'Entrada', Icons.add_box_outlined, AppColors.success),
  saidaVenda(
    'saida_venda',
    'Venda',
    Icons.shopping_cart_outlined,
    AppColors.info,
  ),
  ajuste('ajuste', 'Ajuste', Icons.tune, AppColors.warning),
  perda('perda', 'Perda', Icons.delete_outline, AppColors.danger);

  const TipoMovimentacao(this.db, this.label, this.icone, this.cor);

  final String db;
  final String label;
  final IconData icone;
  final Color cor;

  /// Movimentacoes que o usuario pode lancar na tela de estoque.
  /// `saidaVenda` fica de fora: so a RPC de venda a produz.
  static List<TipoMovimentacao> get manuais => <TipoMovimentacao>[
    TipoMovimentacao.entrada,
    TipoMovimentacao.ajuste,
    TipoMovimentacao.perda,
  ];

  static TipoMovimentacao fromDb(String value) =>
      TipoMovimentacao.values.firstWhere(
        (TipoMovimentacao t) => t.db == value,
        orElse: () => TipoMovimentacao.ajuste,
      );
}

enum StatusAlerta {
  aberto('aberto', 'Aberto'),
  resolvido('resolvido', 'Resolvido');

  const StatusAlerta(this.db, this.label);

  final String db;
  final String label;

  static StatusAlerta fromDb(String value) => StatusAlerta.values.firstWhere(
    (StatusAlerta s) => s.db == value,
    orElse: () => StatusAlerta.aberto,
  );
}

/// Fase 2 — fila da TV.
enum StatusPedido {
  recebido('recebido', 'Recebido', AppColors.statusRecebido),
  preparando('preparando', 'Preparando', AppColors.statusPreparando),
  pronto('pronto', 'Pronto', AppColors.statusPronto),
  entregue('entregue', 'Entregue', AppColors.statusEntregue),
  cancelado('cancelado', 'Cancelado', AppColors.danger);

  const StatusPedido(this.db, this.label, this.cor);

  final String db;
  final String label;
  final Color cor;

  /// Os que aparecem na fila da TV.
  bool get naFila =>
      this == StatusPedido.recebido ||
      this == StatusPedido.preparando ||
      this == StatusPedido.pronto;

  static StatusPedido fromDb(String value) => StatusPedido.values.firstWhere(
    (StatusPedido s) => s.db == value,
    orElse: () => StatusPedido.recebido,
  );
}

/// Situacao de estoque derivada da quantidade — usada em lista, badge e alerta.
enum SituacaoEstoque {
  ok('Ok', AppColors.success),
  acabando('Acabando', AppColors.warning),
  esgotado('Esgotado', AppColors.danger);

  const SituacaoEstoque(this.label, this.cor);

  final String label;
  final Color cor;

  static SituacaoEstoque de({required int quantidade, required int minimo}) {
    if (quantidade <= 0) return SituacaoEstoque.esgotado;
    if (quantidade <= minimo) return SituacaoEstoque.acabando;
    return SituacaoEstoque.ok;
  }
}

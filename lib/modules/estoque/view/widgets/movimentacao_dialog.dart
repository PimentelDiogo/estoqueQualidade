import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/estoque.dart';
import '../../../../data/models/produto.dart';
import '../../viewmodel/estoque_viewmodel.dart';

/// Entrada, ajuste ou perda de estoque, com o historico do produto embaixo.
///
/// `saida_venda` nao aparece: essa so nasce da RPC do caixa (ver
/// [TipoMovimentacao.manuais]).
class MovimentacaoDialog extends StatefulWidget {
  const MovimentacaoDialog({required this.produto, super.key});

  final Produto produto;

  @override
  State<MovimentacaoDialog> createState() => _MovimentacaoDialogState();
}

class _MovimentacaoDialogState extends State<MovimentacaoDialog> {
  final EstoqueViewModel _vm = Get.find<EstoqueViewModel>();
  final TextEditingController _quantidade = TextEditingController();
  final TextEditingController _observacao = TextEditingController();

  TipoMovimentacao _tipo = TipoMovimentacao.entrada;

  /// Para ajuste: define se o saldo sobe ou desce.
  bool _ajusteNegativo = false;

  String? _erro;

  @override
  void initState() {
    super.initState();
    _vm.carregarHistorico(widget.produto.id);
  }

  @override
  void dispose() {
    _quantidade.dispose();
    _observacao.dispose();
    super.dispose();
  }

  int get _quantidadeInformada => int.tryParse(_quantidade.text) ?? 0;

  /// Saldo previsto, mostrado antes de confirmar — evita ajuste no escuro.
  int get _saldoPrevisto {
    final int q = _quantidadeInformada;
    return switch (_tipo) {
      TipoMovimentacao.entrada => widget.produto.quantidade + q,
      TipoMovimentacao.perda => widget.produto.quantidade - q,
      TipoMovimentacao.ajuste =>
        _ajusteNegativo
            ? widget.produto.quantidade - q
            : widget.produto.quantidade + q,
      TipoMovimentacao.saidaVenda => widget.produto.quantidade,
    };
  }

  Future<void> _confirmar() async {
    final int q = _quantidadeInformada;

    if (q <= 0) {
      setState(() => _erro = 'Informe uma quantidade maior que zero');
      return;
    }
    if (_saldoPrevisto < 0) {
      setState(
        () => _erro =
            'Saldo ficaria negativo (disponivel: ${widget.produto.quantidade})',
      );
      return;
    }

    setState(() => _erro = null);

    final bool ok = await _vm.movimentar(
      produtoId: widget.produto.id,
      tipo: _tipo,
      // Ajuste negativo viaja com sinal; entrada/perda o banco normaliza.
      quantidade: _tipo == TipoMovimentacao.ajuste && _ajusteNegativo ? -q : q,
      observacao: _observacao.text.trim().isEmpty
          ? null
          : _observacao.text.trim(),
    );

    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Movimentar estoque', style: AppTypography.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(widget.produto.nome, style: AppTypography.bodyMedium),
              Text(
                'Saldo atual: ${widget.produto.quantidade} '
                '${widget.produto.unidade}',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapXl,

              Text('Tipo', style: AppTypography.label),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final TipoMovimentacao t in TipoMovimentacao.manuais)
                    ChoiceChip(
                      avatar: Icon(t.icone, size: 16, color: t.cor),
                      label: Text(t.label),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    ),
                ],
              ),

              if (_tipo == TipoMovimentacao.ajuste) ...<Widget>[
                AppSpacing.gapMd,
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Somar'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Subtrair'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: <bool>{_ajusteNegativo},
                  onSelectionChanged: (Set<bool> s) =>
                      setState(() => _ajusteNegativo = s.first),
                ),
              ],

              AppSpacing.gapLg,
              AppTextField.quantidade(
                label: 'Quantidade',
                controller: _quantidade,
                errorText: _erro,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),

              AppSpacing.gapMd,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Saldo apos', style: AppTypography.bodyMedium),
                    Text(
                      '$_saldoPrevisto ${widget.produto.unidade}',
                      style: AppTypography.titleMedium.copyWith(
                        color: _saldoPrevisto <= widget.produto.estoqueMinimo
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.gapLg,
              AppTextField(
                label: 'Observacao (opcional)',
                controller: _observacao,
                hint: 'Compra do mercado, vencimento...',
                maxLines: 2,
              ),

              AppSpacing.gapXl,
              Obx(
                () => AppButton(
                  label: 'Confirmar',
                  icon: Icons.check,
                  size: AppButtonSize.large,
                  expanded: true,
                  loading: _vm.salvando.value,
                  onPressed: _confirmar,
                ),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),

              const Divider(height: AppSpacing.xxl),
              Text('Historico', style: AppTypography.titleMedium),
              AppSpacing.gapSm,
              const _Historico(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Historico extends StatelessWidget {
  const _Historico();

  @override
  Widget build(BuildContext context) {
    final EstoqueViewModel vm = Get.find<EstoqueViewModel>();

    return Obx(() {
      if (vm.historico.isEmpty) {
        return Text(
          'Sem movimentacoes registradas.',
          style: AppTypography.bodySmall,
        );
      }

      return Column(
        children: <Widget>[
          for (final MovimentacaoEstoque m in vm.historico.take(15))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(m.tipo.icone, size: 18, color: m.tipo.cor),
              title: Text(m.tipo.label, style: AppTypography.bodyMedium),
              subtitle: Text(
                '${Datas.dataHora(m.criadoEm)}'
                '${m.usuarioNome == null ? '' : ' - ${m.usuarioNome}'}'
                '${m.observacao == null ? '' : '\n${m.observacao}'}',
                style: AppTypography.bodySmall,
              ),
              trailing: Text(
                '${m.quantidadeFormatada}  (${m.saldoApos})',
                style: AppTypography.money.copyWith(
                  color: m.isEntrada ? AppColors.success : AppColors.danger,
                ),
              ),
            ),
        ],
      );
    });
  }
}

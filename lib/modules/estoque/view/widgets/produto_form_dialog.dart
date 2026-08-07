import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../data/models/produto.dart';
import '../../../../data/services/session_service.dart';
import '../../viewmodel/estoque_viewmodel.dart';

/// Cadastro e edicao de produto.
///
/// `quantidade` so e editavel na **criacao** (estoque inicial). Depois disso,
/// toda mudanca passa por movimentacao, para o livro-razao nao ter buracos.
class ProdutoFormDialog extends StatefulWidget {
  const ProdutoFormDialog({super.key, this.produto});

  /// `null` = novo produto.
  final Produto? produto;

  @override
  State<ProdutoFormDialog> createState() => _ProdutoFormDialogState();
}

class _ProdutoFormDialogState extends State<ProdutoFormDialog> {
  final EstoqueViewModel _vm = Get.find<EstoqueViewModel>();

  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _codigoBarras;
  late final TextEditingController _preco;
  late final TextEditingController _custo;
  late final TextEditingController _unidade;
  late final TextEditingController _quantidade;
  late final TextEditingController _minimo;

  String? _erroNome;
  String? _erroPreco;

  bool get _novo => widget.produto == null;

  @override
  void initState() {
    super.initState();
    final Produto? p = widget.produto;

    _nome = TextEditingController(text: p?.nome ?? '');
    _descricao = TextEditingController(text: p?.descricao ?? '');
    _codigoBarras = TextEditingController(text: p?.codigoBarras ?? '');
    _preco = TextEditingController(
      text: p == null ? '' : Money.plain(p.precoVenda),
    );
    _custo = TextEditingController(text: p == null ? '' : Money.plain(p.custo));
    _unidade = TextEditingController(text: p?.unidade ?? 'un');
    _quantidade = TextEditingController(
      text: p == null ? '0' : '${p.quantidade}',
    );
    _minimo = TextEditingController(text: '${p?.estoqueMinimo ?? 5}');
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nome,
      _descricao,
      _codigoBarras,
      _preco,
      _custo,
      _unidade,
      _quantidade,
      _minimo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    setState(() {
      _erroNome = _nome.text.trim().isEmpty ? 'Informe o nome' : null;
      final double? preco = Money.parse(_preco.text);
      _erroPreco = preco == null || preco <= 0
          ? 'Informe um preco maior que zero'
          : null;
    });
    return _erroNome == null && _erroPreco == null;
  }

  Future<void> _salvar() async {
    if (!_validar()) return;

    final String? ministerioId =
        Get.find<SessionService>().ministerioAtivoId.value;
    if (ministerioId == null) return;

    final Produto produto = Produto(
      id: widget.produto?.id ?? '',
      ministerioId: ministerioId,
      nome: _nome.text.trim(),
      descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
      codigoBarras: _codigoBarras.text.trim().isEmpty
          ? null
          : _codigoBarras.text.trim(),
      precoVenda: Money.parse(_preco.text) ?? 0,
      custo: Money.parse(_custo.text) ?? 0,
      unidade: _unidade.text.trim().isEmpty ? 'un' : _unidade.text.trim(),
      quantidade: _novo ? (int.tryParse(_quantidade.text) ?? 0) : 0,
      estoqueMinimo: int.tryParse(_minimo.text) ?? 5,
    );

    final bool ok = await _vm.salvarProduto(produto, novo: _novo);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _lerCodigoBarras() async {
    final String? codigo = await Get.toNamed<String?>(Rotas.scanner);
    if (codigo != null && codigo.isNotEmpty) {
      setState(() => _codigoBarras.text = codigo);
    }
  }

  Future<void> _desativar() async {
    final bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Desativar produto?'),
        content: const Text(
          'Ele some das telas de venda e estoque, mas continua no historico '
          'de vendas ja registradas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    final bool ok = await _vm.desativarProduto(widget.produto!.id);
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
              Text(
                _novo ? 'Novo produto' : 'Editar produto',
                style: AppTypography.headlineMedium,
              ),
              AppSpacing.gapXl,

              AppTextField(
                label: 'Nome',
                controller: _nome,
                hint: 'Cafe expresso',
                errorText: _erroNome,
                autofocus: true,
              ),
              AppSpacing.gapLg,

              AppTextField(
                label: 'Descricao (opcional)',
                controller: _descricao,
                hint: 'Cafe curto',
              ),
              AppSpacing.gapLg,

              AppTextField(
                label: 'Codigo de barras (opcional)',
                controller: _codigoBarras,
                hint: '7891000100103',
                keyboardType: TextInputType.number,
                suffix: IconButton(
                  tooltip: 'Ler com a camera',
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  onPressed: _lerCodigoBarras,
                ),
              ),
              AppSpacing.gapLg,

              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField.money(
                      label: 'Preco de venda',
                      controller: _preco,
                      errorText: _erroPreco,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField.money(
                      label: 'Custo',
                      controller: _custo,
                      helper: 'Para calcular margem',
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: 'Unidade',
                      controller: _unidade,
                      hint: 'un, fatia, kg',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField.quantidade(
                      label: 'Estoque minimo',
                      controller: _minimo,
                      helper: 'Dispara o alerta',
                    ),
                  ),
                ],
              ),

              if (_novo) ...<Widget>[
                AppSpacing.gapLg,
                AppTextField.quantidade(
                  label: 'Estoque inicial',
                  controller: _quantidade,
                  helper: 'Depois, so muda por movimentacao',
                ),
              ],

              AppSpacing.gapXl,
              Obx(() {
                final falha = _vm.falha.value;
                if (falha == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    falha.mensagem,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                );
              }),

              Obx(
                () => AppButton(
                  label: 'Salvar',
                  icon: Icons.save_outlined,
                  size: AppButtonSize.large,
                  expanded: true,
                  loading: _vm.salvando.value,
                  onPressed: _salvar,
                ),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
              if (!_novo) ...<Widget>[
                AppSpacing.gapSm,
                AppButton(
                  label: 'Desativar produto',
                  icon: Icons.visibility_off_outlined,
                  variant: AppButtonVariant.ghost,
                  expanded: true,
                  onPressed: _desativar,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/enums.dart';

/// Galeria de componentes — **so em dev** (ver `Env.showcaseEnabled`).
///
/// Serve para uma coisa: redimensionar a janela e ver todo o design system
/// reagir aos 4 breakpoints de uma vez. E aqui que se descobre que um botao
/// estourou no celular, antes de descobrir no culto.
///
/// Regra: componente novo em `core/widgets/` **entra aqui**. Se nao esta nesta
/// pagina, ninguem sabe que ele existe e alguem vai duplicar.
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Showcase'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: AppBadge(
                label: context.breakpoint.name.toUpperCase(),
                color: AppColors.brandRose,
                icon: Icons.aspect_ratio,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Secao(
                titulo: 'Breakpoint atual',
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Largura: '
                        '${MediaQuery.sizeOf(context).width.toStringAsFixed(0)}px',
                        style: AppTypography.bodyMedium,
                      ),
                      Text(
                        'Breakpoint: ${context.breakpoint.name}',
                        style: AppTypography.bodyMedium,
                      ),
                      Text(
                        'Escala de texto: ${context.textScale}x',
                        style: AppTypography.bodyMedium,
                      ),
                      AppSpacing.gapMd,
                      Text(
                        'Titulo escalado pelo breakpoint',
                        style: context.scaled(AppTypography.titleLarge),
                      ),
                    ],
                  ),
                ),
              ),

              _Secao(
                titulo: 'Cores da marca',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: const <Widget>[
                    _Swatch('brandBlack', AppColors.brandBlack),
                    _Swatch('brandCream', AppColors.brandCream),
                    _Swatch('brandRose', AppColors.brandRose),
                    _Swatch('brandCoffee', AppColors.brandCoffee),
                    _Swatch('success', AppColors.success),
                    _Swatch('warning', AppColors.warning),
                    _Swatch('danger', AppColors.danger),
                    _Swatch('info', AppColors.info),
                  ],
                ),
              ),

              _Secao(
                titulo: 'Tipografia',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Display Large', style: AppTypography.displayLarge),
                    Text('Headline Large', style: AppTypography.headlineLarge),
                    Text(
                      'Headline Medium',
                      style: AppTypography.headlineMedium,
                    ),
                    Text('Title Large', style: AppTypography.titleLarge),
                    Text('Body Large', style: AppTypography.bodyLarge),
                    Text('Body Small', style: AppTypography.bodySmall),
                    Text('LABEL', style: AppTypography.label),
                  ],
                ),
              ),

              _Secao(
                titulo: 'Botoes',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppButton(label: 'Primario', onPressed: () {}),
                    AppButton(
                      label: 'Secundario',
                      variant: AppButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Perigo',
                      variant: AppButtonVariant.danger,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Ghost',
                      variant: AppButtonVariant.ghost,
                      onPressed: () {},
                    ),
                    const AppButton(label: 'Desabilitado', onPressed: null),
                    AppButton(
                      label: 'Carregando',
                      loading: true,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Grande com icone',
                      icon: Icons.check_circle_outline,
                      size: AppButtonSize.large,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              _Secao(
                titulo: 'Campos',
                child: Column(
                  children: <Widget>[
                    const AppTextField(
                      label: 'Texto',
                      hint: 'Digite algo',
                      prefixIcon: Icons.search,
                    ),
                    AppSpacing.gapLg,
                    AppTextField.money(
                      label: 'Dinheiro (mascara da direita p/ esquerda)',
                      helper: 'Digite 1000 e veja virar 10,00',
                    ),
                    AppSpacing.gapLg,
                    AppTextField.quantidade(label: 'Quantidade'),
                    AppSpacing.gapLg,
                    const AppTextField(
                      label: 'Com erro',
                      errorText: 'Campo obrigatorio',
                    ),
                  ],
                ),
              ),

              _Secao(
                titulo: 'Badges',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppBadge.estoque(quantidade: 20, minimo: 5),
                    AppBadge.estoque(quantidade: 3, minimo: 5),
                    AppBadge.estoque(quantidade: 0, minimo: 5),
                    for (final TipoVenda t in TipoVenda.values)
                      AppBadge(label: t.label, color: t.cor, icon: t.icone),
                    const CountBadge(count: 3),
                    const CountBadge(count: 128),
                  ],
                ),
              ),

              _Secao(
                titulo: 'Dinheiro',
                child: Column(
                  children: const <Widget>[
                    MoneyText(1234.5, large: true),
                    MoneyText(1234.5),
                    MoneyText(1234.5, compact: true),
                    AppSpacing.gapMd,
                    MoneyLabelValue(label: 'Subtotal', value: 42),
                    MoneyLabelValue(label: 'Total', value: 42, emphasis: true),
                  ],
                ),
              ),

              _Secao(
                titulo: 'ResponsiveGrid (2/3/4/5 colunas)',
                child: ResponsiveGrid(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (int i = 1; i <= 8; i++)
                      AppCard(
                        child: Center(
                          child: Text('$i', style: AppTypography.titleLarge),
                        ),
                      ),
                  ],
                ),
              ),

              _Secao(
                titulo: 'ResponsiveRow (empilha no mobile)',
                child: ResponsiveRow(
                  flex: const <int>[2, 1],
                  children: <Widget>[
                    AppCard(
                      child: Text('Principal', style: AppTypography.bodyMedium),
                    ),
                    AppCard(
                      child: Text('Lateral', style: AppTypography.bodyMedium),
                    ),
                  ],
                ),
              ),

              // Altura fixa fica em CADA card, nao na linha: quando a
              // ResponsiveRow empilha no mobile, uma altura unica de 260px
              // teria que caber os tres cards e estouraria o layout.
              _Secao(
                titulo: 'Estados',
                child: ResponsiveRow(
                  children: <Widget>[
                    const SizedBox(
                      height: 300,
                      child: AppCard(child: AppLoading(mensagem: 'Carregando')),
                    ),
                    const SizedBox(
                      height: 300,
                      child: AppCard(
                        child: EmptyState(
                          titulo: 'Vazio',
                          descricao: 'Nada por aqui.',
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: AppCard(
                        child: EmptyState.erro(
                          const AppFailure.rede(),
                          onTentarDeNovo: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.gapXxl,
            ],
          ),
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(titulo, style: AppTypography.headlineMedium),
          const Divider(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.nome, this.cor);

  final String nome;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 48,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: AppRadius.brSm,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 72,
          child: Text(
            nome,
            style: AppTypography.bodySmall.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

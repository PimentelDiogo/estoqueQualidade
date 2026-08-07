import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Os quatro contextos reais de uso do sistema.
///
/// Portado do padrao do projeto `englishIA` (`AppBreakpoints`), com o breakpoint
/// extra de [tv] — a fila de pedidos projetada no salao.
enum Breakpoint {
  /// Voluntario no celular durante o culto. **Este e o alvo principal.**
  mobile,

  /// Caixa em tablet — cabe lista de produtos + carrinho lado a lado.
  tablet,

  /// Painel do administrador / relatorios.
  desktop,

  /// Fila de pedidos na TV do salao. Sem interacao, tipografia ampliada.
  tv,
}

/// Limites em largura logica. Unico lugar do app onde estes numeros existem.
abstract final class AppBreakpoints {
  static const double tablet = 768;
  static const double desktop = 1280;
  static const double tv = 1920;

  static Breakpoint of(double width) {
    if (width >= tv) return Breakpoint.tv;
    if (width >= desktop) return Breakpoint.desktop;
    if (width >= tablet) return Breakpoint.tablet;
    return Breakpoint.mobile;
  }
}

extension BreakpointContext on BuildContext {
  /// Breakpoint atual. **Unica** forma permitida de uma tela reagir a largura —
  /// ler `MediaQuery.sizeOf(context).width` direto na View e proibido.
  Breakpoint get breakpoint => AppBreakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isMobile => breakpoint == Breakpoint.mobile;
  bool get isTablet => breakpoint == Breakpoint.tablet;
  bool get isDesktop => breakpoint == Breakpoint.desktop;
  bool get isTv => breakpoint == Breakpoint.tv;

  /// Verdadeiro de tablet para cima — o caso mais comum de decisao de layout
  /// ("lado a lado" vs "empilhado").
  bool get isWide => breakpoint != Breakpoint.mobile;
}

/// Valor que muda por breakpoint, sem `if` espalhado na View.
///
/// Cada breakpoint nao informado cai para o anterior menor, entao
/// `ResponsiveValue(mobile: 1, desktop: 3)` da 1 no tablet e 3 na TV.
///
/// ```dart
/// final colunas = const ResponsiveValue<int>(mobile: 1, tablet: 2, desktop: 3)
///     .resolve(context);
/// ```
@immutable
class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.tv,
  });

  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? tv;

  T resolve(BuildContext context) => resolveFor(context.breakpoint);

  T resolveFor(Breakpoint breakpoint) => switch (breakpoint) {
    Breakpoint.mobile => mobile,
    Breakpoint.tablet => tablet ?? mobile,
    Breakpoint.desktop => desktop ?? tablet ?? mobile,
    Breakpoint.tv => tv ?? desktop ?? tablet ?? mobile,
  };
}

/// Constroi um widget diferente por breakpoint.
///
/// Use apenas quando o layout muda de **estrutura** (ex.: bottom bar vs rail).
/// Para variar so um numero, prefira [ResponsiveValue] — e mais barato.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    super.key,
    this.tablet,
    this.desktop,
    this.tv,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? tv;

  @override
  Widget build(BuildContext context) {
    final WidgetBuilder builder = switch (context.breakpoint) {
      Breakpoint.mobile => mobile,
      Breakpoint.tablet => tablet ?? mobile,
      Breakpoint.desktop => desktop ?? tablet ?? mobile,
      Breakpoint.tv => tv ?? desktop ?? tablet ?? mobile,
    };
    return builder(context);
  }
}

/// Corpo padrao de tela: centraliza, limita a largura de leitura e aplica o
/// padding do breakpoint. Toda pagina do app deve envolver seu conteudo nisto.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    required this.child,
    super.key,
    this.maxWidth,
    this.padding,
    this.scrollable = false,
  });

  final Widget child;

  /// Largura maxima do conteudo. Sem isto, um relatorio em monitor ultrawide
  /// vira uma linha de texto de 2000px, ilegivel.
  final ResponsiveValue<double>? maxWidth;

  final ResponsiveValue<EdgeInsets>? padding;

  /// Envolve em scroll vertical — util em formularios que estouram no mobile.
  final bool scrollable;

  static const ResponsiveValue<double> _defaultMaxWidth =
      ResponsiveValue<double>(
        mobile: double.infinity,
        tablet: 900,
        desktop: 1200,
        tv: 1600,
      );

  static const ResponsiveValue<EdgeInsets> _defaultPadding =
      ResponsiveValue<EdgeInsets>(
        mobile: EdgeInsets.all(AppSpacing.lg),
        tablet: EdgeInsets.all(AppSpacing.xl),
        desktop: EdgeInsets.all(AppSpacing.xxl),
        tv: EdgeInsets.all(AppSpacing.xxxl),
      );

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: (padding ?? _defaultPadding).resolve(context),
      child: child,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (maxWidth ?? _defaultMaxWidth).resolve(context),
        ),
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

/// Grade com numero de colunas por breakpoint.
///
/// Usada na lista de produtos do PDV e nos cards de relatorio.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    super.key,
    this.columns,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
    this.childAspectRatio,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<Widget> children;
  final ResponsiveValue<int>? columns;
  final double spacing;
  final double runSpacing;
  final ResponsiveValue<double>? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  static const ResponsiveValue<int> _defaultColumns = ResponsiveValue<int>(
    mobile: 2,
    tablet: 3,
    desktop: 4,
    tv: 5,
  );

  static const ResponsiveValue<double> _defaultRatio = ResponsiveValue<double>(
    mobile: 1.1,
    tablet: 1.2,
    desktop: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: EdgeInsets.zero,
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (columns ?? _defaultColumns).resolve(context),
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: (childAspectRatio ?? _defaultRatio).resolve(context),
      ),
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

/// Linha que vira coluna no mobile.
///
/// O caso classico do PDV: no tablet, produtos a esquerda e carrinho a direita;
/// no celular, um embaixo do outro.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    required this.children,
    super.key,
    this.flex,
    this.spacing = AppSpacing.lg,
    this.stackBelow = Breakpoint.tablet,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;

  /// Peso de cada filho quando em linha. Ignorado ao empilhar.
  final List<int>? flex;
  final double spacing;

  /// Abaixo deste breakpoint, empilha em coluna.
  final Breakpoint stackBelow;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final bool stack = context.breakpoint.index < stackBelow.index;

    if (stack) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: spacing),
          Expanded(
            flex: flex != null && i < flex!.length ? flex![i] : 1,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// Escala de tipografia por breakpoint.
///
/// Na TV tudo cresce ~1.8x porque a leitura acontece a varios metros de distancia.
extension ResponsiveTextScale on BuildContext {
  double get textScale => switch (breakpoint) {
    Breakpoint.mobile => 1,
    Breakpoint.tablet => 1.05,
    Breakpoint.desktop => 1.1,
    Breakpoint.tv => 1.8,
  };

  /// Aplica a escala do breakpoint a um estilo do tema.
  TextStyle scaled(TextStyle style) =>
      style.copyWith(fontSize: (style.fontSize ?? 14) * textScale);
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/enums.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/session_service.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_badge.dart';
import 'responsive_layout.dart';

/// Um destino do menu principal.
class DestinoNav {
  const DestinoNav({
    required this.rota,
    required this.label,
    required this.icone,
    required this.iconeSelecionado,
    required this.papeis,
  });

  final String rota;
  final String label;
  final IconData icone;
  final IconData iconeSelecionado;

  /// Papeis que enxergam este destino.
  final Set<PapelUsuario> papeis;
}

/// Casca de navegacao do app.
///
/// Muda de **estrutura** por breakpoint — este e exatamente o caso de uso do
/// [ResponsiveLayout]: barra inferior no celular (polegar alcanca), rail lateral
/// no tablet/desktop (aproveita a largura sem roubar altura da lista).
class AppShell extends StatelessWidget {
  const AppShell({
    required this.child,
    required this.rotaAtual,
    super.key,
    this.alertasAbertos = 0,
  });

  final Widget child;
  final String rotaAtual;

  /// Contador do badge de estoque baixo — o aviso que motivou o sistema.
  final int alertasAbertos;

  static const List<DestinoNav> destinos = <DestinoNav>[
    DestinoNav(
      rota: Rotas.pdv,
      label: 'Caixa',
      icone: Icons.point_of_sale_outlined,
      iconeSelecionado: Icons.point_of_sale,
      papeis: <PapelUsuario>{PapelUsuario.admin, PapelUsuario.caixa},
    ),
    DestinoNav(
      rota: Rotas.pedidos,
      label: 'Pedidos',
      icone: Icons.receipt_long_outlined,
      iconeSelecionado: Icons.receipt_long,
      papeis: <PapelUsuario>{PapelUsuario.admin, PapelUsuario.caixa},
    ),
    DestinoNav(
      rota: Rotas.estoque,
      label: 'Estoque',
      icone: Icons.inventory_2_outlined,
      iconeSelecionado: Icons.inventory_2,
      papeis: <PapelUsuario>{PapelUsuario.admin, PapelUsuario.caixa},
    ),
    DestinoNav(
      rota: Rotas.alertas,
      label: 'Alertas',
      icone: Icons.notifications_outlined,
      iconeSelecionado: Icons.notifications,
      papeis: <PapelUsuario>{PapelUsuario.admin, PapelUsuario.caixa},
    ),
    DestinoNav(
      rota: Rotas.relatorios,
      label: 'Relatorios',
      icone: Icons.bar_chart_outlined,
      iconeSelecionado: Icons.bar_chart,
      papeis: <PapelUsuario>{PapelUsuario.admin, PapelUsuario.caixa},
    ),
    DestinoNav(
      rota: Rotas.ministerios,
      label: 'Ministerios',
      icone: Icons.groups_outlined,
      iconeSelecionado: Icons.groups,
      papeis: <PapelUsuario>{PapelUsuario.admin},
    ),
  ];

  List<DestinoNav> _destinosVisiveis(PapelUsuario? papel) {
    if (papel == null) return const <DestinoNav>[];
    return destinos
        .where((DestinoNav d) => d.papeis.contains(papel))
        .toList(growable: false);
  }

  void _navegar(String rota) {
    if (rota == rotaAtual) return;
    Get.offAllNamed<void>(rota);
  }

  @override
  Widget build(BuildContext context) {
    final AuthService auth = Get.find<AuthService>();

    return Obx(() {
      final List<DestinoNav> visiveis = _destinosVisiveis(
        auth.perfil.value?.papel,
      );

      final int indiceAtual = visiveis.indexWhere(
        (DestinoNav d) => rotaAtual.startsWith(d.rota),
      );

      return ResponsiveLayout(
        mobile: (_) => _ComBarraInferior(
          destinos: visiveis,
          indiceAtual: indiceAtual,
          alertasAbertos: alertasAbertos,
          onSelecionar: _navegar,
          child: child,
        ),
        tablet: (_) => _ComRail(
          destinos: visiveis,
          indiceAtual: indiceAtual,
          alertasAbertos: alertasAbertos,
          onSelecionar: _navegar,
          estendido: false,
          child: child,
        ),
        desktop: (_) => _ComRail(
          destinos: visiveis,
          indiceAtual: indiceAtual,
          alertasAbertos: alertasAbertos,
          onSelecionar: _navegar,
          estendido: true,
          child: child,
        ),
      );
    });
  }
}

class _ComBarraInferior extends StatelessWidget {
  const _ComBarraInferior({
    required this.child,
    required this.destinos,
    required this.indiceAtual,
    required this.alertasAbertos,
    required this.onSelecionar,
  });

  final Widget child;
  final List<DestinoNav> destinos;
  final int indiceAtual;
  final int alertasAbertos;
  final ValueChanged<String> onSelecionar;

  @override
  Widget build(BuildContext context) {
    if (destinos.isEmpty) return child;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceAtual < 0 ? 0 : indiceAtual,
        onDestinationSelected: (int i) => onSelecionar(destinos[i].rota),
        destinations: <Widget>[
          for (final DestinoNav d in destinos)
            NavigationDestination(
              icon: _IconeComBadge(
                icone: d.icone,
                mostrarBadge: d.rota == Rotas.alertas,
                contador: alertasAbertos,
              ),
              selectedIcon: _IconeComBadge(
                icone: d.iconeSelecionado,
                mostrarBadge: d.rota == Rotas.alertas,
                contador: alertasAbertos,
              ),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _ComRail extends StatelessWidget {
  const _ComRail({
    required this.child,
    required this.destinos,
    required this.indiceAtual,
    required this.alertasAbertos,
    required this.onSelecionar,
    required this.estendido,
  });

  final Widget child;
  final List<DestinoNav> destinos;
  final int indiceAtual;
  final int alertasAbertos;
  final ValueChanged<String> onSelecionar;

  /// `true` mostra o rotulo ao lado do icone (espaco sobrando no desktop).
  final bool estendido;

  @override
  Widget build(BuildContext context) {
    if (destinos.isEmpty) return child;

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: indiceAtual < 0 ? 0 : indiceAtual,
            onDestinationSelected: (int i) => onSelecionar(destinos[i].rota),
            extended: estendido,
            minExtendedWidth: 200,
            labelType: estendido
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Icon(
                Icons.coffee_outlined,
                color: AppColors.brandCream,
                size: 28,
              ),
            ),
            trailing: const Expanded(child: _RodapeRail()),
            destinations: <NavigationRailDestination>[
              for (final DestinoNav d in destinos)
                NavigationRailDestination(
                  icon: _IconeComBadge(
                    icone: d.icone,
                    mostrarBadge: d.rota == Rotas.alertas,
                    contador: alertasAbertos,
                  ),
                  selectedIcon: _IconeComBadge(
                    icone: d.iconeSelecionado,
                    mostrarBadge: d.rota == Rotas.alertas,
                    contador: alertasAbertos,
                  ),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Identificacao de quem esta operando + sair. Fica no fim do rail para o
/// voluntario conferir que nao esta usando a conta de outro.
class _RodapeRail extends StatelessWidget {
  const _RodapeRail();

  @override
  Widget build(BuildContext context) {
    final SessionService session = Get.find<SessionService>();
    final AuthService auth = Get.find<AuthService>();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Obx(
              () => Tooltip(
                message: session.descricaoContexto,
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () async {
                await auth.sair();
                await Get.offAllNamed<void>(Rotas.login);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconeComBadge extends StatelessWidget {
  const _IconeComBadge({
    required this.icone,
    required this.mostrarBadge,
    required this.contador,
  });

  final IconData icone;
  final bool mostrarBadge;
  final int contador;

  @override
  Widget build(BuildContext context) {
    if (!mostrarBadge || contador <= 0) return Icon(icone);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icone),
        Positioned(top: -6, right: -8, child: CountBadge(count: contador)),
      ],
    );
  }
}

/// Cabecalho reutilizavel que mostra o ministerio em foco.
///
/// Existe porque registrar venda no ministerio errado e o erro mais caro do
/// sistema — e o mais facil de cometer quando o admin opera varios.
class ContextoMinisterio extends StatelessWidget {
  const ContextoMinisterio({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionService session = Get.find<SessionService>();

    return Obx(() {
      final String? nome = session.ministerioAtivoNome.value;
      if (nome == null) return const SizedBox.shrink();

      return InkWell(
        onTap: session.podeTrocarMinisterio
            ? () => Get.toNamed<void>(Rotas.escolherMinisterio)
            : null,
        borderRadius: AppRadius.brPill,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.brPill,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.storefront_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(nome, style: AppTypography.bodySmall),
              if (session.podeTrocarMinisterio) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.expand_more,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

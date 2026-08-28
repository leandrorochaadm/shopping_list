import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/core/widgets/under_construction_screen.dart';
import 'routes.dart';

/// The eleven routes of `tecnico §3.4`, registered from day one.
///
/// Screens not written yet point at [UnderConstructionScreen]: each story
/// swaps one entry for the real screen, so no story ever has to invent a route
/// and no link lands on a route that does not exist.
///
/// **No route is protected** — there is no session to protect. The single
/// `redirect` this app will have is not about identity either: while the
/// device user label is not in Hive, every route falls to [Routes.welcome].
/// It arrives with H1, together with the label itself.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.shoppingList,
    routes: [
      GoRoute(
        path: Routes.shoppingList,
        name: RouteNames.shoppingList,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Lista de compras',
          story: 'H4',
        ),
      ),
      GoRoute(
        path: Routes.welcome,
        name: RouteNames.welcome,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Quem está usando?',
          story: 'H1',
        ),
      ),
      GoRoute(
        path: Routes.suggestions,
        name: RouteNames.suggestions,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Sugestão de itens',
          story: 'H17',
        ),
      ),
      // Declared BEFORE the ':id' route below, because go_router matches in
      // order. Today the two cannot collide — '/purchases/new' has two
      // segments and '/purchases/:id/edit' has three — but the day a plain
      // '/purchases/:id' route exists, 'new' would be read as an id. The order
      // is the guard for that day, and router_test holds it.
      GoRoute(
        path: Routes.newPurchase,
        name: RouteNames.newPurchase,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Lançar compra', story: 'H7'),
      ),
      GoRoute(
        path: Routes.editPurchase,
        name: RouteNames.editPurchase,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Corrigir compra',
          story: 'H9',
        ),
      ),
      GoRoute(
        path: Routes.purchaseHistory,
        name: RouteNames.purchaseHistory,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Histórico de compras',
          story: 'H9',
        ),
      ),
      GoRoute(
        path: Routes.newProduct,
        name: RouteNames.newProduct,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Novo produto', story: 'H2'),
      ),
      GoRoute(
        path: Routes.reports,
        name: RouteNames.reports,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Relatórios', story: 'H11'),
      ),
      GoRoute(
        path: Routes.remainingThisMonth,
        name: RouteNames.remainingThisMonth,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Falta comprar este mês',
          story: 'H18',
        ),
      ),
      GoRoute(
        path: Routes.catalog,
        name: RouteNames.catalog,
        builder: (context, state) => const UnderConstructionScreen(
          title: 'Manutenção do cadastro',
          story: 'H10',
        ),
      ),
      GoRoute(
        path: Routes.settings,
        name: RouteNames.settings,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Configurações', story: 'H13'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/device_user/device_user_repository.dart';
import '../ui/catalog/widgets/catalog_maintenance_screen.dart';
import '../ui/catalog/widgets/new_product_screen.dart';
import '../ui/consumption/widgets/remaining_screen.dart';
import '../ui/consumption/widgets/suggestions_screen.dart';
import '../ui/device_user/widgets/welcome_screen.dart';
import '../ui/purchase/widgets/edit_purchase_screen.dart';
import '../ui/purchase/widgets/new_purchase_screen.dart';
import '../ui/purchase/widgets/purchase_history_screen.dart';
import '../ui/report/widgets/reports_screen.dart';
import '../ui/settings/widgets/settings_screen.dart';
import '../ui/shopping_list/widgets/shopping_list_screen.dart';
import '../ui/spike/widgets/typing_spike_screen.dart';
import 'routes.dart';

/// The eleven routes of `tecnico §3.4`, registered from day one.
///
/// **Since H17/H18 all eleven have a screen.** Until then the ones not written
/// yet pointed at an `UnderConstructionScreen`, so no story ever had to invent
/// a route and no link landed on a route that did not exist. That screen and
/// the `pendingDestinations` map beside it were deleted along with the last
/// two entries of this file.
///
/// **No route is protected** — there is no session to protect. The single
/// `redirect` this app has is not about identity either: while the device
/// user label is not in Hive, every route falls to [Routes.welcome].
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.shoppingList,
    // go_router runs this SYNCHRONOUSLY, which is why the Hive box is opened
    // by `main` before runApp: after that, reading the label costs nothing.
    //
    // `ref.read`, never `ref.watch`: watching would rebuild this provider on
    // every label change, and rebuilding the provider throws the whole
    // navigation stack away under the user's finger.
    redirect: (context, state) {
      // Without this guard /welcome redirects to /welcome and the screen
      // never opens — a loop whose symptom points at nothing.
      if (state.matchedLocation == Routes.welcome) return null;

      // The S1 spike measures typing, not the app: sending it through the
      // welcome screen would add a question to a stopwatch run. Goes away
      // with the route.
      if (state.matchedLocation == Routes.typingSpike) return null;

      return ref.read(storedDeviceUserProvider) == null ? Routes.welcome : null;
    },
    routes: [
      GoRoute(
        path: Routes.shoppingList,
        name: RouteNames.shoppingList,
        builder: (context, state) => const ShoppingListScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        name: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.suggestions,
        name: RouteNames.suggestions,
        // Screen 1 opens it with `push`, never `go`: the routes are flat, and
        // the wireframe sends this one BACK to the list — with `go` there
        // would be no stack to pop.
        builder: (context, state) => const SuggestionsScreen(),
      ),
      // Declared BEFORE the ':id' route below, because go_router matches in
      // order. Today the two cannot collide — '/purchases/new' has two
      // segments and '/purchases/:id/edit' has three — but the day a plain
      // '/purchases/:id' route exists, 'new' would be read as an id. The order
      // is the guard for that day, and router_test holds it.
      GoRoute(
        path: Routes.newPurchase,
        name: RouteNames.newPurchase,
        builder: (context, state) => const NewPurchaseScreen(),
      ),
      GoRoute(
        path: Routes.editPurchase,
        name: RouteNames.editPurchase,
        builder: (context, state) =>
            EditPurchaseScreen(purchaseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.purchaseHistory,
        name: RouteNames.purchaseHistory,
        builder: (context, state) => const PurchaseHistoryScreen(),
      ),
      GoRoute(
        path: Routes.newProduct,
        name: RouteNames.newProduct,
        // The `extra` says what was asked of screen 4: screen 3 asks for
        // the chosen leaf BACK instead of a navigation to the list, and the
        // catalog maintenance says WHICH registration to open. Whoever
        // arrives from the menu passes nothing and falls to the default.
        builder: (context, state) {
          final request =
              state.extra as NewProductRequest? ?? const NewProductRequest();
          return NewProductScreen(
            returnsSelection: request.returnsSelection,
            registrationId: request.registrationId,
          );
        },
      ),
      GoRoute(
        path: Routes.reports,
        name: RouteNames.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: Routes.remainingThisMonth,
        name: RouteNames.remainingThisMonth,
        // The third permanent destination of the bottom bar, and the bar
        // reaches it with `go`: switching between the three is not going back,
        // so it carries no Back button.
        builder: (context, state) => const RemainingScreen(),
      ),
      GoRoute(
        path: Routes.catalog,
        name: RouteNames.catalog,
        builder: (context, state) => const CatalogMaintenanceScreen(),
      ),
      // Minimal for now — only the device user label, which is an acceptance
      // criterion of H1. The spending cap arrives with H13.
      GoRoute(
        path: Routes.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // The twelfth route, and the only one that is not one of the eleven
      // screens of `tecnico §3.4`: the S1 typing spike. It is registered here
      // because the measurement has to happen on the installed PWA, and
      // getting there is one tap on an address — a --dart-define would have
      // meant a separate build just to measure. **Deleted with the screen.**
      GoRoute(
        path: Routes.typingSpike,
        name: RouteNames.typingSpike,
        builder: (context, state) => const TypingSpikeScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

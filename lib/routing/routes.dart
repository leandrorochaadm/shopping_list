/// Every screen of the app has a named route — the eleven of `tecnico §3.4`,
/// not only the six the wireframes drew.
///
/// Paths are identifiers, so they are in English. What the user reads is the
/// screen title, which is pt-BR.
abstract final class Routes {
  /// Screen 1, the home of the bottom bar.
  static const shoppingList = '/';

  /// Asks who is using the device. Shown once per device, before anything else.
  static const welcome = '/welcome';

  /// Screen 2 — suggests items from the last months of consumption.
  static const suggestions = '/suggestions';

  /// Screen 3 — registering a purchase.
  static const newPurchase = '/purchases/new';

  /// Behind the `≡` menu: the purchases already registered, and who
  /// registered each one. The only paginated screen.
  static const purchaseHistory = '/purchases';

  /// Behind the `≡` menu: correcting or deleting one purchase.
  static const editPurchase = '/purchases/:id/edit';

  /// Screen 4 — reached from the `[+Novo]` of screen 3 and from the catalog.
  static const newProduct = '/products/new';

  /// Screen 5 — spending and consumption over a free period.
  static const reports = '/reports';

  /// Screen 6 — what is still missing this month.
  static const remainingThisMonth = '/remaining';

  /// Behind the `≡` menu: rename, reclassify, deactivate and reactivate.
  static const catalog = '/catalog';

  /// Behind the `≡` menu: the monthly spending cap and the device user.
  static const settings = '/settings';

  /// **Throwaway — spike S1.** Reached by typing the address on the phone, so
  /// the measurement happens on the installed PWA and not in a tab. Deleted
  /// with the screen once A2 is answered.
  static const typingSpike = '/spike';
}

/// Route names, used by `context.goNamed` so a path change never has to be
/// hunted down across screens.
abstract final class RouteNames {
  static const shoppingList = 'shoppingList';
  static const welcome = 'welcome';
  static const suggestions = 'suggestions';
  static const newPurchase = 'newPurchase';
  static const purchaseHistory = 'purchaseHistory';
  static const editPurchase = 'editPurchase';
  static const newProduct = 'newProduct';
  static const reports = 'reports';
  static const remainingThisMonth = 'remainingThisMonth';
  static const catalog = 'catalog';
  static const settings = 'settings';

  /// Throwaway — see [Routes.typingSpike].
  static const typingSpike = 'typingSpike';
}

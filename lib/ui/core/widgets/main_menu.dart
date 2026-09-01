import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'main_bottom_bar.dart';
import 'menu_entry.dart';

/// The `≡` — and, as the `handoff` put it, "a única porta das quatro telas não
/// desenhadas". Without it being born on screen 1 they would have had no door
/// at all, and the only way in would have been typing the route. Since H18 all
/// four exist, so every entry here simply navigates.
///
/// **Since 01/09/2026 it has a FOURTH door, and it is not one of those four
/// screens**: `Lançar compra`. Screen 3 was drawn in the wireframe and was
/// never a pending destination — what it did not have was a door outside
/// screen 1's footer, so registering a purchase forced a stop at the list.
/// The bottom bar could not take it: it is frozen at three permanent
/// destinations (`wireframes §327`), and a fourth destination there would
/// pull screen 3 into the trio, giving it a bar AND a `< Voltar` — which
/// `wireframes §330` forbids. Decision I-a.
///
/// It is the FIRST entry because it is the most frequent action of the three
/// screens that mount this menu, and screen 1 keeps its footer button beside
/// it: hiding one of the two would cost this menu a `current` parameter, like
/// [MainBottomBar] has, to erase a line that does not get in the way
/// (decision I-b).
///
/// It lives in `ui/core/` and not in `ui/shopping_list/`, for the same reason
/// [MainBottomBar] does: the wireframe draws this same `≡` in the header of
/// screen 5, and a second copy of it is where two different menus begin. It
/// can live here because it only depends on `routing/` and on `core` itself —
/// the `👤` dialog beside it cannot, and that is why it went to
/// `ui/device_user/` instead.
///
/// **"Corrigir compra" is not one of the doors**, and it did not become
/// enabled either: `/purchases/:id/edit` does not navigate without an id, and
/// the only screen that knows which id is the history — one line above it.
abstract final class MainMenu {
  static const _entries = <MenuEntry>[
    MenuEntry(
      route: Routes.newPurchase,
      icon: Icons.add_shopping_cart,
      label: 'Lançar compra',
    ),
    MenuEntry(
      route: Routes.purchaseHistory,
      icon: Icons.receipt_long,
      label: 'Histórico de compras',
    ),
    MenuEntry(
      route: Routes.catalog,
      icon: Icons.inventory_2_outlined,
      label: 'Manutenção do cadastro',
    ),
    MenuEntry(
      route: Routes.settings,
      icon: Icons.settings_outlined,
      label: 'Configurações',
    ),
  ];

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _entries)
            ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.label),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(entry.route);
              },
            ),
        ],
      ),
    ),
  );
}

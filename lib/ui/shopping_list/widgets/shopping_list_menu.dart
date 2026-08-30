import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/menu_entry.dart';
import '../../core/widgets/pending_destinations.dart';

/// The `≡` of screen 1 — and, as the `handoff` puts it, "a única porta das
/// quatro telas não desenhadas". Without it being born here they would have no
/// door at all, and the only way in would be typing the route.
///
/// **"Corrigir compra" is not one of them any more**, and it did not become
/// enabled either: `/purchases/:id/edit` does not navigate without an id, and
/// the only screen that knows which id is the history — one line above it.
abstract final class ShoppingListMenu {
  static const _entries = <MenuEntry>[
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

  static Future<void> show(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _entries)
                ListTile(
                  leading: Icon(
                    entry.icon,
                    color: isPending(entry.route)
                        ? Theme.of(sheetContext).disabledColor
                        : null,
                  ),
                  title: Text(entry.label),
                  subtitle: pendingDestinations[entry.route] == null
                      ? null
                      // Explained right there, rather than only after a tap.
                      : Text(pendingDestinations[entry.route]!),
                  onTap: () {
                    final pending = pendingDestinations[entry.route];
                    Navigator.of(sheetContext).pop();
                    if (pending != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(pending)));
                      return;
                    }
                    context.go(entry.route);
                  },
                ),
            ],
          ),
        ),
      );
}

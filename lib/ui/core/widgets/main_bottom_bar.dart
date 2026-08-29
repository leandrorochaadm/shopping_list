import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'menu_entry.dart';
import 'pending_destinations.dart';

/// The three permanent destinations of the wireframe's bottom bar.
///
/// It lives in `ui/core/` and not in `ui/shopping_list/`: screens 5 and 6 show
/// the same bar, and a second copy of it is where two different bars begin.
class MainBottomBar extends StatelessWidget {
  const MainBottomBar({required this.current, super.key});

  /// The route being shown, so the bar can mark its own destination.
  final String current;

  static const _destinations = <MenuEntry>[
    MenuEntry(route: Routes.shoppingList, icon: Icons.checklist, label: 'Lista'),
    MenuEntry(
      route: Routes.remainingThisMonth,
      icon: Icons.event_note,
      label: 'Falta',
    ),
    MenuEntry(
      route: Routes.reports,
      icon: Icons.bar_chart,
      label: 'Relatórios',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final disabled = Theme.of(context).disabledColor;
    final index = _destinations.indexWhere((d) => d.route == current);

    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (selected) {
        final route = _destinations[selected].route;
        final pending = pendingDestinations[route];
        if (pending != null) {
          // Never a tap that does nothing and does not say why.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(pending)));
          return;
        }
        if (route != current) context.go(route);
      },
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            // Greyed out, but NOT `enabled: false`: a disabled destination
            // swallows the tap, and a tap that does nothing and does not say
            // why is exactly what the `handoff` forbids. The grey says "not
            // yet"; the SnackBar above says which story brings it.
            icon: Icon(
              destination.icon,
              color: isPending(destination.route) ? disabled : null,
            ),
            label: destination.label,
            // Also the semantic label, so a screen reader does not have to
            // discover it by tapping.
            tooltip:
                pendingDestinations[destination.route] ?? destination.label,
          ),
      ],
    );
  }
}

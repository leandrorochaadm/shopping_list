import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'menu_entry.dart';

/// The three permanent destinations of the wireframe's bottom bar.
///
/// It lives in `ui/core/` and not in `ui/shopping_list/`: screens 5 and 6 show
/// the same bar, and a second copy of it is where two different bars begin.
class MainBottomBar extends StatelessWidget {
  const MainBottomBar({required this.current, super.key});

  /// The route being shown, so the bar can mark its own destination.
  final String current;

  static const _destinations = <MenuEntry>[
    MenuEntry(
      route: Routes.shoppingList,
      icon: Icons.checklist,
      label: 'Lista',
    ),
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
    final index = _destinations.indexWhere((d) => d.route == current);

    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (selected) {
        final route = _destinations[selected].route;
        // Since H18 all three destinations have a screen, so there is no arm
        // left that greys one out and explains which story brings it — the map
        // that held those sentences was deleted with its last entry.
        if (route != current) context.go(route);
      },
      destinations: [
        for (final destination in _destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            label: destination.label,
            // Also the semantic label, so a screen reader does not have to
            // discover it by tapping.
            tooltip: destination.label,
          ),
      ],
    );
  }
}

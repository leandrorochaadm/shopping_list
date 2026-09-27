import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'menu_entry.dart';

/// The three permanent destinations of the wireframe's bottom bar, with the
/// `Lançar compra` button in the middle of them.
///
/// It lives in `ui/core/` and not in `ui/shopping_list/`: screens 2 and 5 show
/// the same bar, and a second copy of it is where two different bars begin.
///
/// The middle button is an ACTION, not a fourth destination (decision I-d):
/// screen 3 does not join the trio, so it keeps its `< Voltar` and no bar,
/// which is what decision I-a protects. That is also why this is not a
/// `NavigationBar` — it has no slot for something that is not a destination,
/// and a placeholder destination under the button would still be read aloud.
class MainBottomBar extends StatelessWidget {
  const MainBottomBar({required this.current, super.key});

  /// The route being shown, so the bar can mark its own destination.
  final String current;

  /// Two on the left and one on the right: the halves are the same width, so
  /// the button sits in the exact centre of the bar.
  static const _leftDestinations = <MenuEntry>[
    MenuEntry(
      route: Routes.shoppingList,
      icon: Icons.checklist,
      label: 'Lista',
    ),
    MenuEntry(
      route: Routes.suggestions,
      icon: Icons.fact_check_outlined,
      label: 'Despensa',
    ),
  ];

  static const _rightDestinations = <MenuEntry>[
    MenuEntry(
      route: Routes.reports,
      icon: Icons.bar_chart,
      label: 'Relatórios',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget destination(MenuEntry entry) => Expanded(
      child: _Destination(
        entry: entry,
        selected: entry.route == current,
        // A control that goes where you already are does nothing.
        onTap: () {
          if (entry.route != current) context.go(entry.route);
        },
      ),
    );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (final entry in _leftDestinations) destination(entry),
                  ],
                ),
              ),
              const _NewPurchaseButton(),
              Expanded(
                child: Row(
                  children: [
                    for (final entry in _rightDestinations) destination(entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination, drawn like a Material 3 `NavigationDestination`: the
/// pill behind the icon marks the screen on display.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final MenuEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      // Also the semantic label, so a screen reader does not have to discover
      // it by tapping.
      child: Tooltip(
        message: entry.label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  entry.icon,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round button in the middle of the bar.
///
/// `go` and not `push`: registering a purchase ENDS on the list — screen 3
/// goes back there by itself once it saves, whichever screen opened it
/// (decision I-c) — so there is no stack worth keeping.
class _NewPurchaseButton extends StatelessWidget {
  const _NewPurchaseButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            key: const ValueKey('new-purchase'),
            // Screens 1, 2 and 5 each mount this button, and `go` animates
            // one into the other: a shared default hero tag would fly it.
            heroTag: null,
            elevation: 2,
            tooltip: 'Lançar compra',
            onPressed: () => context.go(Routes.newPurchase),
            child: const Icon(Icons.add_shopping_cart),
          ),
          const SizedBox(height: 2),
          Text(
            'Lançar',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

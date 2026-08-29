import 'package:flutter/material.dart';

/// One door out of a screen: where it goes, and how it is drawn. The bottom
/// bar and the `≡` of screen 1 both list these, which is why it lives in
/// `ui/core/widgets/` and not inside either of them.
///
/// Not named after the Material widget that draws it: only one of the two is
/// a `NavigationBar` — the `≡` is a bottom sheet — so a `NavDestination` name
/// would mislead half the time.
final class MenuEntry {
  const MenuEntry({
    required this.route,
    required this.icon,
    required this.label,
  });

  final String route;
  final IconData icon;

  /// pt-BR: read on screen.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuEntry &&
          other.route == route &&
          other.icon == icon &&
          other.label == label;

  @override
  int get hashCode => Object.hash(route, icon, label);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/core/widgets/menu_entry.dart';

/// The door the bottom bar and the `≡` of screen 1 both list. It was a record
/// declared twice — once in each file — until 29/08/2026.
void main() {
  MenuEntry entry({
    String route = Routes.shoppingList,
    IconData icon = Icons.checklist,
    String label = 'Lista',
  }) => MenuEntry(route: route, icon: icon, label: label);

  test('equality covers every field', () {
    expect(entry(), entry());
    expect(entry().hashCode, entry().hashCode);
    expect(entry(), isNot(entry(route: Routes.reports)));
    expect(entry(), isNot(entry(icon: Icons.bar_chart)));
    expect(entry(), isNot(entry(label: 'Relatórios')));
  });
}

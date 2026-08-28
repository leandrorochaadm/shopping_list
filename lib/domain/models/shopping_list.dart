import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'category.dart';
import 'name_normalization.dart';
import 'shopping_list_item.dart';

/// One category and its items, already in the order the screen draws them.
final class ShoppingListGroup {
  const ShoppingListGroup({required this.category, required this.items});

  final Category category;
  final IList<ShoppingListItem> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingListGroup &&
          other.category == category &&
          other.items == items);

  @override
  int get hashCode => Object.hash(category, items);

  @override
  String toString() => 'ShoppingListGroup(${category.name}, ${items.length})';
}

/// The grouping of requirement 11 and the order decided on 28/08/2026 (`C3`):
/// categories alphabetically and, inside each one, the items by the type's
/// name — the same organization screens 2 and 6 use.
///
/// It compares by the NORMALIZED name: `'Açougue'.compareTo('Bebidas')` in
/// Dart compares code units, and the 'ç' would land after the 'z'.
///
/// The category comes from inside the item, and it is always the CURRENT one:
/// reclassifying a type in H10 moves the item's group without anything here
/// knowing about it.
IList<ShoppingListGroup> groupByCategory(IList<ShoppingListItem> items) {
  final byCategory = <String, List<ShoppingListItem>>{};
  final categories = <String, Category>{};

  for (final item in items) {
    // A category with no id has not been written yet, and cannot be the one
    // an item points at — the name is the fallback so nothing is dropped.
    final key = item.category.id ?? item.category.name;
    categories[key] = item.category;
    (byCategory[key] ??= []).add(item);
  }

  final keys = categories.keys.toList()
    ..sort((a, b) => _compare(categories[a]!.name, categories[b]!.name, a, b));

  return [
    for (final key in keys)
      ShoppingListGroup(
        category: categories[key]!,
        items:
            (byCategory[key]!..sort(
                  // The id breaks the tie so the order is STABLE: two types
                  // with the same name do not exist (the unique index sees to
                  // that), but two items of the same type on the same list do,
                  // and without a tiebreak their order changes on every fetch.
                  (a, b) => _compare(
                    a.type.name,
                    b.type.name,
                    a.id ?? '',
                    b.id ?? '',
                  ),
                ))
                .toIList(),
      ),
  ].toIList();
}

int _compare(String name, String otherName, String tie, String otherTie) {
  final byName = normalizeName(name).compareTo(normalizeName(otherName));
  return byName != 0 ? byName : tie.compareTo(otherTie);
}

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
/// categories alphabetically and, inside each one, the items by what the
/// line reads ([ShoppingListItem.effectiveLabel]). Since M-a a type can sit on
/// the list more than once — "Leite Italac integral" and "Leite" — and
/// sorting by the label keeps the lines of one type together, since every
/// label starts with the type's name.
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
                  // The id breaks the tie so the order is STABLE: two lines
                  // with the same label can exist (the guard of M-a is the
                  // screen's, and the other phone can beat it), and without a
                  // tiebreak their order changes on every fetch.
                  (a, b) => _compare(
                    a.effectiveLabel,
                    b.effectiveLabel,
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

/// The OPEN item of [typeId] the screens point at — screen 6 opens the dialog
/// on it instead of creating a second line for the same type.
///
/// **The oldest one when there is more than one** (decision E-i): since M-a
/// the `#1a` panel creates more than one line per type on purpose, and without a tiebreak which item the dialog opens would change on
/// every fetch. `enteredOn` first, the id second — two items can enter on the
/// same day.
ShoppingListItem? findOpenItemOfType(
  IList<ShoppingListItem> items,
  String typeId,
) {
  final candidates =
      items.where((item) => item.isOpen && item.type.id == typeId).toList()
        ..sort((a, b) {
          final byDay = a.enteredOn.compareTo(b.enteredOn);
          return byDay != 0 ? byDay : (a.id ?? '').compareTo(b.id ?? '');
        });
  return candidates.firstOrNull;
}

/// The registrations OTHER open lines of [typeId] already ask for — what the
/// item dialog greys out, so the same product never sits on the list twice
/// (decision M-a). **`null` in the set is an answer**: an open line with no
/// registration, which takes "Qualquer um" just as a line takes "Italac".
///
/// It reads the EFFECTIVE preference: a line whose registration was
/// deactivated is a "Qualquer um" line now, and it is that one it blocks.
/// [exceptItemId] is the line being edited — it never blocks its own option.
ISet<String?> takenRegistrationsOfType(
  IList<ShoppingListItem> items,
  String typeId, {
  String? exceptItemId,
}) => {
  for (final item in items)
    if (item.isOpen && item.type.id == typeId && item.id != exceptItemId)
      item.effectivePreferredRegistration?.id,
}.lock;

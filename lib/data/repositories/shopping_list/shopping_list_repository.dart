import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/pending_changes.dart';
import '../../../domain/models/shopping_list_item.dart';

/// The one list the two phones share. I/O only: every rule is asked of the
/// entity before a method here is called.
abstract class ShoppingListRepository {
  /// The whole list, with type, category, brand and packaging already
  /// embedded — the screen does not survive half a line (D4). No `active`
  /// filter: a deactivated type that is on the list stays on the list.
  Future<IList<ShoppingListItem>> fetchAll();

  /// Writes the line and returns what the database created, embeds included.
  ///
  /// **The item arrives with its `id` already filled in**, born on the phone
  /// through `newUuidV4()`. It is not a whim: without the id before the write
  /// there is no way to discard the echo of our own INSERT, and resending an
  /// `add` that timed out would create a second item on the list.
  ///
  /// It takes the ENTITY rather than a loose `productTypeId` because of the
  /// fake: the return has to bring type and category embedded (D4), and a
  /// fake given only an id would need a mirror catalog to build them. The
  /// ViewModel already holds both entities — they came from the panel.
  Future<ShoppingListItem> add(ShoppingListItem item);

  /// The checkbox and the dialog, in one method: quantity, preferences,
  /// `picked` and `not_found` are all columns of the same row, and the app is
  /// "last write wins" (`tecnico §4.5`).
  Future<ShoppingListItem> update(ShoppingListItem item);

  /// Removing by hand, from the item dialog. It is a real DELETE: the list
  /// item is not one of the six soft-deleted catalogs (decision 19) — it has
  /// no history to preserve, and a list that only grows is useless in an
  /// aisle.
  Future<void> remove(String id);

  /// What the other phone touched, while this screen is open.
  ///
  /// **It never emits an error** (D1): a channel that drops is an absence of
  /// events, and coming back emits `changed`, because anything could have
  /// changed while it was down. THIS phone's own writes do not show up here
  /// (D2).
  Stream<ListChangeKind> watchChanges();
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => throw UnimplementedError(
    'shoppingListRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);

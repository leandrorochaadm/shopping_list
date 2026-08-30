import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/pending_changes.dart';
import '../../../domain/models/shopping_list_item.dart';

/// The one list the two phones share. I/O only: every rule is asked of the
/// entity before a method here is called.
abstract class ShoppingListRepository {
  /// The list as it stands: every line still ON it, with type, category,
  /// brand and packaging already embedded — the screen does not survive half
  /// a line (D4) — and with the write-off trail already summed, so the
  /// balance can be derived (P5).
  ///
  /// "Still on it" means neither closed by a purchase (`fulfilled_on`) nor
  /// removed by hand (`removed_on`). **The filter belongs here and not beside
  /// a second method**: leaving this one bringing everything is how a bought
  /// item reappears in the aisle.
  ///
  /// No `active` filter, though: a deactivated type that is on the list stays
  /// on the list.
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

  /// Removing by hand, from the item dialog.
  ///
  /// **Since H7 it is NOT a DELETE.** `list_write_off` has a foreign key to
  /// this table with no `on delete`, so an item that already took a partial
  /// write-off cannot be deleted — and deleting it would take with it the
  /// trail H9 undoes. It fills `removed_on` instead, and the read above stops
  /// bringing it, which is what the aisle actually sees.
  ///
  /// [day] is the phone's today: the clock enters the system in the
  /// ViewModel and travels as a parameter (rule 9).
  Future<void> remove(ShoppingListItem item, DateTime day);

  /// The items THIS trail cites, open or not — what the correction's undo
  /// needs to see, and nothing beyond it.
  ///
  /// **It is not "the whole list including what left".** That was this
  /// method's first shape, and it read the entire table: a closed item and a
  /// removed one are never deleted (D1), so it grew forever — ~170 items a
  /// month (`tecnico §1.9`) are thousands of rows in a year, each with its
  /// `list_write_off` embed, on EVERY opening of the correction screen.
  ///
  /// The undo does not need that: `undoWriteOffs` only touches an item the
  /// trail cites, and the trail arrives from `fetchDetail` before this call.
  /// What the correction reads is proportional to the size of the purchase,
  /// not to the age of the app.
  Future<IList<ShoppingListItem>> fetchItemsByIds(Iterable<String> ids);

  /// How many OPEN items have this type — the number behind the warning
  /// "achocolatado está em 1 item da lista" (H10).
  Future<int> countOpenItemsOfType(String productTypeId);

  /// Takes every open item of a type off the list, writing [day] into
  /// `removed_on`. It is what confirming the deactivation of a type fires
  /// (H10), and it is deliberately irreversible: reactivating the type does
  /// NOT bring the item back.
  ///
  /// [day] comes from the ViewModel — no `current_date` in SQL (decision 7).
  ///
  /// It returns the ids that left, and the `_remote` consumes their echo
  /// inside itself before the Future completes — see [expectEcho].
  Future<IList<String>> removeOpenItemsOfType(String productTypeId, DateTime day);

  /// Tells the channel that the next changes to these rows are OURS.
  ///
  /// The counter behind it is fed only by this repository's own writes, and
  /// the correction of H9 writes `shopping_list_item` through an RPC of
  /// ANOTHER repository — so without this the echo is never consumed and H4's
  /// banner announces, on the very phone that made the correction, the change
  /// that phone has just made.
  ///
  /// [ids] is counted WITH REPETITION, on purpose: the counter holds how many
  /// echoes to expect per id, and an item the correction writes TWICE — the
  /// undo reopens it and the corrected purchase closes it again, two UPDATEs
  /// in one transaction — has to appear twice here. A `Set` would bring the
  /// wrong banner back, silently, in the most common correction of all.
  void expectEcho(Iterable<String> ids);

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

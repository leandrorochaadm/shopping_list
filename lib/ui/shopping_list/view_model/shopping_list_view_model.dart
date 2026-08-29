import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/shopping_list/shopping_list_repository.dart';
import '../../../domain/models/calendar_day.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/shopping_list_item.dart';
import '../../../domain/models/uuid.dart';
import '../../core/error_translation.dart';

/// Screen 1: the list the two of them edit from their phones.
///
/// The banner is NOT here — it is its own notifier, because the list is an
/// `AsyncNotifier` whose `build()` protects the initial load, and the banner
/// only subscribes to a stream.
final class ShoppingListViewModel
    extends AsyncNotifier<IList<ShoppingListItem>> {
  /// Reentrancy guard: the list stays on screen during an action, so the
  /// checkbox stays tappable — and in an aisle, with a trolley in hand, the
  /// double tap is the common case rather than the exception.
  bool _running = false;

  @override
  Future<IList<ShoppingListItem>> build() =>
      ref.watch(shoppingListRepositoryProvider).fetchAll();

  /// Reloads. It is what the tap on the banner and the pull-to-refresh call.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<IList<ShoppingListItem>>();

      final items = await ref.read(shoppingListRepositoryProvider).fetchAll();
      if (!ref.mounted) return null;

      state = AsyncData(items);
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar a lista');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<IList<ShoppingListItem>>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }

  /// The two-tap path of the `#1a` panel: the type, its category and the day.
  ///
  /// [category] travels along because the line carries it whole (D4) and the
  /// panel already has it in hand — it draws its results grouped by it.
  /// Fetching it again here would mean reading the CatalogViewModel from
  /// inside this one, and two ViewModels coupled by reads is where a circular
  /// dependency begins.
  ///
  /// [today] exists for the test: the screen passes nothing and the clock
  /// enters the system HERE (decision 13 and rule 9). Never in a widget, never
  /// in an entity. The item is born with **no quantity and no preferences**:
  /// whoever wants to ask for "6 litros" opens the dialog afterwards.
  ///
  /// The key is born here through `newUuidV4()`, not in the database: it is
  /// what lets the repository discard the echo of its own INSERT, and what
  /// makes resending a timed-out `add` not become a second item.
  Future<String?> add(
    ProductType type,
    Category category, {
    DateTime? today,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      final item = ShoppingListItem(
        id: newUuidV4(),
        type: type,
        category: category,
        enteredOn: dayOf(today ?? DateTime.now()),
      );

      final created = await ref
          .read(shoppingListRepositoryProvider)
          .add(item);
      if (!ref.mounted) return null;

      // The state does NOT become AsyncLoading in an action: the list stays on
      // screen, which is the same promise the banner makes for the other
      // phone's changes.
      state = AsyncData([...?state.value, created].toIList());
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'adicionar o item');
    } finally {
      _running = false;
    }
  }

  /// The checkbox. It flips empty ↔ picked and NEVER passes through "não
  /// encontrei" — what guarantees that is `item.togglePicked()`, not a
  /// copyWith written here (rule 7).
  Future<String?> togglePicked(ShoppingListItem item) =>
      _write(item.togglePicked(), 'marcar o item');

  /// The whole item dialog, in one write (H6).
  Future<String?> save(ShoppingListItem item) => _write(item, 'salvar o item');

  /// Removing by hand — which since H7 fills `removed_on` instead of
  /// deleting the row, so the write-off trail H9 undoes stays whole.
  ///
  /// [today] exists for the test: the screen passes nothing and the clock
  /// enters the system HERE (rule 9), never in a widget or an entity.
  Future<String?> remove(ShoppingListItem item, {DateTime? today}) async {
    if (_running) return null;
    _running = true;
    try {
      await ref
          .read(shoppingListRepositoryProvider)
          .remove(item, today ?? DateTime.now());
      if (!ref.mounted) return null;

      state = AsyncData(
        (state.value ?? const IList<ShoppingListItem>.empty())
            .removeWhere((entry) => entry.id == item.id),
      );
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, 'remover o item');
    } finally {
      _running = false;
    }
  }

  /// The checkbox and the dialog write the same row, so they share one method
  /// — "last write wins" (`tecnico §4.5`) is a single decision, and two copies
  /// of it would be two places to break it.
  Future<String?> _write(ShoppingListItem item, String action) async {
    if (_running) return null;
    _running = true;
    try {
      final written = await ref
          .read(shoppingListRepositoryProvider)
          .update(item);
      if (!ref.mounted) return null;

      state = AsyncData(
        (state.value ?? const IList<ShoppingListItem>.empty())
            .map((entry) => entry.id == written.id ? written : entry)
            .toIList(),
      );
      return null;
    } on Object catch (e, st) {
      return translateError(e, st, action);
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final shoppingListViewModelProvider =
    AsyncNotifierProvider<ShoppingListViewModel, IList<ShoppingListItem>>(
      ShoppingListViewModel.new,
      retry: (retryCount, error) => null,
    );

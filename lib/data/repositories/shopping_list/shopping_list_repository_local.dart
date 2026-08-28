import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/pending_changes.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/shopping_list_item.dart';
import 'shopping_list_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// The seed reproduces **the three shapes that break differently**, and its
/// types are the very ones `CatalogRepositoryLocal` has — a list holding a
/// type the catalog does not know would make the `#1a` panel look wrong in
/// debug for a reason that is only the fake's.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class ShoppingListRepositoryLocal implements ShoppingListRepository {
  ShoppingListRepositoryLocal({
    Iterable<ShoppingListItem>? initial,
    this.latency = const Duration(milliseconds: 400),
  }) : _items = [...initial ?? _seed()];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<ShoppingListItem> _items;

  /// The other phone's channel, simulated. The notifier tests call
  /// [emitRemoteChange]; in debug nobody does, and the banner never shows up.
  ///
  /// `broadcast` because Riverpod recreates a notifier on every rebuild of its
  /// provider, and a single-subscription controller would throw
  /// `Bad state: Stream has already been listened to` on the second `build()`.
  final _changes = StreamController<ListChangeKind>.broadcast();

  var _nextId = 100;

  static List<ShoppingListItem> _seed() {
    final meat = Category(id: 'cat-2', name: 'Carnes');
    final drinks = Category(id: 'cat-1', name: 'Bebidas');
    final cleaning = Category(id: 'cat-3', name: 'Limpeza');

    return [
      // With a quantity and no preference — and marked "não encontrei", so
      // the `[!]` shows up in debug without anyone tapping anything.
      ShoppingListItem(
        id: 'item-1',
        type: ProductType(
          id: 'type-2',
          name: 'Acém moído',
          categoryId: 'cat-2',
          baseUnit: BaseUnit.kilogram,
        ),
        category: meat,
        quantity: 6000,
        enteredOn: DateTime(2026, 8, 26),
        notFound: true,
      ),
      // No quantity at all: the common path of the `#1a` panel, and the case
      // the base migration was corrected to accept.
      ShoppingListItem(
        id: 'item-2',
        type: ProductType(
          id: 'type-3',
          name: 'Papel higiênico',
          categoryId: 'cat-3',
          baseUnit: BaseUnit.unit,
        ),
        category: cleaning,
        enteredOn: DateTime(2026, 8, 27),
      ),
      // Brand AND packaging preferred — the only one that exercises the whole
      // label — and already picked, so both states of the line are visible.
      ShoppingListItem(
        id: 'item-3',
        type: ProductType(
          id: 'type-1',
          name: 'Refrigerante',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.liter,
        ),
        category: drinks,
        preferredBrand: Brand(id: 'brand-1', name: 'Coca-Cola'),
        preferredProduct: Product(
          id: 'prod-4',
          productRegistrationId: 'reg-1',
          packaging: Packaging(
            pieceCount: 12,
            pieceSize: 350,
            pieceSizeUnit: MeasureUnit.milliliter,
          ),
        ),
        quantity: 4200,
        enteredOn: DateTime(2026, 8, 28),
        picked: true,
      ),
    ];
  }

  void emitRemoteChange(ListChangeKind kind) => _changes.add(kind);

  @override
  Stream<ListChangeKind> watchChanges() => _changes.stream;

  @override
  Future<IList<ShoppingListItem>> fetchAll() async {
    await Future<void>.delayed(latency);
    return _items.toIList();
  }

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    await Future<void>.delayed(latency);
    // The id is born on the phone, so the fake keeps whatever arrived — the
    // fallback is only for a test that builds an item by hand.
    final created = item.id == null
        ? item.copyWith(id: 'item-${_nextId++}')
        : item;
    _items.add(created);
    return created;
  }

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    await Future<void>.delayed(latency);
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) _items[index] = item;
    return item;
  }

  @override
  Future<void> remove(String id) async {
    await Future<void>.delayed(latency);
    _items.removeWhere((entry) => entry.id == id);
  }
}

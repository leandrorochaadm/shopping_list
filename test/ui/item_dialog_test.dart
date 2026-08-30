import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/ui/shopping_list/widgets/item_dialog.dart';

import '../helpers/catalog.dart';
import '../helpers/shopping_list.dart';

/// The list fake with a switch that makes the next write fail, and a record of
/// what was written — the same shape every other ViewModel test uses, and it
/// is what reaches the SnackBar arm of the dialog without mocktail.
///
/// The record exists because **a repository method cannot be awaited from
/// inside `testWidgets`**: the fakes' `Future.delayed(Duration.zero)` only
/// fires when a frame is pumped WITH a duration, so `await fetchAll()` after
/// the dialog closes is a deadlock, not an assertion.
class _SpyList extends ShoppingListRepositoryLocal {
  _SpyList({super.initial}) : super(latency: Duration.zero);

  Object? failNextWrite;

  final List<ShoppingListItem> written = [];
  final List<ShoppingListItem> removed = [];

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    written.add(item);
    return super.update(item);
  }

  @override
  Future<void> remove(ShoppingListItem item, DateTime day) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    removed.add(item);
    return super.remove(item, day);
  }
}

/// A catalog whose `fetchLeavesOfType` can be made to fail: the dialog has to
/// keep working with the two dropdowns stuck on "Qualquer uma".
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  Object? failNextLeaves;

  @override
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId) async {
    final failure = failNextLeaves;
    failNextLeaves = null;
    if (failure != null) throw failure;
    return super.fetchLeavesOfType(productTypeId);
  }
}

final _drinks = Category(id: 'cat-1', name: 'Bebidas');

final _softDrink = ProductType(
  id: 'type-1',
  name: 'Refrigerante',
  categoryId: 'cat-1',
  baseUnit: BaseUnit.liter,
);

ShoppingListItem _item({
  int? quantity,
  bool notFound = false,
  Brand? brand,
  Product? product,
}) => ShoppingListItem(
  id: 'item-1',
  type: _softDrink,
  category: _drinks,
  quantity: quantity,
  preferredBrand: brand,
  preferredProduct: product,
  notFound: notFound,
  enteredOn: DateTime(2026, 8, 20),
);

void main() {
  Future<_SpyList> pumpDialog(
    WidgetTester tester, {
    ShoppingListItem? item,
    _SpyList? list,
    CatalogRepository? catalog,
  }) async {
    final line = item ?? _item(quantity: 6000);
    final repository = list ?? _SpyList(initial: [line]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListOverride(repository: repository),
          catalogOverride(repository: catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ItemDialog.show(context, line),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('opens with the stored quantity written in the base unit', (
    tester,
  ) async {
    await pumpDialog(tester, item: _item(quantity: 6000));

    // 6000 millilitres are six LITRES on screen: the field speaks the base
    // unit of the type, spelled out beside it.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('field-quantity')),
    );
    expect(field.controller!.text, '6');
    expect(find.text('litros'), findsOneWidget);
    expect(find.text('Refrigerante'), findsOneWidget);
  });

  testWidgets('opens empty when the item never asked for a quantity', (
    tester,
  ) async {
    await pumpDialog(tester, item: _item());

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('field-quantity')),
    );
    expect(field.controller!.text, '');
    expect(find.text('Vazio: sai na primeira compra do tipo.'), findsOneWidget);
  });

  testWidgets('offers the brands and the packagings of THIS type', (
    tester,
  ) async {
    await pumpDialog(tester);

    // The fake catalog hangs four leaves of one Coca-Cola registration under
    // `type-1`, so the brand comes from the leaves and not from the whole
    // brand list — "Omo" is in the catalog and must not show up here.
    await tester.tap(find.byKey(const ValueKey('field-brand')));
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola'), findsWidgets);
    expect(find.text('Omo'), findsNothing);

    await tester.tap(find.text('Coca-Cola').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('field-packaging')));
    await tester.pumpAndSettle();
    expect(find.text('12 × 350 ml'), findsWidgets);
  });

  testWidgets('saves the quantity and the not-found mark', (tester) async {
    final repository = await pumpDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '2,5');
    await tester.tap(find.byKey(const ValueKey('field-not-found')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // The dialog closed, and what was written speaks the base unit: 2,5 L is
    // 2500 millilitres.
    expect(find.text('Salvar'), findsNothing);
    expect(repository.written.single.quantity, 2500);
    expect(repository.written.single.notFound, isTrue);
  });

  testWidgets('clearing the field puts the item back to no quantity', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // `clearQuantity` and not a `??`: the dialog has to tell "keep what is
    // there" from "put it back to none", and only the flag does.
    expect(repository.written.single.quantity, isNull);
  });

  testWidgets('a quantity that is not a quantity stays under the field', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      'abc',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Under the field and NOT in a SnackBar: it is an answer about what was
    // just typed. The dialog is still open and nothing was written.
    expect(find.text('Informe uma quantidade válida.'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(repository.written, isEmpty);
  });

  testWidgets('more decimals than the unit holds is refused the same way', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);

    // Litres go down to the millilitre — three decimal places — so a fourth
    // is a typo the field has to say no to.
    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '1,2345',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('casas decimais'), findsOneWidget);
    expect(repository.written, isEmpty);
  });

  testWidgets('a failed save keeps the dialog open and shows the SnackBar', (
    tester,
  ) async {
    final list = _SpyList(initial: [_item(quantity: 6000)]);
    await pumpDialog(tester, list: list);

    list.failNextWrite = NetworkException('down');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // The raw exception NEVER reaches the screen (rule 10).
    expect(find.textContaining('down'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('removing asks first, and cancelling writes nothing', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);

    await tester.tap(find.text('Remover da lista'));
    await tester.pumpAndSettle();
    expect(find.text('Remover da lista?'), findsOneWidget);
    expect(find.textContaining('sai da lista'), findsOneWidget);

    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();

    expect(repository.removed, isEmpty);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('confirming the removal takes the line off the list', (
    tester,
  ) async {
    final repository = await pumpDialog(tester);

    await tester.tap(find.text('Remover da lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(repository.removed.single.id, 'item-1');
    expect(find.text('Salvar'), findsNothing);
  });

  testWidgets('a failed removal keeps the dialog open', (tester) async {
    final list = _SpyList(initial: [_item(quantity: 6000)]);
    await pumpDialog(tester, list: list);

    await tester.tap(find.text('Remover da lista'));
    await tester.pumpAndSettle();

    list.failNextWrite = NetworkException('down');
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('cancelling writes nothing at all', (tester) async {
    final repository = await pumpDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '3');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.written, isEmpty);
  });

  testWidgets('packagings that did not load leave the dialog usable', (
    tester,
  ) async {
    final catalog = _SpyCatalog()..failNextLeaves = NetworkException('x');
    final repository = await pumpDialog(tester, catalog: catalog);

    // No brands, no packagings — and the quantity still saves, which is the
    // whole reason `leavesOfType` answers with an empty list on failure.
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '4');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.written.single.quantity, 4000);
  });
}

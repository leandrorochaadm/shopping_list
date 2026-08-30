import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/ui/shopping_list/widgets/add_item_panel.dart';

import '../helpers/catalog.dart';
import '../helpers/shopping_list.dart';

/// The catalog fake with a switch that fails the next read — the `#1a` panel
/// has an error arm of its own, with a `[ Tentar de novo ]` that no other
/// screen reaches.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  Object? failNextFetch;

  /// Appended to what the fake already has — the fake has no deactivated
  /// type, and decision B3 only shows up when there is one.
  final List<ProductType> extraTypes = [];

  final List<ProductType> updated = [];

  @override
  Future<IList<ProductType>> fetchTypes() async {
    final failure = failNextFetch;
    failNextFetch = null;
    // The throw waits for the fake's latency ON PURPOSE: `build()` starts
    // three futures and awaits them in order, so a failure raised before the
    // first `await` lands with no listener attached and Dart reports it as an
    // unhandled zone error instead of as this provider's AsyncError.
    final types = await super.fetchTypes();
    if (failure != null) throw failure;
    return types.addAll(extraTypes);
  }

  @override
  Future<ProductType> updateType(ProductType type) async {
    updated.add(type);
    return super.updateType(type);
  }
}

/// The list fake that records what was added — a repository method cannot be
/// awaited from inside `testWidgets` (the fakes' `Future.delayed` only fires
/// on a frame pumped WITH a duration), so the record is the assertion.
class _SpyList extends ShoppingListRepositoryLocal {
  _SpyList({super.initial}) : super(latency: Duration.zero);

  Object? failNextAdd;

  final List<ShoppingListItem> added = [];

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    final failure = failNextAdd;
    failNextAdd = null;
    if (failure != null) throw failure;
    added.add(item);
    return super.add(item);
  }
}

ShoppingListItem _onTheList(String typeId, String typeName) =>
    ShoppingListItem(
      id: 'item-$typeId',
      type: ProductType(
        id: typeId,
        name: typeName,
        categoryId: 'cat-1',
        baseUnit: BaseUnit.liter,
      ),
      category: Category(id: 'cat-1', name: 'Bebidas'),
      enteredOn: DateTime(2026, 8, 20),
    );

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    CatalogRepository? catalog,
    _SpyList? list,
  }) async {
    // A tall viewport: the sheet lists three categories with their types, and
    // the default 800×600 leaves the last of them outside the render tree.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogOverride(repository: catalog),
          shoppingListOverride(repository: list ?? _SpyList(initial: const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AddItemPanel.show(context),
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
  }

  testWidgets('lists the active types grouped by category', (tester) async {
    await pumpPanel(tester);

    // The three categories of the fake, each with its own type under it. The
    // grouping is `groupTypesByCategory`, in the domain since 29/08.
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Carnes'), findsOneWidget);
    expect(find.text('Limpeza'), findsOneWidget);
    expect(find.text('Refrigerante'), findsOneWidget);
    expect(find.text('Acém moído'), findsOneWidget);
  });

  testWidgets('the search compares normalized on both sides', (tester) async {
    await pumpPanel(tester);

    // "acem moido" finds "Acém moído" — and whoever types it does NOT create
    // a second type, which is the whole point of the normalization.
    await tester.enterText(find.byType(TextField), 'acem moido');
    await tester.pumpAndSettle();

    expect(find.text('Acém moído'), findsOneWidget);
    expect(find.text('Refrigerante'), findsNothing);
    expect(find.byKey(const ValueKey('create-type')), findsNothing);
  });

  testWidgets('a search that matches nothing offers to create the type', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'Manteiga');
    await tester.pumpAndSettle();

    expect(find.text('Criar "Manteiga"'), findsOneWidget);
  });

  testWidgets('two taps put the type on the list', (tester) async {
    final list = _SpyList(initial: const []);
    await pumpPanel(tester, list: list);

    await tester.tap(find.text('Refrigerante'));
    await tester.pumpAndSettle();

    // The line is born with NO quantity and NO preferences: whoever wants
    // "6 litros" opens the dialog afterwards. And the panel closed.
    expect(list.added.single.type.name, 'Refrigerante');
    expect(list.added.single.quantity, isNull);
    expect(list.added.single.category.name, 'Bebidas');
    expect(find.text('Refrigerante'), findsNothing);
  });

  testWidgets('a type already on the list is offered as unavailable', (
    tester,
  ) async {
    final list = _SpyList(initial: [_onTheList('type-1', 'Refrigerante')]);
    await pumpPanel(tester, list: list);

    expect(find.text('(já está na lista)'), findsOneWidget);

    // Tapping it writes nothing: repeating an item helps nobody in an aisle.
    await tester.tap(find.text('Refrigerante'));
    await tester.pumpAndSettle();
    expect(list.added, isEmpty);
  });

  testWidgets('an exact match never offers to create a second type', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'Refrigerante');
    await tester.pumpAndSettle();

    // The guard is `findNameConflict`, the same one the ViewModel uses: an
    // exact match hides the `[ + Criar ]`, so nobody creates a twin type and
    // splits the sum every report is built on.
    expect(find.byKey(const ValueKey('create-type')), findsNothing);
  });

  testWidgets('a deactivated type offers to reactivate and then adds it', (
    tester,
  ) async {
    final catalog = _SpyCatalog()
      ..extraTypes.add(
        ProductType(
          id: 'type-9',
          name: 'Achocolatado',
          categoryId: 'cat-1',
          baseUnit: BaseUnit.liter,
          active: false,
        ),
      );
    final list = _SpyList(initial: const []);
    await pumpPanel(tester, catalog: catalog, list: list);

    // It does not show up in the empty search — that lists the active ones —
    // and it does show up once its name is typed, which is decision B3: the
    // way out is to reactivate the one that exists, never to create a second
    // one and split its history in two.
    expect(find.text('Achocolatado'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Achocolatado');
    await tester.pumpAndSettle();
    expect(find.text('(desativado)'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-type')), findsNothing);

    await tester.tap(find.text('Reativar'));
    await tester.pumpAndSettle();

    expect(catalog.updated.single.active, isTrue);
    // And it lands on the list in the same gesture — reactivating is the
    // detour, adding is what the person came for.
    expect(list.added.single.type.name, 'Achocolatado');
  });

  testWidgets('a failed load shows the retry, and the retry recovers', (
    tester,
  ) async {
    final catalog = _SpyCatalog()..failNextFetch = NetworkException('down');
    await pumpPanel(tester, catalog: catalog);

    // The raw exception never reaches the screen (rule 10).
    expect(find.textContaining('down'), findsNothing);
    expect(find.text('Não foi possível carregar os tipos.'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Refrigerante'), findsOneWidget);
  });

  testWidgets('a failed add keeps the panel open and shows the SnackBar', (
    tester,
  ) async {
    final list = _SpyList(initial: const [])
      ..failNextAdd = NetworkException('down');
    await pumpPanel(tester, list: list);

    await tester.tap(find.text('Refrigerante'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('down'), findsNothing);
    // Still open: the panel is the most used path of the app, and closing it
    // on a failure would cost the two taps all over again.
    expect(find.text('Refrigerante'), findsOneWidget);
  });

  testWidgets('the search box names the type the create dialog opens with', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'Manteiga');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-type')));
    await tester.pumpAndSettle();

    // What was searched for is what names the new type — nobody types it
    // twice.
    expect(find.text('Criar e adicionar'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == 'Manteiga'),
      isTrue,
    );
  });
}

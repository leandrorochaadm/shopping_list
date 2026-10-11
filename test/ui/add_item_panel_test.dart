import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/catalog/widgets/new_product_screen.dart';
import 'package:shopping_list/ui/shopping_list/widgets/add_item_panel.dart';
import 'package:shopping_list/ui/shopping_list/widgets/item_dialog.dart';

import '../helpers/barcode_camera.dart';
import '../helpers/barcode_owners.dart';
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

  /// What `findOwners` knows: the fake starts with no code at all.
  final owners = <Barcode, BarcodeOwner>{};
  int findOwnersCalls = 0;
  Object? failFindOwners;

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    findOwnersCalls++;
    // Throws after the fake's own await, for the same reason as `fetchTypes`.
    await super.findOwners(codes);
    final failure = failFindOwners;
    if (failure != null) throw failure;
    return {for (final code in codes) code: ?owners[code]}.lock;
  }

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

ShoppingListItem _onTheList(String typeId, String typeName) => ShoppingListItem(
  id: 'item-$typeId',
  type: ProductType(
    id: typeId,
    name: typeName,
    categoryId: 'cat-1',
    baseUnit: BaseUnit.milliliter,
  ),
  category: Category(id: 'cat-1', name: 'Bebidas'),
  enteredOn: DateTime(2026, 8, 20),
);

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    CatalogRepository? catalog,
    _SpyList? list,
    FakeBarcodeCamera? camera,
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
          (camera ?? FakeBarcodeCamera()).override,
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

  /// Opens the reader, hands it [raw] and lets the lookup finish. The fake
  /// clock only advances on a `pump` WITH a duration.
  Future<void> scan(
    WidgetTester tester,
    FakeBarcodeCamera camera,
    String raw,
  ) async {
    await tester.tap(find.byKey(const ValueKey('scan-type')));
    await tester.pumpAndSettle();
    camera.read(raw);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  /// The panel inside a router, for the cases that go to screen 4. The fake
  /// screen 4 records the request and pops [returns].
  Future<List<NewProductRequest?>> pumpPanelInRouter(
    WidgetTester tester, {
    required _SpyCatalog catalog,
    required _SpyList list,
    required FakeBarcodeCamera camera,
    PickedProduct? returns,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final requests = <NewProductRequest?>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AddItemPanel.show(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.newProduct,
          builder: (context, state) {
            requests.add(state.extra as NewProductRequest?);
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(returns),
                child: const Text('salvar fake'),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogOverride(repository: catalog),
          shoppingListOverride(repository: list),
          camera.override,
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return requests;
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

  testWidgets('a type already on the list opens the item dialog (M-a)', (
    tester,
  ) async {
    final list = _SpyList(initial: [_onTheList('type-1', 'Refrigerante')]);
    await pumpPanel(tester, list: list);

    expect(
      find.text('já está na lista — toque para pedir outro produto'),
      findsOneWidget,
    );

    // The tap writes nothing yet: the panel closes and the item dialog opens
    // in the creating mode, where the second line gets a product of its own.
    await tester.tap(find.text('Refrigerante'));
    await tester.pumpAndSettle();
    expect(list.added, isEmpty);
    expect(find.byType(AddItemPanel), findsNothing);
    expect(find.byType(ItemDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('field-registration')), findsOneWidget);
    expect(find.text('Remover da lista'), findsNothing);

    // The line on the list asks for "Qualquer um", so the new one has to
    // choose a product — and the fake catalog's only one is free.
    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(list.added.single.type.name, 'Refrigerante');
    expect(list.added.single.preferredRegistration?.id, 'reg-1');
    expect(find.byType(ItemDialog), findsNothing);
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
          baseUnit: BaseUnit.milliliter,
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

  group('the [▥] reads a code', () {
    const scaleLabel = '02822521001605261107';
    const scaleMessage =
        'Etiqueta de balança só serve no lançamento da compra.';

    testWidgets('a read code puts the type with its product, no packaging', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final list = _SpyList(initial: const []);
      await pumpPanel(tester, catalog: catalog, list: list, camera: camera);

      await scan(tester, camera, colaCode);

      final added = list.added.single;
      expect(added.type.id, 'type-1');
      expect(added.preferredRegistration?.id, 'reg-1');
      expect(added.preferredRegistrationBrand?.id, 'brand-1');
      expect(added.quantity, isNull);
      expect(added.category.name, 'Bebidas');
      expect(find.byType(AddItemPanel), findsNothing);
    });

    testWidgets('the product an open line already asks for is refused', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final asking = ShoppingListItem(
        id: 'item-asking',
        type: colaOwner.type,
        category: Category(id: 'cat-1', name: 'Bebidas'),
        preferredRegistration: colaOwner.registration,
        enteredOn: DateTime(2026, 8, 20),
      );
      final list = _SpyList(initial: [asking]);
      await pumpPanel(tester, catalog: catalog, list: list, camera: camera);

      await scan(tester, camera, colaCode);

      expect(find.text('Já está na lista.'), findsOneWidget);
      expect(list.added, isEmpty);
      expect(find.byType(AddItemPanel), findsOneWidget);
    });

    testWidgets('a "Qualquer um" line does not stop the read', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final list = _SpyList(initial: [_onTheList('type-1', 'Refrigerante')]);
      await pumpPanel(tester, catalog: catalog, list: list, camera: camera);

      await scan(tester, camera, colaCode);

      expect(list.added.single.preferredRegistration?.id, 'reg-1');
    });

    testWidgets('an unknown code offers to register', (tester) async {
      final camera = FakeBarcodeCamera();
      final list = _SpyList(initial: const []);
      await pumpPanel(tester, list: list, camera: camera);

      await scan(tester, camera, foilCode);

      expect(find.text('Nenhum produto com esse código.'), findsOneWidget);
      final action = find.byKey(const ValueKey('scan-notice-action'));
      expect(
        find.descendant(of: action, matching: find.text('Cadastrar produto')),
        findsOneWidget,
      );
      expect(list.added, isEmpty);
    });

    testWidgets('the registered product goes on the list', (tester) async {
      final camera = FakeBarcodeCamera();
      final list = _SpyList(initial: const []);
      final requests = await pumpPanelInRouter(
        tester,
        catalog: _SpyCatalog(),
        list: list,
        camera: camera,
        returns: pickedFrom(foilOwner),
      );

      await scan(tester, camera, foilCode);
      await tester.tap(find.byKey(const ValueKey('scan-notice-action')));
      await tester.pumpAndSettle();

      expect(
        requests.single,
        NewProductRequest(
          returnsSelection: true,
          initialBarcode: Barcode.typed(foilCode),
        ),
      );

      await tester.tap(find.text('salvar fake'));
      await tester.pumpAndSettle();

      final added = list.added.single;
      expect(added.type.id, 'type-6');
      expect(added.preferredRegistration?.id, 'reg-3');
      expect(added.category.name, 'Limpeza');
      expect(find.byType(AddItemPanel), findsNothing);
    });

    testWidgets('coming back from screen 4 with nothing adds nothing', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final list = _SpyList(initial: const []);
      await pumpPanelInRouter(
        tester,
        catalog: _SpyCatalog(),
        list: list,
        camera: camera,
      );

      await scan(tester, camera, foilCode);
      await tester.tap(find.byKey(const ValueKey('scan-notice-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('salvar fake'));
      await tester.pumpAndSettle();

      expect(list.added, isEmpty);
      expect(find.byType(AddItemPanel), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-notice')), findsOneWidget);
    });

    testWidgets('a scale label is refused', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog();
      final list = _SpyList(initial: const []);
      await pumpPanel(tester, catalog: catalog, list: list, camera: camera);

      await scan(tester, camera, scaleLabel);

      expect(find.text(scaleMessage), findsOneWidget);
      expect(catalog.findOwnersCalls, 0);
      expect(list.added, isEmpty);
    });

    testWidgets('an invalid code says so inside the panel', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpPanel(tester, camera: camera);

      await scan(tester, camera, '7894900011518');

      expect(
        find.descendant(
          of: find.byType(AddItemPanel),
          matching: find.text('Código de barras inválido.'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failing lookup keeps the panel open and says why there', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog()..failFindOwners = NetworkException('down');
      await pumpPanel(tester, catalog: catalog, camera: camera);

      await scan(tester, camera, colaCode);

      expect(
        find.descendant(
          of: find.byType(AddItemPanel),
          matching: find.byKey(const ValueKey('scan-notice')),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('down'), findsNothing);
    });

    testWidgets('a failing add keeps the panel open and says why', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final list = _SpyList(initial: const [])
        ..failNextAdd = NetworkException('down');
      await pumpPanel(tester, catalog: catalog, list: list, camera: camera);

      await scan(tester, camera, colaCode);

      expect(find.byKey(const ValueKey('scan-notice')), findsOneWidget);
      expect(find.textContaining('down'), findsNothing);
      expect(find.byType(AddItemPanel), findsOneWidget);
    });

    testWidgets('typing clears the notice', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpPanel(tester, camera: camera);
      await scan(tester, camera, foilCode);
      expect(find.byKey(const ValueKey('scan-notice')), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'lei');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scan-notice')), findsNothing);
    });

    testWidgets('closing the reader does nothing', (tester) async {
      final catalog = _SpyCatalog();
      await pumpPanel(tester, catalog: catalog);

      await tester.tap(find.byKey(const ValueKey('scan-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-close')));
      await tester.pumpAndSettle();

      expect(catalog.findOwnersCalls, 0);
      expect(find.byKey(const ValueKey('scan-notice')), findsNothing);
    });
  });
}

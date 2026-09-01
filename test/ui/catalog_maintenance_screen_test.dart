import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';

/// The fake with a switch that makes the next call fail.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  Object? failNextCall;
  int updateCategoryCalls = 0;

  @override
  Future<IList<Category>> fetchCategories() async {
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchCategories();
  }

  @override
  Future<Category> updateCategory(Category category) async {
    updateCategoryCalls++;
    return super.updateCategory(category);
  }
}

void main() {
  // Screen 3 is reachable from the router this test builds, and it draws a
  // date — `main()` does not run in a test.
  setUpAll(initializePtBr);

  late _SpyCatalog catalog;

  setUp(() => catalog = _SpyCatalog());

  Future<ProviderContainer> pumpCatalog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        catalogOverride(repository: catalog),
        shoppingListOverride(
          repository: ShoppingListRepositoryLocal(latency: Duration.zero),
        ),
        ...purchaseOverrides(),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go(Routes.catalog);
    await tester.pumpAndSettle();
    return container;
  }

  /// The dialog's own field. The screen's search box is a TextField too, and
  /// it comes FIRST in the tree — `find.byType(TextField).first` would type
  /// into the list behind the dialog and the test would pass for the wrong
  /// reason.
  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Future<void> selectKind(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('field-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the categories', (tester) async {
    await pumpCatalog(tester);

    expect(find.text('Bebidas'), findsWidgets);
    expect(find.text('Carnes'), findsWidgets);
    expect(find.text('Limpeza'), findsWidgets);
  });

  testWidgets('the selector swaps catalogs without going to the database', (
    tester,
  ) async {
    await pumpCatalog(tester);

    await selectKind(tester, 'Tipos de produto');
    expect(find.text('Acém moído'), findsOneWidget);
    // The type carries what it is filed under and how it is measured.
    expect(find.text('Carnes · kg'), findsOneWidget);

    await selectKind(tester, 'Mercados');
    expect(find.text('Carrefour'), findsOneWidget);

    await selectKind(tester, 'Embalagens');
    expect(find.text('12 × 350 ml'), findsOneWidget);
  });

  testWidgets('the loose leaf is named after the grandeza of its type', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Embalagens');

    // A leaf with no packaging has no label to show, so the row says how the
    // product is sold — and "a peso" would not name bulk olive oil, which is
    // measured in litres. The word comes from the base unit of the type.
    expect(find.text('Vendido por peso'), findsOneWidget);
  });

  testWidgets('the search is normalized: "acem" finds "Acém"', (tester) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Tipos de produto');

    await tester.enterText(find.byKey(const ValueKey('field-search')), 'acem');
    await tester.pumpAndSettle();

    expect(find.text('Acém moído'), findsOneWidget);
    expect(find.text('Refrigerante'), findsNothing);
  });

  testWidgets('deactivated rows show only with the filter on', (tester) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Marcas');

    // 'Guaraná Antarctica' is the deactivated brand of the fake.
    expect(find.text('Guaraná Antarctica'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('show-inactive')));
    await tester.pumpAndSettle();

    expect(find.text('Guaraná Antarctica'), findsOneWidget);
  });

  testWidgets('a leaf reads as inactive when its REGISTRATION is', (
    tester,
  ) async {
    await pumpCatalog(tester);

    // Deactivate the registration through its own dialog…
    await selectKind(tester, 'Cadastros de produto');
    await tester.tap(find.byTooltip('Editar Coca-Cola original'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-active')));
    await tester.pumpAndSettle();

    // …and its four leaves leave the list, with `active: true` on every one
    // of them: the reading is `isEffectivelyActiveIn` (D7), not a second
    // write that would walk the leaves one by one.
    await selectKind(tester, 'Embalagens');
    expect(find.text('12 × 350 ml'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('show-inactive')));
    await tester.pumpAndSettle();
    expect(find.text('12 × 350 ml'), findsOneWidget);
  });

  testWidgets('renaming a category writes it', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.byTooltip('Editar Bebidas'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cadastro não se apaga: renomear vale para todo o histórico, e '
        'desativar tem volta.',
      ),
      findsOneWidget,
    );

    await tester.enterText(dialogField, 'Bebidas e sucos');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(catalog.updateCategoryCalls, 1);
    expect(find.text('Bebidas e sucos'), findsOneWidget);
  });

  testWidgets('renaming onto another row is refused, under the field', (
    tester,
  ) async {
    await pumpCatalog(tester);

    await tester.tap(find.byTooltip('Editar Bebidas'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, 'limpeza');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Já existe a categoria Limpeza.'), findsOneWidget);
    // Still open: the answer is about what was just typed, so it belongs
    // beside it and not in a SnackBar.
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('deactivating a type in use warns with the number, and asks', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Tipos de produto');

    // 'Papel higiênico' is on two open lines of the list fake.
    await tester.tap(find.byTooltip('Editar Papel higiênico'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-active')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Papel higiênico está em 2 itens da lista — eles serão removidos.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    // Cancelled: the type is still on.
    expect(find.byKey(const ValueKey('toggle-active')), findsOneWidget);
  });

  testWidgets('confirming it removes the items and deactivates the type', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Tipos de produto');

    await tester.tap(find.byTooltip('Editar Papel higiênico'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-active')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-deactivate')));
    await tester.pumpAndSettle();

    expect(find.text('Papel higiênico'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('show-inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Papel higiênico'), findsOneWidget);
  });

  testWidgets('a type with products cannot change its base unit', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Tipos de produto');

    await tester.tap(find.byTooltip('Editar Refrigerante'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Este tipo já tem produtos ou compras. A unidade base não pode mais '
        'mudar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed load occupies the screen, without the exception', (
    tester,
  ) async {
    catalog.failNextCall = ApiException(500, 'boom');
    await pumpCatalog(tester);

    expect(find.byKey(const ValueKey('retry-catalog')), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('a search that finds nothing says so', (tester) async {
    await pumpCatalog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('field-search')),
      'zzzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum cadastro encontrado.'), findsOneWidget);
  });

  testWidgets('has an exit of its own', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.byTooltip('Ir para a lista'));
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
  });
}

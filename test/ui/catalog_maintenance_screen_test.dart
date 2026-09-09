import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_view_model.dart';
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

    await tester.enterText(find.byKey(const ValueKey('field-search')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nenhum cadastro encontrado.'), findsOneWidget);
  });

  testWidgets('the create button follows the selector', (tester) async {
    await pumpCatalog(tester);

    // Decision D-1: the `+` promises what the list below it is showing, in
    // the gender of that catalog.
    expect(find.byTooltip('Nova categoria'), findsOneWidget);

    await selectKind(tester, 'Mercados');
    expect(find.byTooltip('Novo mercado'), findsOneWidget);

    await selectKind(tester, 'Embalagens');
    expect(find.byTooltip('Nova embalagem'), findsOneWidget);
  });

  testWidgets('creating a category shows it on the list', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, 'Padaria');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // The three catalog states are separate: without the `refresh()` of the
    // maintenance ViewModel the row would be written and never drawn.
    expect(find.text('Padaria'), findsOneWidget);
  });

  testWidgets('creating a brand shows it on the list', (tester) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Marcas');

    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, 'Ypê');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Ypê'), findsOneWidget);
  });

  testWidgets('creating a store shows it on the list', (tester) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Mercados');

    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, 'Hortifruti da esquina');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Hortifruti da esquina'), findsOneWidget);
  });

  testWidgets('a name that already exists is refused under the field', (
    tester,
  ) async {
    await pumpCatalog(tester);

    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    await tester.enterText(dialogField, 'limpeza');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Já existe a categoria Limpeza.'), findsOneWidget);
    // The dialog stays open and the list behind it is untouched.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a deactivated name offers to reactivate, not to duplicate', (
    tester,
  ) async {
    await pumpCatalog(tester);

    // Deactivated HERE, in the maintenance's own state…
    await tester.tap(find.byTooltip('Editar Limpeza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-active')));
    await tester.pumpAndSettle();

    // …and typed again in the create dialog, which reads the OTHER state.
    // Without the reload of `_reloadCatalog` the guard would look at a list
    // that never heard of the deactivation, and decision B3 would lose its
    // way back.
    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, 'Limpeza');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);
  });

  testWidgets('a double tap on + opens one dialog', (tester) async {
    await pumpCatalog(tester);

    final button = find.byKey(const ValueKey('create-entry'));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Without the `_busy` guard the second tap would stack a second dialog
    // over a list the first one is already changing.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('with Embalagens selected, + asks which product first', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Embalagens');

    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Nova embalagem'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();

    // Only the ACTIVE registrations are offered.
    expect(find.text('Coca-Cola original · Refrigerante'), findsWidgets);
  });

  testWidgets('the + is off until the six lists are in', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        // With latency the first frame has no value at all, which is the
        // state this case is about.
        catalogOverride(
          repository: CatalogRepositoryLocal(
            latency: const Duration(milliseconds: 50),
          ),
        ),
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
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('create-entry')),
    );
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('when the catalog cannot be reloaded, nothing opens and the '
      'reason is said', (tester) async {
    final container = await pumpCatalog(tester);
    // The catalog ViewModel is created HERE, before the failure is armed:
    // creating it costs a `build()` of its own, and that build would eat the
    // armed failure and leave `refresh()` to succeed.
    container.read(catalogViewModelProvider);
    await tester.pumpAndSettle();

    catalog.failNextCall = ApiException(500, 'boom');
    await tester.tap(find.byKey(const ValueKey('create-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('the pencil hands back the id only for the packaging door', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Cadastros de produto');

    // The contract `_editRegistration` depends on: the dialog answers with
    // the id when the packaging door was tapped, and with null otherwise.
    // Only the two closings that write NOTHING are exercised here — the
    // `[ Salvar ]` path goes through the CatalogViewModel, and the edit case
    // above already asserts its null.
    await tester.tap(find.byTooltip('Editar Coca-Cola original'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Abrir e acrescentar embalagem'),
      ),
    );
    await tester.pumpAndSettle();

    // Handing the id back is what puts screen 4 on the stack, from the
    // SCREEN — the dialog no longer travels on its own.
    expect(find.text('Novo produto'), findsWidgets);
  });

  testWidgets('coming back from screen 4 the list is up to date', (
    tester,
  ) async {
    await pumpCatalog(tester);
    await selectKind(tester, 'Cadastros de produto');

    await tester.tap(find.byTooltip('Editar Coca-Cola original'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Abrir e acrescentar embalagem'),
      ),
    );
    await tester.pumpAndSettle();

    final size = find.byKey(const ValueKey('size-1'));
    await tester.ensureVisible(size);
    await tester.pumpAndSettle();
    await tester.enterText(size, '750');
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Back on the maintenance screen — not on the shopping list (step 2) —
    // and with the new packaging on the list (the `refresh()` of the pencil).
    expect(find.text('Manutenção do cadastro'), findsOneWidget);
    await selectKind(tester, 'Embalagens');
    expect(find.textContaining('750 ml'), findsOneWidget);
  });

  testWidgets('has an exit of its own', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.byTooltip('Ir para a lista'));
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
  });
}

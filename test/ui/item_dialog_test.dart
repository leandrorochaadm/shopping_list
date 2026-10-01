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
import 'package:shopping_list/domain/models/product_registration.dart';
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
  final List<ShoppingListItem> added = [];
  final List<ShoppingListItem> removed = [];

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    added.add(item);
    return super.add(item);
  }

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
/// keep working with the "Produto" field stuck on "Qualquer um".
///
/// [withZero] hangs a second registration under `type-1` — "Coca-Cola zero"
/// beside the fake's "Coca-Cola original" — which is what the guard of M-a
/// needs to have something left to offer.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog({this.withZero = false}) : super(latency: Duration.zero);

  final bool withZero;

  Object? failNextLeaves;

  @override
  Future<IList<TypeLeaf>> fetchLeavesOfType(String productTypeId) async {
    final failure = failNextLeaves;
    failNextLeaves = null;
    if (failure != null) throw failure;
    final leaves = await super.fetchLeavesOfType(productTypeId);
    if (!withZero || productTypeId != 'type-1') return leaves;
    return leaves.add(
      TypeLeaf(
        product: const Product(id: 'prod-zero', productRegistrationId: _zeroId),
        registration: _zero,
      ),
    );
  }
}

/// The registration every leaf of `type-1` in the fake catalog is under.
final _original = ProductRegistration(
  id: 'reg-1',
  productTypeId: 'type-1',
  brandId: 'brand-1',
  description: 'original',
  sellingMode: SellingMode.byPiece,
);

const _zeroId = 'reg-zero';

final _zero = ProductRegistration(
  id: _zeroId,
  productTypeId: 'type-1',
  brandId: 'brand-1',
  description: 'zero',
  sellingMode: SellingMode.byPiece,
);

final _coke = Brand(id: 'brand-1', name: 'Coca-Cola');

final _drinks = Category(id: 'cat-1', name: 'Bebidas');

final _softDrink = ProductType(
  id: 'type-1',
  name: 'Refrigerante',
  categoryId: 'cat-1',
  baseUnit: BaseUnit.milliliter,
);

ShoppingListItem _item({
  String id = 'item-1',
  int? quantity,
  bool notFound = false,
  ProductRegistration? registration,
  Brand? brand,
}) => ShoppingListItem(
  id: id,
  type: _softDrink,
  category: _drinks,
  quantity: quantity,
  preferredRegistration: registration,
  preferredRegistrationBrand: brand,
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

  /// Screen 6's door, which decides between the two modes on [existing].
  Future<_SpyList> pumpForType(
    WidgetTester tester, {
    ShoppingListItem? existing,
    int? missing,
    _SpyList? list,
    CatalogRepository? catalog,
  }) async {
    final repository = list ?? _SpyList(initial: [?existing]);

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
                onPressed: () => ItemDialog.showForType(
                  context,
                  type: _softDrink,
                  category: _drinks,
                  missing: missing,
                  existing: existing,
                ),
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

    // The field is still TYPED in the base unit — 6000 keystrokes of digit —
    // but it is READ in the large one: "6,000" with "L" beside it.
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-quantity')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '6,000');
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Refrigerante'), findsOneWidget);
  });

  testWidgets('opens empty when the item never asked for a quantity', (
    tester,
  ) async {
    await pumpDialog(tester, item: _item());

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-quantity')),
        matching: find.byType(TextField),
      ),
    );
    // Empty, and NOT '0,000': nothing asked for is not zero asked for.
    expect(field.controller!.text, '');
    expect(find.text('Vazio: sai na primeira compra.'), findsOneWidget);
  });

  testWidgets('offers the products of THIS type, and "Qualquer um"', (
    tester,
  ) async {
    await pumpDialog(tester, catalog: _SpyCatalog(withZero: true));

    // Four leaves of the Coca-Cola original and one of the zero hang under
    // `type-1`: two registrations, each ONCE — the packaging is not what the
    // field chooses. "Omo" is in the catalog and must not show up here.
    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    expect(find.text('Qualquer um'), findsWidgets);
    expect(find.text('Coca-Cola original'), findsWidgets);
    expect(find.text('Coca-Cola zero'), findsWidgets);
    expect(find.textContaining('Omo'), findsNothing);
    expect(find.textContaining('350 ml'), findsNothing);
  });

  testWidgets('the help under the field follows the choice', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Sai da lista com qualquer refrigerante.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original').last);
    await tester.pumpAndSettle();

    expect(find.text('Só sai da lista com este produto.'), findsOneWidget);
  });

  testWidgets('saves the product chosen, with its brand', (tester) async {
    final repository = await pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.written.single.preferredRegistration, _original);
    expect(repository.written.single.preferredRegistrationBrand, _coke);
  });

  testWidgets('"Qualquer um" clears the product the line had', (tester) async {
    final repository = await pumpDialog(
      tester,
      item: _item(quantity: 6000, registration: _original, brand: _coke),
    );

    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qualquer um').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.written.single.preferredRegistration, isNull);
    expect(repository.written.single.preferredRegistrationBrand, isNull);
  });

  testWidgets('saves the quantity and the not-found mark', (tester) async {
    final repository = await pumpDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '2500',
    );
    await tester.tap(find.byKey(const ValueKey('field-not-found')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // The dialog closed, and what was written is what was typed: the field
    // speaks the base unit.
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

    // Zero is what the mask still lets through, and the dialog refuses it.
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '0');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Under the field and NOT in a SnackBar: it is an answer about what was
    // just typed. The dialog is still open and nothing was written.
    expect(find.text('Informe uma quantidade válida.'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(repository.written, isEmpty);
  });

  testWidgets('the field takes digits and nothing else', (tester) async {
    await pumpDialog(tester);

    // The mask keeps the digits and writes the comma itself: '1,25abc' has
    // three of them, and 125 millilitres read as '0,125'.
    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '1,25abc',
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-quantity')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '0,125');
    expect(field.keyboardType, TextInputType.number);
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
    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '4000',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.written.single.quantity, 4000);
  });

  testWidgets('a product that is not among the leaves is kept, not cleared', (
    tester,
  ) async {
    // The leaves did not load, so the stored registration has no item of its
    // own in the dropdown. Showing a value with no matching item is what trips
    // the DropdownButton assertion and takes the whole dialog down — and
    // saving must not erase a preference the person never touched.
    final catalog = _SpyCatalog()..failNextLeaves = NetworkException('x');
    final repository = await pumpDialog(
      tester,
      catalog: catalog,
      item: _item(quantity: 6000, registration: _zero, brand: _coke),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Coca-Cola zero'), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.written.single.preferredRegistration, _zero);
    expect(repository.written.single.preferredRegistrationBrand, _coke);
  });

  group('the two doors of screen 6 (H18)', () {
    testWidgets('the creating mode shows neither "Não encontrei" nor '
        '"Remover da lista"', (tester) async {
      // The written criterion: "marcar como não encontrado o que ninguém pediu
      // não quer dizer nada" — and there is no line to remove either.
      await pumpForType(tester, missing: 2000);

      expect(find.byKey(const ValueKey('field-not-found')), findsNothing);
      expect(find.text('Não encontrei'), findsNothing);
      expect(find.text('Remover da lista'), findsNothing);
      // The rest of the dialog is the SAME one — that is what the wireframe
      // demands.
      expect(find.text('Refrigerante'), findsOneWidget);
      expect(find.byKey(const ValueKey('field-quantity')), findsOneWidget);
      expect(find.byKey(const ValueKey('field-registration')), findsOneWidget);
    });

    testWidgets('the editing mode still shows both', (tester) async {
      await pumpForType(tester, existing: _item(quantity: 6000), missing: 2000);

      expect(find.byKey(const ValueKey('field-not-found')), findsOneWidget);
      expect(find.text('Remover da lista'), findsOneWidget);
    });

    testWidgets('the creating mode ADDS a new line with what was typed', (
      tester,
    ) async {
      final repository = await pumpForType(tester, missing: 2000);

      // It opened with the missing amount already in, in the base unit.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-quantity')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '2,000');

      await tester.enterText(
        find.byKey(const ValueKey('field-quantity')),
        '3000',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repository.added, hasLength(1));
      expect(repository.added.single.quantity, 3000);
      expect(repository.added.single.type, _softDrink);
      expect(repository.added.single.category, _drinks);
      // It ADDED; it did not update anything.
      expect(repository.written, isEmpty);
      expect(find.byType(ItemDialog), findsNothing);
    });

    testWidgets('the creating mode with an empty field adds no quantity', (
      tester,
    ) async {
      // The bottom band of screen 6 opens with `missing: null`, and an item
      // with no quantity leaves the list on the first purchase of the type.
      final repository = await pumpForType(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-quantity')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repository.added.single.quantity, isNull);
    });

    testWidgets('the prefill WINS over the stored quantity', (tester) async {
      // The dialog is being opened FROM the missing amount, so that is what
      // the field shows — the leite of the wireframe asks 6 L on the list and
      // screen 6 says 8 L are missing.
      await pumpForType(tester, existing: _item(quantity: 6000), missing: 8000);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-quantity')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '8,000');
    });

    testWidgets('with no prefill the stored quantity stays', (tester) async {
      await pumpForType(tester, existing: _item(quantity: 6000));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-quantity')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '6,000');
    });

    testWidgets('the item on the list with NO quantity is warned that the '
        'rule changes', (tester) async {
      // Decision of 26/08/2026: confirming makes the line stop leaving on the
      // first purchase of the type and start being written off by amount. The
      // screen does not change the rule in silence.
      await pumpForType(tester, existing: _item(quantity: null), missing: 2000);

      expect(
        find.text(
          'este item está na lista sem quantidade — confirmar passa a '
          'pedir 2 L',
        ),
        findsOneWidget,
      );
      // And the usual sentence gives way to it — stacking both would be noise.
      expect(find.text('Vazio: sai na primeira compra.'), findsNothing);
    });

    testWidgets('the warning needs BOTH halves to appear', (tester) async {
      // With a quantity already on the line there is no rule to change.
      await pumpForType(tester, existing: _item(quantity: 6000), missing: 2000);
      expect(find.textContaining('confirmar passa a pedir'), findsNothing);
      expect(
        find.text('Vazio: sai na primeira compra.'),
        findsOneWidget,
      );
    });

    testWidgets('and it does not appear in the creating mode either', (
      tester,
    ) async {
      // There is no item on the list, so there is no rule of any line to
      // change.
      await pumpForType(tester, missing: 2000);
      expect(find.textContaining('confirmar passa a pedir'), findsNothing);
    });

    testWidgets('the creating mode KEEPS the product chosen (M-a)', (
      tester,
    ) async {
      // E-k discarded it; M-a revoked E-k — with the write-off by product, a
      // second line of milk saved without it would be worth any milk.
      final repository = await pumpForType(tester, missing: 2000);

      await tester.tap(find.byKey(const ValueKey('field-registration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coca-Cola original').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repository.added.single.preferredRegistration, _original);
      expect(repository.added.single.preferredRegistrationBrand, _coke);
    });

    testWidgets('a failing add keeps the dialog open and says why', (
      tester,
    ) async {
      final repository = _SpyList(initial: const [])
        ..failNextWrite = ApiException(500, 'boom');
      await pumpForType(tester, missing: 2000, list: repository);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDialog), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      // The raw exception NEVER reaches the screen.
      expect(find.textContaining('boom'), findsNothing);
    });
  });

  group('the same product never sits on the list twice (M-a)', () {
    testWidgets('an option another line asks for is greyed out, and says so', (
      tester,
    ) async {
      final other = _item(id: 'item-9', registration: _original, brand: _coke);
      await pumpForType(
        tester,
        list: _SpyList(initial: [other]),
        catalog: _SpyCatalog(withZero: true),
      );

      await tester.tap(find.byKey(const ValueKey('field-registration')));
      await tester.pumpAndSettle();

      expect(
        find.text('Coca-Cola original · já está na lista'),
        findsWidgets,
      );
      final option = tester.widget<DropdownMenuItem<String>>(
        find
            .ancestor(
              of: find.text('Coca-Cola original · já está na lista').last,
              matching: find.byType(DropdownMenuItem<String>),
            )
            .first,
      );
      expect(option.enabled, isFalse);
      expect(find.text('Coca-Cola zero'), findsWidgets);
    });

    testWidgets('the line being edited never blocks its own option', (
      tester,
    ) async {
      final line = _item(
        quantity: 6000,
        registration: _original,
        brand: _coke,
      );
      await pumpDialog(tester, item: line);

      await tester.tap(find.byKey(const ValueKey('field-registration')));
      await tester.pumpAndSettle();

      expect(find.textContaining('já está na lista'), findsNothing);
    });

    testWidgets('"Qualquer um" taken: the field opens empty, Salvar waits', (
      tester,
    ) async {
      final other = _item(id: 'item-9');
      final repository = await pumpForType(
        tester,
        list: _SpyList(initial: [other]),
        catalog: _SpyCatalog(withZero: true),
      );

      expect(
        find.text('Escolha um produto que ainda não está na lista.'),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Salvar'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('field-registration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coca-Cola zero').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repository.added.single.preferredRegistration, _zero);
    });

    testWidgets('everything taken: the field says so, and Salvar stays off', (
      tester,
    ) async {
      await pumpForType(
        tester,
        list: _SpyList(
          initial: [
            _item(id: 'item-8'),
            _item(id: 'item-9', registration: _original, brand: _coke),
          ],
        ),
      );

      expect(
        find.text('Todos os produtos deste tipo já estão na lista.'),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Salvar'),
      );
      expect(save.onPressed, isNull);
    });
  });
}

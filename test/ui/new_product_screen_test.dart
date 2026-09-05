import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/selling_choice.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_view_model.dart';
import 'package:shopping_list/ui/catalog/widgets/new_product_screen.dart';
import 'package:shopping_list/ui/catalog/widgets/packaging_row.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/shopping_list.dart';
import '../helpers/viewport.dart';

void main() {
  /// Mounted through the real router: screen 4 asks `context.canPop()` to
  /// decide which exit R11 gives it, and that question has no answer without
  /// a GoRouter above it.
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    CatalogRepository? repository,
    NewProductRequest? request,
  }) async {
    // A tall viewport: screen 4 is a long form, and the default 800×600 puts
    // the second packaging row outside the render tree, where a tap misses.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        catalogOverride(repository: repository),
        // The router starts on `/`, which is the real screen 1 since H4.
        shoppingListOverride(),
      ],
    );
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(Routes.newProduct, extra: request);
    await tester.pumpAndSettle();
    return container;
  }

  /// Scrolls the target into view before tapping it: the form is longer than
  /// any phone, so half of it is off-screen at any moment.
  Future<void> tapOn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Picks an option out of a DropdownButtonFormField by the text it shows.
  Future<void> choose(WidgetTester tester, Key field, String option) async {
    await tapOn(tester, find.byKey(field));
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('save')));

  /// The `Vendido` field as the screen actually built it: which word is taken
  /// and which ones can be taken at all. Read from the segments, because a
  /// disabled segment still DRAWS — asserting on the text alone would pass
  /// with every word clickable.
  SegmentedButton<SellingChoice> sellingField(WidgetTester tester) =>
      tester.widget<SegmentedButton<SellingChoice>>(
        find.byType(SegmentedButton<SellingChoice>),
      );

  Map<SellingChoice, bool> enabledChoices(WidgetTester tester) => {
    for (final segment in sellingField(tester).segments)
      segment.value: segment.enabled,
  };

  /// The one field inside the open dialog — `find.byType(TextField)` alone
  /// also matches the description field of the screen behind it.
  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  /// Leaves the description field, which is what triggers the identity
  /// check — the warning is meant to arrive on blur, not on every keystroke.
  Future<void> leaveField(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Key field, String text) async {
    await tester.ensureVisible(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(field), text);
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the type before offering any measure', (tester) async {
    // Without a base unit the screen cannot know whether to offer g/kg or
    // ml/L, and offering all four is how "350 ml" gets typed under a type
    // measured in kilos.
    await pumpScreen(tester);

    expect(find.text('Escolha o tipo do produto primeiro.'), findsOneWidget);
    expect(
      find.text('Unidade: escolha o tipo do produto primeiro'),
      findsOneWidget,
    );
  });

  testWidgets('takes the base unit from the type, never from the product', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    expect(find.text('Unidade: litro (vem do tipo)'), findsOneWidget);
  });

  testWidgets('offers only the measures of the chosen base unit', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    await tester.tap(find.byKey(const ValueKey('unit-1')));
    await tester.pumpAndSettle();

    expect(find.text('ml'), findsWidgets);
    expect(find.text('L'), findsWidgets);
    // The weight family never shows up under a type measured in litres.
    expect(find.text('g'), findsNothing);
    expect(find.text('kg'), findsNothing);
  });

  testWidgets('names the packaging the way the shelf does', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    // "350 ml", not "1 × 350 ml": that is the name searched for at the till.
    expect(find.text('350 ml'), findsWidgets);
    expect(find.text('Salvar 1 produto'), findsOneWidget);
  });

  testWidgets('refuses two lines holding the same amount, however typed', (
    tester,
  ) async {
    // By CONTENT, not by text: 1 × 0,35 L is the same packaging as 350 ml,
    // because the comparison happens after the conversion.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    await tapOn(tester, find.text('Adicionar embalagem'));
    await type(tester, const ValueKey('size-2'), '0,35');
    await choose(tester, const ValueKey('unit-2'), 'L');

    expect(find.text('Essa embalagem já está na lista'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('counts how many products are about to be born', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    await tapOn(tester, find.text('Adicionar embalagem'));
    await type(tester, const ValueKey('size-2'), '2');
    await choose(tester, const ValueKey('unit-2'), 'L');

    // Each line becomes a product of its own, with its own price history.
    expect(find.text('Salvar 2 produtos'), findsOneWidget);
  });

  testWidgets('hides the packaging list when the product is sold by weight', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Carnes');
    await choose(tester, const ValueKey('field-type'), 'Acém moído');
    await tapOn(tester, find.text('Peso'));

    expect(find.text('Embalagens deste produto'), findsNothing);
    expect(find.text('Adicionar embalagem'), findsNothing);
    // Quantity is what the PURCHASE asks for, not the registration.
    expect(find.text('Salvar produto'), findsOneWidget);
  });

  testWidgets('names the loose product after the grandeza of the type', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    // Bulk olive oil is measured in litres: calling it "a peso" is the very
    // mistake this field exists to fix.
    expect(enabledChoices(tester), {
      SellingChoice.weight: false,
      SellingChoice.unit: true,
      SellingChoice.volume: true,
    });
  });

  testWidgets('sells by volume the same way it sells by weight', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await tapOn(tester, find.text('Volume'));

    // `Volume` IS `by_weight`: same loose product, other grandeza.
    expect(find.text('Embalagens deste produto'), findsNothing);
    expect(find.text('Adicionar embalagem'), findsNothing);
    expect(find.text('Salvar produto'), findsOneWidget);
  });

  testWidgets('leaves only Unidade under a type counted by unit', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Limpeza');
    await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

    // Decision H-b: there is no bulk in a type counted by unit, so the avulso
    // is a packaging of `1 un` like any other.
    expect(enabledChoices(tester), {
      SellingChoice.weight: false,
      SellingChoice.unit: true,
      SellingChoice.volume: false,
    });
    expect(find.text('Embalagens deste produto'), findsOneWidget);
  });

  testWidgets('keeps the loose product loose when the grandeza changes', (
    tester,
  ) async {
    await pumpScreen(tester);

    // No category chosen on purpose: the type field then lists every type,
    // which is what puts a kilogram and a litre one behind the same dropdown.
    await choose(tester, const ValueKey('field-type'), 'Acém moído');
    await tapOn(tester, find.text('Peso'));
    expect(sellingField(tester).selected, {SellingChoice.weight});

    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    // The saved mode did not move — only the word that names it.
    expect(sellingField(tester).selected, {SellingChoice.volume});
    expect(find.text('Embalagens deste produto'), findsNothing);
  });

  testWidgets('falls back to Unidade when the new type has no bulk', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Limpeza');
    await choose(tester, const ValueKey('field-type'), 'Sabão em pó');
    await tapOn(tester, find.text('Peso'));
    expect(find.text('Embalagens deste produto'), findsNothing);

    await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

    // A `Peso` left behind by the old type would name a product measured in
    // units — the field normalizes instead.
    expect(sellingField(tester).selected, {SellingChoice.unit});
    expect(find.text('Embalagens deste produto'), findsOneWidget);
  });

  testWidgets('fits the three words on an iPhone 12', (tester) async {
    await pumpScreen(tester);
    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    // AFTER pumpScreen, which forces a tall viewport of its own.
    useIPhone12(tester);
    await tester.pumpAndSettle();

    // Drained on purpose, and it is NOT this field: the Marca dropdown
    // overflows by 219 px at this width, by exactly the same amount before
    // this change — it sizes itself to its widest menu item. Left as it was
    // found; the assertion below is about the `Vendido` field alone.
    tester.takeException();

    // The assertion is GEOMETRIC on purpose: `SegmentedButton` constrains its
    // children instead of overflowing, so `takeException()` is null at any
    // width and would prove nothing. At 390 pt the widest label renders at
    // 54,7 pt; at 320 pt it collapses to 31,3 pt and this fails.
    final label = find.descendant(
      of: find.byType(SegmentedButton<SellingChoice>),
      matching: find.text('Unidade'),
    );
    expect(tester.getSize(label).width, greaterThanOrEqualTo(54));
  });

  testWidgets('warns and blocks when the identity is already taken', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    // The warning arrives when the description LEAVES the field.
    await leaveField(tester);

    expect(
      find.text('Esse produto já está cadastrado, com 4 embalagens.'),
      findsOneWidget,
    );
    // Blocked while the repetition exists: changing the description to "zero"
    // unblocks it on the spot, because then it is another product.
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('opens the blocked registration instead of dead-ending', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);

    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    // The packagings it already has are on screen, and the line being built
    // came along instead of being thrown away.
    expect(find.text('já cadastrada'), findsNWidgets(4));
    expect(
      find.text('Acrescentando embalagem a um produto que já existe.'),
      findsOneWidget,
    );
  });

  testWidgets('refuses a packaging the registration already has', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);
    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    // 0,35 L is the 350 ml bottle that is already saved.
    await type(tester, const ValueKey('size-1'), '0,35');
    await choose(tester, const ValueKey('unit-1'), 'L');

    expect(find.text('Essa embalagem já está na lista'), findsOneWidget);
  });

  testWidgets('registers a category without leaving the screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapOn(tester, find.byTooltip('Nova categoria'));
    await tester.enterText(dialogField, 'Padaria');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    await choose(tester, const ValueKey('field-category'), 'Padaria');
  });

  testWidgets('answers the duplicate inside the dialog, next to the field', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapOn(tester, find.byTooltip('Nova marca'));
    await tester.enterText(dialogField, '  OMO ');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    // The dialog stays open with the sentence under the field: it is an
    // answer about what was just typed.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Já existe a marca Omo.'), findsOneWidget);
  });

  testWidgets('creates a type with its category and base unit', (tester) async {
    await pumpScreen(tester);

    await tapOn(tester, find.byTooltip('Novo tipo'));

    // No base unit is guessed, and the button stays disabled until one is
    // chosen: changing it later is the one path with no way back.
    await tester.enterText(dialogField, 'Achocolatado');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar'))
          .onPressed,
      isNull,
    );

    await choose(tester, const ValueKey('field-type-category'), 'Bebidas');
    await tapOn(tester, find.text('Quilo (peso)'));

    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // The type comes back chosen, with its unit already on screen.
    expect(find.text('Unidade: quilo (vem do tipo)'), findsOneWidget);
  });

  testWidgets('offers a retry instead of a spinner when nothing loads', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _FailingRepository());

    expect(
      find.text('Não foi possível carregar as listas do cadastro.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('saves the registration and leaves the screen', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'zero');
    await leaveField(tester);
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Produto salvo.'), findsOneWidget);
    // Saving LEAVES the screen: a registration saved twice is what this
    // avoids, and screen 3 is where H7 will bring it back to.
    expect(find.text('Lista de compras'), findsOneWidget);
  });

  testWidgets('says why it could not save, keeping what was typed', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _RefusingRepository());

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    // An ACTION that failed never takes over the screen — the form is intact.
    expect(find.text('350 ml'), findsWidgets);
  });

  testWidgets('saves a packaging into the registration that already exists', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);
    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    await type(tester, const ValueKey('size-1'), '600');
    await choose(tester, const ValueKey('unit-1'), 'ml');
    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Produto salvo.'), findsOneWidget);
  });

  testWidgets('removes a line and keeps the radio on a line that exists', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');
    await tapOn(tester, find.text('Adicionar embalagem'));
    await type(tester, const ValueKey('size-2'), '2');
    await choose(tester, const ValueKey('unit-2'), 'L');
    expect(find.text('Salvar 2 produtos'), findsOneWidget);

    await tapOn(tester, find.byTooltip('Remover embalagem').first);

    expect(find.text('Salvar 1 produto'), findsOneWidget);
    // The radio never ends up empty: it moved to the line that survived.
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('picks which packaging is being bought right now', (
    tester,
  ) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');
    await tapOn(tester, find.text('Adicionar embalagem'));
    await type(tester, const ValueKey('size-2'), '2');
    await choose(tester, const ValueKey('unit-2'), 'L');

    await tapOn(tester, find.byType(Radio<int>).last);

    expect(tester.widget<Radio<int>>(find.byType(Radio<int>).last).value, 2);
  });

  testWidgets('asks a type counted by unit for the count and nothing else', (
    tester,
  ) async {
    // Egg, toilet paper, bar soap: the base unit IS the piece, so there is no
    // measure to type.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Limpeza');
    await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

    expect(find.text('Unidade: unidade (vem do tipo)'), findsOneWidget);
    expect(find.text('Quantidade'), findsOneWidget);
    expect(find.byKey(const ValueKey('size-1')), findsNothing);

    await type(tester, const ValueKey('count-1'), '12');
    expect(find.text('12 × 1 un'), findsOneWidget);
  });

  testWidgets('takes the suggested description with one tap', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');

    // "orig." typed on a distracted day would create a second registration
    // out of nothing — the suggestion is what stops that.
    await tapOn(tester, find.widgetWithText(ActionChip, 'original'));

    expect(
      find.text('Esse produto já está cadastrado, com 4 embalagens.'),
      findsOneWidget,
    );
  });

  testWidgets('greys out a deactivated brand instead of hiding it', (
    tester,
  ) async {
    // Decision B3: hiding it is how a second "Guaraná Antarctica" would be
    // born the day the first one is deactivated.
    await pumpScreen(tester);

    await tapOn(tester, find.byKey(const ValueKey('field-brand')));

    expect(find.text('Guaraná Antarctica (desativada)'), findsWidgets);
  });

  testWidgets('carries an exit of its own, as R11 requires', (tester) async {
    // Installed on the home screen there is no browser Back button.
    await pumpScreen(tester);

    await tapOn(tester, find.byTooltip('Ir para a lista'));

    expect(find.text('Lista de compras'), findsOneWidget);
  });

  testWidgets('retries the load that failed', (tester) async {
    final repository = _FailingRepository();
    await pumpScreen(tester, repository: repository);

    repository.recover();
    await tapOn(tester, find.text('Tentar de novo'));

    expect(find.text('Novo produto'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('the reentrancy guard never says "Produto salvo."', (
    tester,
  ) async {
    // The regression test of the bug the sealed outcome fixed: `save` used to
    // answer `(error: null, saved: null)` when the guard fired, the screen
    // read `error == null` as success, said "Produto salvo." and navigated
    // away — with nothing written. Deleting the `case null` of the screen
    // brings it back, and this test fails.
    final repository = _StuckRepository();
    final container = await pumpScreen(tester, repository: repository);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await choose(tester, const ValueKey('unit-1'), 'ml');

    // Holds the write guard down: no `await`, so the call is still in flight
    // when the button is tapped. `_saving` of the widget is still false here,
    // so the button IS clickable and the tap really reaches the guard.
    unawaited(
      container
          .read(catalogViewModelProvider.notifier)
          .save(
            registration: ProductRegistration(
              productTypeId: 'type-1',
              sellingMode: SellingMode.byPiece,
            ),
            packagings: [
              Packaging.typed(
                pieceCount: '1',
                pieceSize: '350',
                pieceSizeUnit: MeasureUnit.milliliter,
              ),
            ].lock,
          ),
    );

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Produto salvo.'), findsNothing);
    // Still on screen 4, with the form intact.
    expect(find.text('Novo produto'), findsOneWidget);
    // And the button came back: without the `setState` in the `case null` the
    // screen would trade a lying SnackBar for a button frozen forever.
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save')),
    );
    expect(save.onPressed, isNotNull);

    repository.release();
    await tester.pumpAndSettle();
  });

  group('PickedProduct', () {
    PickedProduct picked({String leafId = 'prod-1', Brand? brand}) =>
        PickedProduct(
          product: Product(id: leafId, productRegistrationId: 'reg-1'),
          registration: ProductRegistration(
            id: 'reg-1',
            productTypeId: 'type-1',
            sellingMode: SellingMode.byPiece,
          ),
          type: ProductType(
            id: 'type-1',
            name: 'Refrigerante',
            categoryId: 'cat-1',
            baseUnit: BaseUnit.liter,
          ),
          brand: brand,
        );

    test('equality covers every field', () {
      expect(picked(), picked());
      expect(picked().hashCode, picked().hashCode);
      expect(picked(), isNot(picked(leafId: 'prod-2')));
      // Null is "Sem marca" (decision B2) — a real answer, and a different one.
      expect(
        picked(),
        isNot(
          picked(
            brand: Brand(id: 'b1', name: 'Coca'),
          ),
        ),
      );
    });
  });
  testWidgets('the ≡ door opens the registration already loaded', (
    tester,
  ) async {
    // Arriving from the catalog maintenance: the fields come filled and
    // LOCKED, and the four packagings that exist are on screen. It lands in
    // the very state H2 wrote for the registration blocked by repetition —
    // no second path through this screen.
    await pumpScreen(
      tester,
      request: const NewProductRequest(registrationId: 'reg-1'),
    );

    expect(
      find.text('Acrescentando embalagem a um produto que já existe.'),
      findsOneWidget,
    );
    expect(find.text('já cadastrada'), findsNWidgets(4));
  });

  testWidgets('the packaging lines being typed come before the ones already '
      'registered', (tester) async {
    // The maintenance path: four packagings already registered, which used to
    // sit ON TOP of the line being typed and pushed it down by four rows.
    await pumpScreen(
      tester,
      request: const NewProductRequest(registrationId: 'reg-1'),
    );

    expect(find.text('já cadastrada'), findsNWidgets(4));
    // Geometric on purpose: nothing here is renamed, only reordered, and
    // order is the only thing an assertion can see.
    expect(
      tester.getTopLeft(find.byType(PackagingRow).first).dy,
      lessThan(tester.getTopLeft(find.text('já cadastrada').first).dy),
      reason: 'what is already registered is above what is being typed',
    );
  });

  testWidgets('a registration that is not there says so, and opens blank', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      request: const NewProductRequest(registrationId: 'nope'),
    );

    expect(
      find.text('Não encontrei esse produto. Atualize a lista.'),
      findsOneWidget,
    );
  });

  testWidgets('the category door offers to reactivate right there', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      repository: _WithDeactivated(categoryId: 'cat-3'),
    );

    await tapOn(tester, find.byTooltip('Nova categoria'));
    await tester.enterText(dialogField, 'limpeza');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('O cadastro Limpeza existe, mas está desativado.'),
      findsOneWidget,
    );
    // The sentence lost its destination when the button arrived.
    expect(find.textContaining('manutenção do cadastro'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reactivate')));
    await tester.pumpAndSettle();

    // The dialog closed handing the name back, and the row is active again —
    // which is what puts it in the screen's dropdown.
    expect(find.byType(AlertDialog), findsNothing);
    final categories = container
        .read(catalogViewModelProvider)
        .value!
        .categories;
    expect(categories.where((c) => c.id == 'cat-3').single.active, isTrue);
  });

  testWidgets('the brand door offers to reactivate right there', (
    tester,
  ) async {
    await pumpScreen(tester);

    // 'Guaraná Antarctica' is the deactivated brand of the fake.
    await tapOn(tester, find.byTooltip('Nova marca'));
    await tester.enterText(dialogField, 'guarana antarctica');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reactivate')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the type door offers to reactivate, written by hand', (
    tester,
  ) async {
    // This dialog has three fields, so it does not use SingleFieldDialog:
    // the same button is written beside the message it raised.
    await pumpScreen(tester, repository: _WithDeactivated(typeId: 'type-3'));

    await tapOn(tester, find.byTooltip('Novo tipo'));
    await tester.enterText(dialogField, 'papel higienico');
    await choose(tester, const ValueKey('field-type-category'), 'Limpeza');
    await tapOn(tester, find.text('Unidade (contagem)'));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reactivate')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'the fourth door: reactivating the registration before adding packaging',
    (tester) async {
      await pumpScreen(
        tester,
        repository: _WithDeactivated(registrationId: 'reg-1'),
      );

      await choose(tester, const ValueKey('field-category'), 'Bebidas');
      await choose(tester, const ValueKey('field-type'), 'Refrigerante');
      await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
      await type(tester, const ValueKey('field-description'), 'original');
      await leaveField(tester);

      // Adding leaves to a deactivated registration is writing what nobody
      // will ever see, so the button reactivates first — and says so.
      expect(
        find.text('Esse produto já existe, mas está desativado.'),
        findsOneWidget,
      );
      await tapOn(tester, find.text('Reativar e acrescentar embalagem'));

      expect(
        find.text('Acrescentando embalagem a um produto que já existe.'),
        findsOneWidget,
      );
    },
  );
}

/// Never finishes the write, so the reentrancy guard stays down for as long as
/// the test needs it — the deterministic way to reach it now that `save` no
/// longer shares its flag with the three catalog creates.
class _StuckRepository extends CatalogRepositoryLocal {
  _StuckRepository() : super(latency: Duration.zero);

  final _held = Completer<SavedRegistration>();

  void release() => _held.complete(
    SavedRegistration(
      registration: ProductRegistration(
        id: 'reg-100',
        productTypeId: 'type-1',
        sellingMode: SellingMode.byPiece,
      ),
      products: const IList.empty(),
    ),
  );

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  }) => _held.future;
}

/// Refuses the load, so the error state gets exercised instead of being seen
/// for the first time on a phone with no connection.
class _FailingRepository extends CatalogRepositoryLocal {
  _FailingRepository() : super(latency: Duration.zero);

  bool _failing = true;

  void recover() => _failing = false;

  @override
  Future<IList<Category>> fetchCategories() async =>
      _failing ? throw NetworkException('offline') : super.fetchCategories();
}

/// Loads fine and refuses to WRITE: the action error path, which never takes
/// over the screen.
class _RefusingRepository extends CatalogRepositoryLocal {
  _RefusingRepository() : super(latency: Duration.zero);

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<Packaging> packagings,
  }) async => throw NetworkException('offline');
}

/// The fake with one row already DEACTIVATED, done by overriding the read.
///
/// Not by awaiting `updateCategory` before the first pump: inside
/// `testWidgets` the clock is fake, so the fakes' `Future.delayed` only fires
/// when a frame is pumped WITH a duration — and an `await` before
/// `pumpWidget` deadlocks the test for ten minutes instead of failing.
class _WithDeactivated extends CatalogRepositoryLocal {
  _WithDeactivated({this.categoryId, this.typeId, this.registrationId})
    : super(latency: Duration.zero);

  final String? categoryId;
  final String? typeId;
  final String? registrationId;

  @override
  Future<IList<Category>> fetchCategories() async =>
      (await super.fetchCategories())
          .map((entry) => entry.id == categoryId ? entry.deactivated() : entry)
          .toIList();

  @override
  Future<IList<ProductType>> fetchTypes() async => (await super.fetchTypes())
      .map((entry) => entry.id == typeId ? entry.deactivated() : entry)
      .toIList();

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    final found = await super.findRegistration(
      productTypeId: productTypeId,
      brandId: brandId,
      description: description,
    );
    return found?.id == registrationId ? found!.deactivated() : found;
  }
}

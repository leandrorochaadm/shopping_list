import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_view_model.dart';
import 'package:shopping_list/ui/catalog/widgets/new_product_screen.dart';
import 'package:shopping_list/ui/catalog/widgets/packaging_row.dart';
import 'package:shopping_list/ui/purchase/widgets/scale_store_dialog.dart';
import 'package:shopping_list/ui/store/view_model/store_view_model.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/auth.dart';
import '../helpers/barcode_camera.dart';
import '../helpers/barcode_owners.dart';
import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/shopping_list.dart';

void main() {
  const cola = '7894900011517';
  const coffee = '7891000100103';
  const guarana = '7894900530018';
  const cocoa = '7891000053508';

  final cola2l = BarcodeOwner(
    product: Product(
      id: 'prod-3',
      productRegistrationId: 'reg-1',
      packaging: Packaging(pieceCount: 1, pieceSize: 2000, baseUnit: BaseUnit.milliliter),
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: 'brand-1',
      description: 'original',
      sellingMode: SellingMode.byPiece,
    ),
    type: ProductType(id: 'type-1', name: 'Refrigerante', categoryId: 'cat-1', baseUnit: BaseUnit.milliliter),
    brand: Brand(id: 'brand-1', name: 'Coca-Cola'),
  );
  final cola2lOff = BarcodeOwner(
    product: cola2l.product.deactivated(),
    registration: cola2l.registration,
    type: cola2l.type,
    brand: cola2l.brand,
  );

  /// Mounted through the real router: screen 4 asks `context.canPop()` to
  /// decide which exit R11 gives it, and that question has no answer without
  /// a GoRouter above it.
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    CatalogRepository? repository,
    NewProductRequest? request,
    FakeBarcodeCamera? camera,
    StoreRepository? stores,
  }) async {
    // A tall viewport: screen 4 is a long form, and the default 800×600 puts
    // the second packaging row outside the render tree, where a tap misses.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        authOverride(),
        catalogOverride(repository: repository),
        storeOverride(repository: stores),
        ?camera?.override,
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

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('save')));

  Finder looseCaption(int id) => find.byKey(ValueKey('loose-caption-$id'));

  /// Turns card `id` into the `A granel` one, the only way a product goes loose.
  Future<void> turnLoose(WidgetTester tester, int id) async {
    await tapOn(tester, find.descendant(of: find.byKey(ValueKey('kind-$id')), matching: find.text('A granel')));
  }

  /// The one field inside the open dialog — `find.byType(TextField)` alone
  /// also matches the description field of the screen behind it.
  final dialogField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

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

  Future<void> includeTyped(WidgetTester tester, int card, String code) async {
    await type(tester, ValueKey('barcode-$card'), code);
    await tapOn(tester, find.byKey(ValueKey('barcode-add-$card')));
  }

  Future<void> pickRefrigerante(WidgetTester tester) async {
    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
  }

  testWidgets('asks for the type before offering any measure', (tester) async {
    // Without a type the screen does not know which magnitude the line is
    // typed in, and a line typed in the wrong one is how a soft drink ends up
    // adding volume to a weight total.
    await pumpScreen(tester);

    expect(find.text('Escolha o tipo do produto primeiro.'), findsOneWidget);
    expect(find.text('Unidade: escolha o tipo do produto primeiro'), findsOneWidget);
  });

  testWidgets('takes the base unit from the type, never from the product', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    expect(find.text('Unidade: mililitro (vem do tipo)'), findsOneWidget);
  });

  testWidgets('the line is typed in the magnitude of the type, with no '
      'measure to pick', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    // The field simply says which unit it is typed in — there is no dropdown
    // through which a '350 g' of soft drink could be typed.
    expect(find.text('Quanto tem cada?'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<BaseUnit>), findsNothing);
  });

  testWidgets('names the packaging the way the shelf does', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');

    // "350 ml", not "1 × 350 ml": that is the name searched for at the till.
    expect(find.text('Vai se chamar: 350 ml'), findsOneWidget);
    expect(find.text('Salvar produto'), findsOneWidget);
  });

  testWidgets('refuses two lines holding the same amount, however typed', (tester) async {
    // By CONTENT, not by text: 2 × 175 ml is the same packaging as 350 ml,
    // because the comparison happens on the total.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');

    await tapOn(tester, find.text('Adicionar outra embalagem'));
    await type(tester, const ValueKey('count-2'), '2');
    await type(tester, const ValueKey('size-2'), '175');

    expect(find.text('Essa embalagem já está na lista'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('counts how many products are about to be born', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');

    await tapOn(tester, find.text('Adicionar outra embalagem'));
    await type(tester, const ValueKey('size-2'), '2000');

    // Each line becomes a product of its own, with its own price history.
    expect(find.text('Salvar 2 produtos'), findsOneWidget);
  });

  testWidgets('keeps the loose card loose when the type changes', (tester) async {
    await pumpScreen(tester);

    // No category chosen on purpose: the type field then lists every type,
    // which is what puts a kilogram and a litre one behind the same dropdown.
    await choose(tester, const ValueKey('field-type'), 'Acém moído');
    // Without a description the identity matches `reg-2` and the screen locks.
    await type(tester, const ValueKey('field-description'), 'moído fino');
    await leaveField(tester);
    await turnLoose(tester, 1);
    expect(find.text('Vendido por kg'), findsOneWidget);

    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    // The card stayed loose — only the unit that names it moved.
    expect(looseCaption(1), findsOneWidget);
    expect(find.text('Vendido por L'), findsOneWidget);
    expect(find.text('Embalagens deste produto'), findsOneWidget);
  });

  testWidgets('opens without the Vendido field', (tester) async {
    await pumpScreen(tester);
    await choose(tester, const ValueKey('field-category'), 'Carnes');
    await choose(tester, const ValueKey('field-type'), 'Acém moído');

    expect(find.text('Vendido'), findsNothing);
    expect(find.text('Embalagens deste produto'), findsOneWidget);
    expect(find.byKey(const ValueKey('kind-1')), findsOneWidget);
  });

  testWidgets('a counted type takes the loose card', (tester) async {
    await pumpScreen(tester);
    await choose(tester, const ValueKey('field-category'), 'Limpeza');
    await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

    await turnLoose(tester, 1);

    expect(looseCaption(1), findsOneWidget);
    expect(find.text('Vendido por un'), findsOneWidget);
  });

  testWidgets('warns and blocks when the identity is already taken', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    // The warning arrives when the description LEAVES the field.
    await leaveField(tester);

    expect(find.text('Esse produto já está cadastrado, com 4 embalagens.'), findsOneWidget);
    // Blocked while the repetition exists: changing the description to "zero"
    // unblocks it on the spot, because then it is another product.
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('opens the blocked registration instead of dead-ending', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);

    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    // The packagings it already has are on screen, and the line being built
    // came along instead of being thrown away.
    expect(find.text('Já cadastradas neste produto (4)'), findsOneWidget);
    expect(find.text('Acrescentando embalagem a um produto que já existe.'), findsOneWidget);
  });

  testWidgets('keeps the packaging lines open when a check lands after opening', (tester) async {
    // On the web the tap on the button blurs the description first, so an
    // identity check is still on its way when the registration opens. Its
    // answer must not bring the conflict back and disable every line.
    final repository = _GatedIdentity();
    await pumpScreen(tester, repository: repository);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);

    final gate = repository.gate = Completer<void>();
    await tester.showKeyboard(find.byKey(const ValueKey('field-description')));
    await leaveField(tester);
    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Acrescentando embalagem a um produto que já existe.'), findsOneWidget);
    expect(tester.widget<PackagingRow>(find.byType(PackagingRow)).enabled, isTrue);
  });

  testWidgets('refuses a packaging the registration already has', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);
    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    // 0,35 L is the 350 ml bottle that is already saved.
    await type(tester, const ValueKey('size-1'), '350');

    expect(find.text('Essa embalagem já está na lista'), findsOneWidget);
  });

  testWidgets('registers a category without leaving the screen', (tester) async {
    await pumpScreen(tester);

    await tapOn(tester, find.byTooltip('Nova categoria'));
    await tester.enterText(dialogField, 'Padaria');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    await choose(tester, const ValueKey('field-category'), 'Padaria');
  });

  testWidgets('answers the duplicate inside the dialog, next to the field', (tester) async {
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
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar')).onPressed, isNull);

    await choose(tester, const ValueKey('field-type-category'), 'Bebidas');
    await tapOn(tester, find.text(BaseUnit.gram.magnitudeLabel));

    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    // The type comes back chosen, with its unit already on screen.
    expect(find.text('Unidade: grama (vem do tipo)'), findsOneWidget);
  });

  testWidgets('offers a retry instead of a spinner when nothing loads', (tester) async {
    await pumpScreen(tester, repository: _FailingRepository());

    expect(find.text('Não foi possível carregar as listas do cadastro.'), findsOneWidget);
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

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Produto salvo.'), findsOneWidget);
    // Saving LEAVES the screen: a registration saved twice is what this
    // avoids, and screen 3 is where H7 will bring it back to.
    //
    // With NO stack — which is how this helper mounts the screen, and which
    // in the app is the typed URL of the PWA — the list is the exit R11
    // asks for. The pushed case is the next one.
    expect(find.text('Lista de compras'), findsOneWidget);
  });

  testWidgets('saving pops back when the screen was pushed', (tester) async {
    final container = await pumpScreen(tester);

    // Mounted again, this time PUSHED over the catalog — the three doors of
    // the maintenance screen all use `push`, and `go` would leave the person
    // on the shopping list, away from the list they were tidying up.
    final router = container.read(appRouterProvider);
    router.go(Routes.catalog);
    await tester.pumpAndSettle();
    router.push(Routes.newProduct);
    await tester.pumpAndSettle();

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'zero');
    await leaveField(tester);
    await type(tester, const ValueKey('size-1'), '350');

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Manutenção do cadastro'), findsOneWidget);
    expect(find.text('Lista de compras'), findsNothing);
  });

  testWidgets('says why it could not save, keeping what was typed', (tester) async {
    await pumpScreen(tester, repository: _RefusingRepository());

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');

    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Sem conexão. Verifique a internet e tente de novo.'), findsOneWidget);
    // An ACTION that failed never takes over the screen — the form is intact.
    expect(find.text('Vai se chamar: 350 ml'), findsOneWidget);
  });

  testWidgets('saves a packaging into the registration that already exists', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);
    await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

    await type(tester, const ValueKey('size-1'), '600');
    await tapOn(tester, find.byKey(const ValueKey('save')));

    expect(find.text('Produto salvo.'), findsOneWidget);
  });

  testWidgets('removes a line and keeps saving the ones that survived', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await tapOn(tester, find.text('Adicionar outra embalagem'));
    await type(tester, const ValueKey('size-2'), '2');
    expect(find.text('Salvar 2 produtos'), findsOneWidget);

    await tapOn(tester, find.widgetWithText(TextButton, 'Remover').first);

    expect(find.text('Salvar produto'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('asks nothing about which packaging is being bought', (tester) async {
    // The radio left in the layout review of 08/09/2026: this screen is the
    // REGISTRATION, and a naked circle on each card asked a question of the
    // purchase in the middle of it. The packaging typed LAST is the one
    // screen 3 gets back, and swapping it there is one tap.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');
    await tapOn(tester, find.text('Adicionar outra embalagem'));
    await type(tester, const ValueKey('size-2'), '2000');

    expect(find.byType(Radio<int>), findsNothing);
    expect(find.text('Vai se chamar: 2 L'), findsOneWidget);
  });

  testWidgets('points at the field that is missing, not at the other one', (tester) async {
    // The count opens filled with "1" and the measure opens empty, so the
    // sentence has to name the MEASURE — and a zero is not the same case as
    // an empty field.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    expect(find.text('Falta dizer quanto tem cada peça'), findsOneWidget);

    await type(tester, const ValueKey('size-1'), '350');
    await type(tester, const ValueKey('count-1'), '');
    expect(find.text('Falta dizer quantas peças'), findsOneWidget);

    await type(tester, const ValueKey('count-1'), '0');
    expect(find.text('Use números maiores que zero'), findsOneWidget);
  });

  testWidgets('never writes a zero on the save button', (tester) async {
    // "Salvar 0 produtos" on a dead button reads as a broken screen. What is
    // missing is said above it instead.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');

    expect(find.textContaining('0 produto'), findsNothing);
    expect(find.text('Falta completar 1 embalagem.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('asks a type counted by unit for the count and nothing else', (tester) async {
    // Egg, toilet paper, bar soap: the base unit IS the piece, so there is no
    // measure to type.
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Limpeza');
    await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

    expect(find.text('Unidade: unidade (vem do tipo)'), findsOneWidget);
    expect(find.text('Quantas unidades?'), findsOneWidget);
    expect(find.byKey(const ValueKey('size-1')), findsNothing);

    await type(tester, const ValueKey('count-1'), '12');
    expect(find.text('Vai se chamar: 12 × 1 un'), findsOneWidget);
  });

  testWidgets('takes the suggested description with one tap', (tester) async {
    await pumpScreen(tester);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');

    // "orig." typed on a distracted day would create a second registration
    // out of nothing — the suggestion is what stops that.
    await tapOn(tester, find.widgetWithText(ActionChip, 'original'));

    expect(find.text('Esse produto já está cadastrado, com 4 embalagens.'), findsOneWidget);
  });

  testWidgets('greys out a deactivated brand instead of hiding it', (tester) async {
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

  testWidgets('the reentrancy guard never says "Produto salvo."', (tester) async {
    // The regression test of the bug the sealed outcome fixed: `save` used to
    // answer `(error: null, saved: null)` when the guard fired, the screen
    // read `error == null` as success, said "Produto salvo." and navigated
    // away — with nothing written. Deleting the `case null` of the screen
    // brings it back, and this test fails. The guard now fires in
    // `checkBarcodes`, which shares `_writingRegistration` with the stuck
    // `save`.
    final repository = _StuckRepository();
    final container = await pumpScreen(tester, repository: repository);

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await type(tester, const ValueKey('size-1'), '350');

    // Holds the write guard down: no `await`, so the call is still in flight
    // when the button is tapped. `_saving` of the widget is still false here,
    // so the button IS clickable and the tap really reaches the guard.
    unawaited(
      container
          .read(catalogViewModelProvider.notifier)
          .save(
            registration: ProductRegistration(productTypeId: 'type-1', sellingMode: SellingMode.byPiece),
            packagings: [
              PackagingWithBarcodes(
                packaging: Packaging.typed(pieceCount: '1', pieceSize: '350', baseUnit: BaseUnit.milliliter),
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
    final save = tester.widget<FilledButton>(find.byKey(const ValueKey('save')));
    expect(save.onPressed, isNotNull);

    repository.release();
    await tester.pumpAndSettle();
  });

  group('PackagingDraft barcodes', () {
    final draft = PackagingDraft(id: 1, pieceCount: '2', pieceSize: '350', unit: BaseUnit.milliliter);

    test('withBarcode adds the code and keeps the rest of the line', () {
      final updated = draft.withBarcode(cola);
      expect(updated.barcodes, [Barcode.typed(cola)].lock);
      expect(updated.pieceCount, '2');
      expect(updated.pieceSize, '350');
      expect(updated.unit, BaseUnit.milliliter);
    });

    test('withBarcode lets the domain refusal through', () {
      expect(() => draft.withBarcode(cola).withBarcode(cola), throwsA(isA<BarcodeAlreadyOnPackaging>()));
    });

    test('withUnit and copyWith keep the codes', () {
      final coded = draft.withBarcode(cola);
      expect(coded.withUnit(BaseUnit.gram).barcodes, coded.barcodes);
      expect(coded.copyWith(pieceSize: '1').barcodes, coded.barcodes);
    });

    test('withoutBarcode removes only that code', () {
      final coded = draft.withBarcode(cola).withBarcode(coffee);
      expect(coded.withoutBarcode(Barcode.typed(cola)).barcodes, [Barcode.typed(coffee)].lock);
    });
  });

  group('NewProductRequest', () {
    test('equality covers every field', () {
      final request = NewProductRequest(initialBarcode: Barcode.typed(cola));
      final same = NewProductRequest(initialBarcode: Barcode.typed(cola));
      expect(request, same);
      expect(request.hashCode, same.hashCode);
      expect(request, isNot(const NewProductRequest()));
      expect(request, isNot(NewProductRequest(initialBarcode: Barcode.typed(coffee))));
    });
  });

  group('barcodes on the card', () {
    IconButton addButton(WidgetTester tester) => tester.widget<IconButton>(find.byKey(const ValueKey('barcode-add-1')));

    testWidgets('a typed code goes in with + and the field empties', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      expect(find.text('Nenhum código.'), findsOneWidget);

      await includeTyped(tester, 1, cola);

      expect(find.text('• $cola'), findsOneWidget);
      expect(find.text('Nenhum código.'), findsNothing);
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('+ is off while the field is empty', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      expect(addButton(tester).onPressed, isNull);

      await type(tester, const ValueKey('barcode-1'), '   ');
      expect(addButton(tester).onPressed, isNull);

      await type(tester, const ValueKey('barcode-1'), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('barcode-error-1')), findsNothing);
    });

    testWidgets('x removes the code', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await includeTyped(tester, 1, cola);

      await tapOn(tester, find.byKey(ValueKey('barcode-remove-1-${Barcode.typed(cola).code}')));

      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('refuses the same code twice on the card', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await includeTyped(tester, 1, cola);
      await includeTyped(tester, 1, cola);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('barcode-error-1')),
          matching: find.text('Esse código já está nesta embalagem.'),
        ),
        findsNothing,
      );
      expect(find.text('Esse código já está nesta embalagem.'), findsOneWidget);
      expect(find.text('• $cola'), findsOneWidget);
    });

    testWidgets('refuses a scale code with the scale sentence', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await includeTyped(tester, 1, '2822521001605');

      expect(find.text('Esse é um código de balança.'), findsOneWidget);
      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('refuses an invalid code', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await includeTyped(tester, 1, '7894900011518');

      expect(find.text('Código de barras inválido.'), findsOneWidget);

      await type(tester, const ValueKey('barcode-1'), '7');
      expect(find.text('Código de barras inválido.'), findsNothing);
    });

    testWidgets('a camera read goes straight into the list, with no +', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await pickRefrigerante(tester);

      await tapOn(tester, find.byKey(const ValueKey('barcode-scan-1')));
      camera.read(cola);
      await tester.pumpAndSettle();

      expect(find.text('• $cola'), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-camera')), findsNothing);
    });

    testWidgets('a scale label read by the camera is refused', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await pickRefrigerante(tester);

      await tapOn(tester, find.byKey(const ValueKey('barcode-scan-1')));
      camera.read('02822521001605261107');
      await tester.pumpAndSettle();

      expect(find.text('Esse é um código de balança.'), findsOneWidget);
      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('initialBarcode fills the first card', (tester) async {
      await pumpScreen(tester, request: NewProductRequest(initialBarcode: Barcode.typed(cola)));
      await pickRefrigerante(tester);

      expect(find.text('• $cola'), findsOneWidget);
    });

    testWidgets('a new card takes the code of a card still incomplete', (tester) async {
      await pumpScreen(tester, request: NewProductRequest(initialBarcode: Barcode.typed(cola)));
      await pickRefrigerante(tester);

      await tapOn(tester, find.text('Adicionar outra embalagem'));

      final rows = tester.widgetList<PackagingRow>(find.byType(PackagingRow)).toList();
      expect(rows.first.draft.barcodes, isEmpty);
      expect(rows.last.draft.barcodes, [Barcode.typed(cola)]);
      expect(find.text('• $cola'), findsOneWidget);
    });

    testWidgets('a complete card keeps its code when another is added', (tester) async {
      await pumpScreen(tester, request: NewProductRequest(initialBarcode: Barcode.typed(cola)));
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');

      await tapOn(tester, find.text('Adicionar outra embalagem'));

      final rows = tester.widgetList<PackagingRow>(find.byType(PackagingRow)).toList();
      expect(rows.first.draft.barcodes, [Barcode.typed(cola)]);
      expect(rows.last.draft.barcodes, isEmpty);
    });

    testWidgets('saves 0, 1 and 3 codes, each on its own card', (tester) async {
      final repository = _WithOwners();
      await pumpScreen(tester, repository: repository);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await type(tester, const ValueKey('size-2'), '2000');
      await includeTyped(tester, 2, cola);
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await type(tester, const ValueKey('size-3'), '269');
      await includeTyped(tester, 3, coffee);
      await includeTyped(tester, 3, guarana);
      await includeTyped(tester, 3, cocoa);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(repository.saved?.map((p) => p.barcodes).toList(), [
        const IList<Barcode>.empty(),
        [Barcode.typed(cola)].lock,
        [Barcode.typed(coffee), Barcode.typed(guarana), Barcode.typed(cocoa)].lock,
      ]);
      expect(repository.findOwnersCalls, 1);
    });

    testWidgets('a code of an active product blocks the save above the '
        'button', (tester) async {
      final repository = _WithOwners(owners: {Barcode.typed(cola): cola2l});
      await pumpScreen(tester, repository: repository);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Esse código já é do ${cola2l.label}.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(repository.saved, isNull);

      // Typing a measure is not touching a code: the block stays.
      await type(tester, const ValueKey('size-1'), '351');
      expect(saveButton(tester).onPressed, isNull);

      await tapOn(tester, find.byKey(ValueKey('barcode-remove-1-${Barcode.typed(cola).code}')));
      expect(find.text('Esse código já é do ${cola2l.label}.'), findsNothing);
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('the same code on two cards is refused before the database', (tester) async {
      final repository = _WithOwners();
      await pumpScreen(tester, repository: repository);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await type(tester, const ValueKey('size-2'), '2000');
      await includeTyped(tester, 2, cola);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Esse código já está em outra embalagem desta tela.'), findsOneWidget);
      expect(repository.findOwnersCalls, 0);
      expect(repository.saved, isNull);
    });

    testWidgets('a code of a deactivated product saves without asking and '
        'says so', (tester) async {
      final repository = _WithOwners(owners: {Barcode.typed(cola): cola2lOff});
      await pumpScreen(tester, repository: repository);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.removedFrom, ['prod-3']);
      expect(find.textContaining('Produto salvo.'), findsOneWidget);
      expect(find.textContaining(releasedBarcodeMessage(cola2lOff)), findsOneWidget);
      expect(repository.saved?.single.barcodes, [Barcode.typed(cola)].lock);
    });

    testWidgets('a failing check keeps the form and says why', (tester) async {
      final repository = _WithOwners(failFind: true);
      await pumpScreen(tester, repository: repository);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Sem conexão. Verifique a internet e tente de novo.'), findsOneWidget);
      expect(find.text('Vai se chamar: 350 ml'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
      expect(repository.saved, isNull);
    });

    testWidgets('the saved packagings show their codes, read only', (tester) async {
      await pumpScreen(
        tester,
        repository: _WithSavedCodes(cola),
        request: const NewProductRequest(registrationId: 'reg-1'),
      );

      await tapOn(tester, find.byKey(const ValueKey('existing-packagings')));

      expect(tester.widget<Text>(find.byKey(const ValueKey('existing-barcodes-prod-1'))).data, cola);
      expect(
        find.descendant(of: find.byKey(const ValueKey('existing-packagings')), matching: find.byIcon(Icons.close)),
        findsNothing,
      );
    });
  });

  group('PickedProduct', () {
    PickedProduct picked({String leafId = 'prod-1', Brand? brand}) => PickedProduct(
      product: Product(id: leafId, productRegistrationId: 'reg-1'),
      registration: ProductRegistration(id: 'reg-1', productTypeId: 'type-1', sellingMode: SellingMode.byPiece),
      type: ProductType(id: 'type-1', name: 'Refrigerante', categoryId: 'cat-1', baseUnit: BaseUnit.milliliter),
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
  testWidgets('the ≡ door opens the registration already loaded', (tester) async {
    // Arriving from the catalog maintenance: the fields come filled and
    // EDITABLE (M-b), and the four packagings that exist are on screen. It
    // lands in the very state H2 wrote for the registration blocked by
    // repetition — no second path through this screen.
    await pumpScreen(tester, request: const NewProductRequest(registrationId: 'reg-1'));

    expect(find.text('Editar produto'), findsOneWidget);
    expect(find.text('Editando um produto que já existe.'), findsOneWidget);
    expect(find.text('Já cadastradas neste produto (4)'), findsOneWidget);
  });

  testWidgets('the packaging lines being typed come before the ones already '
      'registered', (tester) async {
    // The maintenance path: four packagings already registered, which used to
    // sit ON TOP of the line being typed and pushed it down by four rows.
    await pumpScreen(tester, request: const NewProductRequest(registrationId: 'reg-1'));

    expect(find.text('Já cadastradas neste produto (4)'), findsOneWidget);
    // Editing opens with no line: the first one is asked for.
    await tapOn(tester, find.text('Adicionar embalagem'));
    // Geometric on purpose: nothing here is renamed, only reordered, and
    // order is the only thing an assertion can see.
    expect(
      tester.getTopLeft(find.byType(PackagingRow).first).dy,
      lessThan(tester.getTopLeft(find.text('Já cadastradas neste produto (4)')).dy),
      reason: 'what is already registered is above what is being typed',
    );
  });

  testWidgets('a registration that is not there says so, and opens blank', (tester) async {
    await pumpScreen(tester, request: const NewProductRequest(registrationId: 'nope'));

    expect(find.text('Não encontrei esse produto. Atualize a lista.'), findsOneWidget);
  });

  testWidgets('the category door offers to reactivate right there', (tester) async {
    final container = await pumpScreen(tester, repository: _WithDeactivated(categoryId: 'cat-3'));

    await tapOn(tester, find.byTooltip('Nova categoria'));
    await tester.enterText(dialogField, 'limpeza');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('O cadastro Limpeza existe, mas está desativado.'), findsOneWidget);
    // The sentence lost its destination when the button arrived.
    expect(find.textContaining('manutenção do cadastro'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reactivate')));
    await tester.pumpAndSettle();

    // The dialog closed handing the name back, and the row is active again —
    // which is what puts it in the screen's dropdown.
    expect(find.byType(AlertDialog), findsNothing);
    final categories = container.read(catalogViewModelProvider).value!.categories;
    expect(categories.where((c) => c.id == 'cat-3').single.active, isTrue);
  });

  testWidgets('the brand door offers to reactivate right there', (tester) async {
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

  testWidgets('the type door offers to reactivate, written by hand', (tester) async {
    // This dialog has three fields, so it does not use SingleFieldDialog:
    // the same button is written beside the message it raised.
    await pumpScreen(tester, repository: _WithDeactivated(typeId: 'type-3'));

    await tapOn(tester, find.byTooltip('Novo tipo'));
    await tester.enterText(dialogField, 'papel higienico');
    await choose(tester, const ValueKey('field-type-category'), 'Limpeza');
    await tapOn(tester, find.text(BaseUnit.unit.magnitudeLabel));
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reactivate')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the fourth door: reactivating the registration before adding packaging', (tester) async {
    await pumpScreen(tester, repository: _WithDeactivated(registrationId: 'reg-1'));

    await choose(tester, const ValueKey('field-category'), 'Bebidas');
    await choose(tester, const ValueKey('field-type'), 'Refrigerante');
    await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
    await type(tester, const ValueKey('field-description'), 'original');
    await leaveField(tester);

    // Adding leaves to a deactivated registration is writing what nobody
    // will ever see, so the button reactivates first — and says so.
    expect(find.text('Esse produto já existe, mas está desativado.'), findsOneWidget);
    await tapOn(tester, find.text('Reativar e acrescentar embalagem'));

    expect(find.text('Acrescentando embalagem a um produto que já existe.'), findsOneWidget);
  });

  group('editing from the maintenance pencil — M-b', () {
    const editing = NewProductRequest(registrationId: 'reg-1');

    testWidgets('opens with no packaging line and the save button off', (tester) async {
      await pumpScreen(tester, request: editing);

      expect(find.byType(PackagingRow), findsNothing);
      expect(saveButton(tester).onPressed, isNull);
      expect(find.text('Salvar alterações'), findsOneWidget);
      expect(find.text('Mude algum campo ou acrescente uma embalagem.'), findsOneWidget);
    });

    testWidgets('description, brand and type are editable; category is not', (tester) async {
      await pumpScreen(tester, request: editing);

      final description = tester.widget<TextField>(
        find.descendant(of: find.byKey(const ValueKey('field-description')), matching: find.byType(TextField)),
      );
      expect(description.enabled, isNot(false));
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.descendant(
                of: find.byKey(const ValueKey('field-brand')),
                matching: find.byType(DropdownButton<String?>),
              ),
            )
            .onChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: find.byKey(const ValueKey('field-type')),
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .onChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: find.byKey(const ValueKey('field-category')),
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .onChanged,
        isNull,
      );
      // A new type could measure another magnitude.
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add).at(1)).onPressed, isNull);
      // The category is shown, from the type, even though it is locked.
      expect(find.text('Bebidas'), findsOneWidget);
    });

    testWidgets('the type list offers only types of the same base unit', (tester) async {
      await pumpScreen(tester, request: editing);

      await tapOn(tester, find.byKey(const ValueKey('field-type')));

      // Refrigerante is in millilitres; Acém moído is in grams.
      expect(find.text('Acém moído'), findsNothing);
      expect(find.text('Refrigerante'), findsWidgets);
    });

    testWidgets('changing the description enables save and pops on success', (tester) async {
      final repository = _RecordingRepository();
      await pumpScreen(tester, repository: repository, request: editing);

      await type(tester, const ValueKey('field-description'), 'zero');
      await leaveField(tester);
      expect(saveButton(tester).onPressed, isNotNull);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(repository.updated?.description, 'zero');
      expect(repository.added, isNull);
    });

    testWidgets('adding a packaging alone saves it', (tester) async {
      final repository = _RecordingRepository();
      await pumpScreen(tester, repository: repository, request: editing);

      await tapOn(tester, find.text('Adicionar embalagem'));
      await type(tester, const ValueKey('size-1'), '600');
      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(repository.updated, isNull);
      expect(repository.added, hasLength(1));
    });

    testWidgets('an identity another registration holds blocks save without '
        'the open button', (tester) async {
      await pumpScreen(tester, repository: _RecordingRepository(holdsZero: true), request: editing);

      await type(tester, const ValueKey('field-description'), 'zero');
      await leaveField(tester);

      expect(find.byKey(const ValueKey('edit-conflict')), findsOneWidget);
      expect(find.text('Já existe esse produto cadastrado.'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-conflict')), findsNothing);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a packaging failure after the identity was written keeps the '
        'screen', (tester) async {
      final repository = _RecordingRepository(refusesPackagings: true);
      await pumpScreen(tester, repository: repository, request: editing);

      await type(tester, const ValueKey('field-description'), 'zero');
      await leaveField(tester);
      await tapOn(tester, find.text('Adicionar embalagem'));
      await type(tester, const ValueKey('size-1'), '600');
      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Sem conexão. Verifique a internet e tente de novo.'), findsOneWidget);
      expect(find.text('Produto salvo.'), findsNothing);
      expect(find.text('Editar produto'), findsOneWidget);
      expect(repository.updated?.description, 'zero');
      // The identity written is the new original: what is left to save is
      // the packaging alone, and the button still offers it.
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('editing a loose-only product saves the identity alone', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(registrationId: 'reg-2'));

      expect(find.text('Embalagens deste produto'), findsOneWidget);
      expect(find.text('Mude algum campo ou acrescente uma embalagem.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);

      await tapOn(tester, find.byKey(const ValueKey('existing-packagings')));
      expect(find.text('A granel (por kg)'), findsOneWidget);

      await type(tester, const ValueKey('field-description'), 'fino');
      await leaveField(tester);
      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text('Produto salvo.'), findsOneWidget);
    });

    testWidgets('the conflict path still locks the identity', (tester) async {
      await pumpScreen(tester);

      await choose(tester, const ValueKey('field-category'), 'Bebidas');
      await choose(tester, const ValueKey('field-type'), 'Refrigerante');
      await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
      await type(tester, const ValueKey('field-description'), 'original');
      await leaveField(tester);
      await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

      expect(find.text('Novo produto'), findsOneWidget);
      final description = tester.widget<TextField>(
        find.descendant(of: find.byKey(const ValueKey('field-description')), matching: find.byType(TextField)),
      );
      expect(description.enabled, isFalse);
    });
  });
  group('scale codes', () {
    const tamara = '2822521001605';
    const tamaraQr = '02822521001605261107';
    const other = '2004417001603';
    const storeKey = ValueKey('scale-store');

    Future<void> toLoose(WidgetTester tester) async {
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      // Without a description the identity matches `reg-2` and the screen locks.
      await type(tester, const ValueKey('field-description'), 'moído fino');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await turnLoose(tester, 1);
    }

    Future<void> includeScale(WidgetTester tester, String store, String raw) async {
      await choose(tester, storeKey, store);
      await type(tester, const ValueKey('scale-code'), raw);
      await tapOn(tester, find.byKey(const ValueKey('scale-add')));
    }

    bool buttonOn(WidgetTester tester, Key key) => tester.widget<IconButton>(find.byKey(key)).onPressed != null;

    TextField fieldOf(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(of: find.byKey(const ValueKey('scale-code')), matching: find.byType(TextField)),
    );

    testWidgets('a packaging card has no scale code section', (tester) async {
      await pumpScreen(tester);
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      expect(find.byKey(const ValueKey('scale-codes')), findsNothing);

      await toLoose(tester);
      expect(find.byKey(const ValueKey('scale-codes')), findsOneWidget);
    });

    testWidgets('a typed label goes in with its store and the field empties', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);

      await includeScale(tester, 'Carrefour', tamara);

      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
      expect(find.text('Nenhum código.'), findsNothing);
      expect(fieldOf(tester).controller?.text, isEmpty);
    });

    testWidgets('+, ▥ and the field are off until a store is chosen', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);

      expect(fieldOf(tester).enabled, isFalse);
      expect(buttonOn(tester, const ValueKey('scale-scan')), isFalse);
      expect(buttonOn(tester, const ValueKey('scale-add')), isFalse);

      await choose(tester, storeKey, 'Carrefour');
      expect(fieldOf(tester).enabled, isTrue);
      expect(buttonOn(tester, const ValueKey('scale-scan')), isTrue);
    });

    testWidgets('a failed store load offers to try again', (tester) async {
      final stores = _FlakyStores();
      await pumpScreen(tester, stores: stores);
      await toLoose(tester);

      expect(find.text('Não foi possível carregar os mercados.'), findsOneWidget);

      await tapOn(tester, find.text('Tentar de novo'));

      expect(find.byKey(storeKey), findsOneWidget);
      expect(find.text('Não foi possível carregar os mercados.'), findsNothing);
    });

    testWidgets('the inactive store is not offered', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);

      await tapOn(tester, find.byKey(storeKey));

      expect(find.text('Feira do Bairro'), findsWidgets);
      expect(find.text('Mercearia do Zé'), findsNothing);
    });

    testWidgets('a camera read keeps only the item code', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLoose(tester);
      await choose(tester, storeKey, 'Carrefour');

      await tapOn(tester, find.byKey(const ValueKey('scale-scan')));
      camera.read(tamaraQr);
      await tester.pumpAndSettle();

      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('the same code twice in the same store is refused under the '
        'field', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);
      await includeScale(tester, 'Carrefour', tamara);

      await type(tester, const ValueKey('scale-code'), tamaraQr);
      await tapOn(tester, find.byKey(const ValueKey('scale-add')));

      expect(tester.widget<Text>(find.byKey(const ValueKey('scale-error'))).data, 'Esse código já está neste produto.');
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('the same code in another store is taken', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);

      await includeScale(tester, 'Carrefour', tamara);
      await includeScale(tester, 'Feira do Bairro', tamara);

      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
      expect(find.text('• Feira do Bairro · 2822521'), findsOneWidget);
    });

    testWidgets('what is not a scale label is refused', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);

      await includeScale(tester, 'Carrefour', '7894900011517');
      expect(find.text('Não conheço esta etiqueta.'), findsOneWidget);

      await type(tester, const ValueKey('scale-code'), '78949');
      expect(find.text('Não conheço esta etiqueta.'), findsNothing);
    });

    testWidgets('x removes the code before saving', (tester) async {
      await pumpScreen(tester);
      await toLoose(tester);
      await includeScale(tester, 'Carrefour', tamara);

      await tapOn(tester, find.byKey(const ValueKey('scale-remove-store-1-2822521')));

      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('saving sends the scale codes', (tester) async {
      final repository = _ScaleSpy();
      await pumpScreen(tester, repository: repository);
      await toLoose(tester);
      await includeScale(tester, 'Carrefour', tamara);
      await includeScale(tester, 'Feira do Bairro', other);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(
        repository.savedScaleCodes,
        [
          const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
          const ScaleCode(storeId: 'store-2', itemCode: '2004417'),
        ].lock,
      );
    });

    testWidgets('removing the loose card sends no scale code', (tester) async {
      final repository = _ScaleSpy();
      await pumpScreen(tester, repository: repository);
      await toLoose(tester);
      await includeScale(tester, 'Carrefour', tamara);
      await tapOn(tester, find.text('Remover'));
      await tapOn(tester, find.text('Adicionar embalagem'));
      await type(tester, const ValueKey('count-2'), '1');
      await type(tester, const ValueKey('size-2'), '500');

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(repository.saveCalls, 1);
      expect(repository.savedScaleCodes, isEmpty);
    });

    testWidgets('a code taken in this store by another product is refused on '
        'save', (tester) async {
      await pumpScreen(tester, repository: _ScaleTakenOnSave());
      await toLoose(tester);
      await includeScale(tester, 'Carrefour', tamara);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text(ScaleCode.takenMessage), findsOneWidget);
      expect(find.byKey(const ValueKey('scale-codes')), findsOneWidget);
    });

    group('on a saved product', () {
      const request = NewProductRequest(registrationId: 'reg-2');

      testWidgets('each + writes at once', (tester) async {
        final repository = _WithScaleCodes();
        await pumpScreen(tester, repository: repository, request: request);

        expect(find.text('• Carrefour · 2822521'), findsOneWidget);

        await includeScale(tester, 'Feira do Bairro', other);

        expect(repository.added, [const ScaleCode(storeId: 'store-2', itemCode: '2004417')]);
        expect(find.text('• Feira do Bairro · 2004417'), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);
      });

      testWidgets('x removes at once', (tester) async {
        final repository = _WithScaleCodes();
        await pumpScreen(tester, repository: repository, request: request);

        await tapOn(tester, find.byKey(const ValueKey('scale-remove-store-1-2822521')));

        expect(repository.removed, [const ScaleCode(storeId: 'store-1', itemCode: '2822521')]);
        expect(find.text('Nenhum código.'), findsOneWidget);
      });

      testWidgets('a failed write stays under the field', (tester) async {
        final repository = _WithScaleCodes()..failAdd = ApiException(500, 'boom');
        await pumpScreen(tester, repository: repository, request: request);

        await includeScale(tester, 'Feira do Bairro', other);

        expect(
          tester.widget<Text>(find.byKey(const ValueKey('scale-error'))).data,
          'O servidor está indisponível. Tente de novo em instantes.',
        );
        expect(find.text('• Feira do Bairro · 2004417'), findsNothing);
        expect(find.textContaining('ApiException'), findsNothing);
      });
    });
  });

  group('top read', () {
    const invalid = '7894900011518';
    const storeCode = '2822521000004';
    final topScan = find.byKey(const ValueKey('top-scan'));
    final cameraView = find.byKey(const ValueKey('fake-camera'));

    Future<void> readRaw(WidgetTester tester, FakeBarcodeCamera camera, String raw) async {
      await tapOn(tester, topScan);
      camera.read(raw);
      await tester.pumpAndSettle();
    }

    testWidgets('top read puts an unknown code in the first card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);
      await pickRefrigerante(tester);

      await readRaw(tester, camera, cola);

      expect(find.text('• $cola'), findsOneWidget);
    });

    testWidgets('top read adds a card when every card already has a code', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);
      await pickRefrigerante(tester);
      await readRaw(tester, camera, cola);

      await readRaw(tester, camera, coffee);

      expect(find.byKey(const ValueKey('size-2')), findsOneWidget);
      expect(find.text('• $coffee'), findsOneWidget);
    });

    testWidgets('top read refuses a code already on screen', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);
      await pickRefrigerante(tester);
      await readRaw(tester, camera, cola);

      await readRaw(tester, camera, cola);

      expect(find.text('Esse código já está em outra embalagem desta tela.'), findsOneWidget);
      expect(find.text('• $cola'), findsOneWidget);
    });

    testWidgets('top read of a known code shows who owns it', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        repository: _WithOwners(owners: {Barcode.typed(colaCode): colaOwner}),
        camera: camera,
      );

      await readRaw(tester, camera, colaCode);

      expect(find.text('Já cadastrado: ${colaOwner.label}.'), findsOneWidget);
    });

    testWidgets('read another reopens the camera', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        repository: _WithOwners(owners: {Barcode.typed(colaCode): colaOwner}),
        camera: camera,
      );
      await pickRefrigerante(tester);
      await readRaw(tester, camera, colaCode);

      await tester.tap(find.byKey(const ValueKey('known-code-read-another')));
      await tester.pumpAndSettle();
      expect(cameraView, findsOneWidget);
      camera.read(coffee);
      await tester.pumpAndSettle();

      expect(find.text('• $coffee'), findsOneWidget);
    });

    testWidgets('open to edit pushes screen 4 in edit mode', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        repository: _WithOwners(owners: {Barcode.typed(colaCode): colaOwner}),
        camera: camera,
      );
      await readRaw(tester, camera, colaCode);

      await tester.tap(find.byKey(const ValueKey('known-code-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Editar produto'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Novo produto'), findsOneWidget);
    });

    testWidgets('closing the reader changes nothing', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        repository: _WithOwners(owners: {Barcode.typed(colaCode): colaOwner}),
        camera: camera,
      );
      await pickRefrigerante(tester);

      await tapOn(tester, topScan);
      await tester.tap(find.byKey(const ValueKey('reader-close')));
      await tester.pumpAndSettle();
      expect(cameraView, findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      await readRaw(tester, camera, colaCode);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('• $colaCode'), findsNothing);
    });

    testWidgets('top read treats a deactivated owner as unknown', (tester) async {
      final camera = FakeBarcodeCamera();
      final repository = _WithOwners(owners: {Barcode.typed(cola): cola2lOff});
      await pumpScreen(tester, repository: repository, camera: camera);
      await pickRefrigerante(tester);

      await readRaw(tester, camera, cola);
      expect(find.text('• $cola'), findsOneWidget);

      await type(tester, const ValueKey('size-1'), '350');
      await tapOn(tester, find.byKey(const ValueKey('save')));
      expect(find.textContaining(releasedBarcodeMessage(cola2lOff)), findsOneWidget);
    });

    testWidgets('top read refuses an unknown scale label', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);

      await readRaw(tester, camera, storeCode);

      expect(find.text('Não conheço esta etiqueta.'), findsOneWidget);
    });

    testWidgets('top read refuses an invalid code', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);

      await tapOn(tester, topScan);
      await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('reader-typed')), matching: find.byType(TextField)),
        invalid,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reader-use')));
      await tester.pumpAndSettle();

      expect(find.text('Código de barras inválido.'), findsOneWidget);
    });

    testWidgets('top read shows the failure when the lookup fails', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(failFind: true), camera: camera);

      await readRaw(tester, camera, cola);

      expect(find.text('Sem conexão. Verifique a internet e tente de novo.'), findsOneWidget);
    });

    testWidgets('double tap on top read opens one reader', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);

      await tester.tap(topScan);
      await tester.tap(topScan);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reader-close')), findsOneWidget);
    });

    testWidgets('top read is hidden while editing', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(registrationId: 'reg-1'));
      expect(topScan, findsNothing);
    });

    testWidgets('top read is hidden once the conflict opened a product', (tester) async {
      await pumpScreen(tester);
      await choose(tester, const ValueKey('field-category'), 'Bebidas');
      await choose(tester, const ValueKey('field-type'), 'Refrigerante');
      await choose(tester, const ValueKey('field-brand'), 'Coca-Cola');
      await type(tester, const ValueKey('field-description'), 'original');
      await leaveField(tester);
      expect(topScan, findsOneWidget);

      await tapOn(tester, find.text('Abrir e acrescentar embalagem'));

      expect(topScan, findsNothing);
    });

    testWidgets('a barcode read on top with only the loose card adds a packaging card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, repository: _WithOwners(), camera: camera);
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      await leaveField(tester);
      await turnLoose(tester, 1);

      await readRaw(tester, camera, cola);

      expect(find.byKey(const ValueKey('kind-2')), findsOneWidget);
      expect(find.text('Embalagens deste produto'), findsOneWidget);
    });
  });

  group('top read of a scale label', () {
    const tamara = '2822521001605';
    const other = '2004417001603';
    final topScan = find.byKey(const ValueKey('top-scan'));
    final storePanel = find.byKey(const ValueKey('scale-store-close'));
    final strip = find.byKey(const ValueKey('label-store'));
    final change = find.byKey(const ValueKey('label-store-change'));

    Future<void> readLabel(WidgetTester tester, FakeBarcodeCamera camera, String raw) async {
      await tapOn(tester, topScan);
      camera.read(raw);
      await tester.pumpAndSettle();
    }

    Future<void> pickStore(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(ValueKey('scale-store-$id')));
      await tester.pumpAndSettle();
    }

    Future<void> toLooseType(WidgetTester tester) async {
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    testWidgets('top read of a scale label asks the store and adds the code', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);

      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      expect(find.text('• Carrefour · ${ScaleLabel.parse(tamara)!.itemCode}'), findsOneWidget);
      expect(find.text('Etiquetas do mercado: Carrefour'), findsOneWidget);
      expect(looseCaption(1), findsOneWidget);
    });

    testWidgets('a scale label on an empty screen turns the first card loose', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);

      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      expect(looseCaption(1), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('a scale label read before the type waits on a loose card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);

      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await toLooseType(tester);

      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
      expect(looseCaption(1), findsOneWidget);
    });

    testWidgets('a scale label under a counted type goes on a loose card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await choose(tester, const ValueKey('field-category'), 'Limpeza');
      await choose(tester, const ValueKey('field-type'), 'Papel higiênico');

      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      expect(looseCaption(1), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('top read refuses a scale code already on the product', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await readLabel(tester, camera, tamara);

      expect(find.text(const ScaleCodeAlreadyOnProduct().message), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('closing the store picker adds nothing', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await readLabel(tester, camera, tamara);

      await tester.tap(storePanel);
      await tester.pumpAndSettle();

      expect(find.text('• Carrefour · 2822521'), findsNothing);
      expect(strip, findsNothing);
    });

    testWidgets('scale label without stores asks to register a store', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera, stores: _NoActiveStores());

      await readLabel(tester, camera, tamara);

      expect(find.text('Cadastre um mercado antes.'), findsOneWidget);
      expect(storePanel, findsNothing);
    });

    testWidgets('a scale label reloads the stores when they never loaded', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera, stores: _FlakyStores());

      await readLabel(tester, camera, tamara);

      expect(storePanel, findsOneWidget);
    });

    testWidgets('saving a scale code taken in that store shows the taken message', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera, repository: _ScaleTakenOnSave());
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.text(ScaleCode.takenMessage), findsOneWidget);
    });

    testWidgets('a second scale label reuses the remembered store', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await readLabel(tester, camera, other);

      expect(storePanel, findsNothing);
      expect(find.text('• Carrefour · 2004417'), findsOneWidget);
    });

    testWidgets('changing the label store moves the pending codes', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await tapOn(tester, change);
      await pickStore(tester, 'store-2');

      expect(find.text('Etiquetas do mercado: Feira do Bairro'), findsOneWidget);
      expect(find.text('• Feira do Bairro · 2822521'), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsNothing);
    });

    testWidgets('closing the change store picker keeps the store', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await tapOn(tester, change);
      await tester.tap(storePanel);
      await tester.pumpAndSettle();

      expect(find.text('Etiquetas do mercado: Carrefour'), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('double tap on change store opens one picker', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.tap(change, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(ScaleStoreDialog), findsOneWidget);
    });

    testWidgets('a new screen 4 asks the store again', (tester) async {
      final camera = FakeBarcodeCamera();
      final container = await pumpScreen(tester, camera: camera);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');
      final router = container.read(appRouterProvider);

      router.go(Routes.shoppingList);
      await tester.pumpAndSettle();
      router.go(Routes.newProduct);
      await tester.pumpAndSettle();

      expect(strip, findsNothing);
      await readLabel(tester, camera, tamara);
      expect(storePanel, findsOneWidget);
    });

    testWidgets('a deactivated remembered store is asked again', (tester) async {
      final camera = FakeBarcodeCamera();
      final stores = _SwitchableStores();
      final container = await pumpScreen(tester, camera: camera, stores: stores);
      await toLooseType(tester);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');

      stores.carrefourOff = true;
      // Not awaited: the fake clock only moves with the pumps below.
      unawaited(container.read(storeViewModelProvider.notifier).refresh());
      await tester.pumpAndSettle();
      expect(strip, findsNothing);

      await readLabel(tester, camera, other);

      expect(find.byKey(const ValueKey('scale-store-store-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('scale-store-store-1')), findsNothing);
    });
  });

  group('save and read another', () {
    const tamara = '2822521001605';
    final saveAndRead = find.byKey(const ValueKey('save-and-read'));
    final cameraView = find.byKey(const ValueKey('fake-camera'));
    final closeCamera = find.byKey(const ValueKey('reader-close'));

    Future<void> readLabel(WidgetTester tester, FakeBarcodeCamera camera, String raw) async {
      await tapOn(tester, find.byKey(const ValueKey('top-scan')));
      camera.read(raw);
      await tester.pumpAndSettle();
    }

    Future<void> pickStore(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(ValueKey('scale-store-$id')));
      await tester.pumpAndSettle();
    }

    Future<void> toLooseType(WidgetTester tester) async {
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> fillByPiece(WidgetTester tester) async {
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
    }

    testWidgets('save and read another clears the form and opens the camera', (tester) async {
      await pumpScreen(tester, camera: FakeBarcodeCamera());
      await fillByPiece(tester);

      await tapOn(tester, saveAndRead);

      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(cameraView, findsOneWidget);
      expect(find.text('Novo produto'), findsOneWidget);
    });

    testWidgets('save and read another also works for a loose product', (tester) async {
      await pumpScreen(tester, camera: FakeBarcodeCamera());
      await toLooseType(tester);
      await turnLoose(tester, 1);

      await tapOn(tester, saveAndRead);

      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(cameraView, findsOneWidget);
      await tapOn(tester, closeCamera);
      expect(find.text('Escolha o tipo do produto primeiro.'), findsOneWidget);
    });

    testWidgets('closing the camera after save and read another leaves a blank form', (tester) async {
      await pumpScreen(tester, camera: FakeBarcodeCamera());
      await fillByPiece(tester);
      await tapOn(tester, saveAndRead);

      await tapOn(tester, closeCamera);

      expect(find.text('Bebidas'), findsNothing);
      expect(find.text('Escolha o tipo do produto primeiro.'), findsOneWidget);
      await pickRefrigerante(tester);
      expect(find.byKey(const ValueKey(1)), findsNothing);
      expect(find.byKey(const ValueKey(2)), findsOneWidget);
    });

    testWidgets('the next read after saving fills the fresh card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);
      await tapOn(tester, saveAndRead);

      camera.read(coffee);
      await tester.pumpAndSettle();
      await pickRefrigerante(tester);

      expect(find.text('• $coffee'), findsOneWidget);
      expect(find.text('• $cola'), findsNothing);
    });

    testWidgets('save and read another keeps the form when a code is taken', (tester) async {
      final repository = _WithOwners(owners: {Barcode.typed(cola): cola2l});
      await pumpScreen(tester, repository: repository, camera: FakeBarcodeCamera());
      await fillByPiece(tester);
      await includeTyped(tester, 1, cola);

      await tapOn(tester, saveAndRead);

      expect(find.text('Esse código já é do ${cola2l.label}.'), findsOneWidget);
      expect(cameraView, findsNothing);
      expect(repository.saved, isNull);
    });

    testWidgets('save and read another keeps the form when saving fails', (tester) async {
      await pumpScreen(tester, repository: _RefusingRepository(), camera: FakeBarcodeCamera());
      await fillByPiece(tester);

      await tapOn(tester, saveAndRead);

      expect(find.text('Sem conexão. Verifique a internet e tente de novo.'), findsOneWidget);
      expect(find.text('Vai se chamar: 350 ml'), findsOneWidget);
      expect(cameraView, findsNothing);
    });

    testWidgets('double tap on save and read another saves once', (tester) async {
      final repository = _ScaleSpy();
      await pumpScreen(tester, repository: repository, camera: FakeBarcodeCamera());
      await fillByPiece(tester);
      await tester.ensureVisible(saveAndRead);
      await tester.pumpAndSettle();

      await tester.tap(saveAndRead);
      await tester.tap(saveAndRead);
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(find.text('Produto salvo.'), findsOneWidget);
    });

    testWidgets('save and read another is hidden when returning a selection', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(returnsSelection: true));

      expect(saveAndRead, findsNothing);
      expect(find.byKey(const ValueKey('save')), findsOneWidget);
    });

    testWidgets('save and read another is hidden while editing', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(registrationId: 'reg-1'));

      expect(saveAndRead, findsNothing);
      expect(find.text('Salvar alterações'), findsOneWidget);
    });

    testWidgets('save and read another is disabled while saving is blocked', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(saveAndRead);
      expect(tester.widget<OutlinedButton>(saveAndRead).onPressed, isNull);
    });

    testWidgets('save and read another clears the pending scale codes but keeps the label store', (tester) async {
      final camera = FakeBarcodeCamera();
      final repository = _ScaleSpy();
      await pumpScreen(tester, repository: repository, camera: camera);
      await toLooseType(tester);
      await turnLoose(tester, 1);
      await readLabel(tester, camera, tamara);
      await pickStore(tester, 'store-1');
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);

      await tapOn(tester, saveAndRead);

      expect(repository.savedScaleCodes, [const ScaleCode(storeId: 'store-1', itemCode: '2822521')].lock);
      await tapOn(tester, closeCamera);
      expect(find.text('Etiquetas do mercado: Carrefour'), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsNothing);
    });
  });

  group('initialScaleCode', () {
    const scaleCode = ScaleCode(storeId: 'store-1', itemCode: '2822521');

    test('NewProductRequest compares initialScaleCode', () {
      const a = NewProductRequest(initialScaleCode: scaleCode);
      const b = NewProductRequest(initialScaleCode: scaleCode);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const NewProductRequest(
            initialScaleCode: ScaleCode(storeId: 'store-2', itemCode: '2822521'),
          ),
        ),
      );
      expect(a, isNot(const NewProductRequest()));
    });

    testWidgets('initialScaleCode starts the remembered store', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(initialScaleCode: scaleCode));

      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      await leaveField(tester);

      expect(find.text('Etiquetas do mercado: Carrefour'), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
    });

    testWidgets('initialScaleCode opens a loose card', (tester) async {
      await pumpScreen(tester, request: const NewProductRequest(initialScaleCode: scaleCode));
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      await leaveField(tester);

      expect(looseCaption(1), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
      expect(find.text('Salvar produto'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });
  });

  group('loose card — part 6', () {
    const tamara = '2822521001605';

    Finder kind(int id) => find.byKey(ValueKey('kind-$id'));
    Finder looseOption(int id) => find.descendant(of: kind(id), matching: find.text('A granel'));

    bool looseEnabled(WidgetTester tester, int id) =>
        tester.widget<SegmentedButton<bool>>(kind(id)).segments.firstWhere((segment) => segment.value).enabled;

    Future<void> goLoose(WidgetTester tester, int id) async => tapOn(tester, looseOption(id));

    Future<void> pickAcem(WidgetTester tester) async {
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await type(tester, const ValueKey('field-description'), 'moído fino');
      await leaveField(tester);
    }

    // The bug path: the identity of `reg-2` (loose leaf only) is typed and the
    // registration is opened to add a packaging.
    Future<void> openAcem(WidgetTester tester) async {
      await choose(tester, const ValueKey('field-category'), 'Carnes');
      await choose(tester, const ValueKey('field-type'), 'Acém moído');
      await leaveField(tester);
      await tapOn(tester, find.text('Abrir e acrescentar embalagem'));
    }

    Future<void> addScale(WidgetTester tester, String raw) async {
      await choose(tester, const ValueKey('scale-store'), 'Carrefour');
      await type(tester, const ValueKey('scale-code'), raw);
      await tapOn(tester, find.byKey(const ValueKey('scale-add')));
    }

    testWidgets('saves packagings without a loose leaf', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.savedLoose, isFalse);
      expect(spy.savedPackagings, hasLength(1));
    });

    testWidgets('saves a loose-only registration', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await pickAcem(tester);
      await goLoose(tester, 1);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.savedLoose, isTrue);
      expect(spy.savedPackagings, isEmpty);
    });

    testWidgets('saves a packaging and the loose leaf together', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await goLoose(tester, 2);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.savedLoose, isTrue);
      expect(spy.savedPackagings, hasLength(1));
    });

    testWidgets('offers the loose card on a unit type', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);

      expect(looseEnabled(tester, 1), isTrue);
    });

    testWidgets('adds a packaging to a registration that only had the loose leaf', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await openAcem(tester);
      await type(tester, const ValueKey('size-1'), '500');

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.addedLoose, isFalse);
      expect(spy.addedPackagings, hasLength(1));
    });

    testWidgets('disables the loose option when the registration already has one', (tester) async {
      await pumpScreen(tester);
      await openAcem(tester);

      expect(looseEnabled(tester, 1), isFalse);
    });

    testWidgets('allows a single loose card on screen', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await goLoose(tester, 2);
      await tapOn(tester, find.text('Adicionar outra embalagem'));

      expect(looseEnabled(tester, 2), isTrue);
      expect(looseEnabled(tester, 3), isFalse);
    });

    testWidgets('keeps the barcode card out of the loose option', (tester) async {
      await pumpScreen(tester);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');
      await includeTyped(tester, 1, cola);

      expect(looseEnabled(tester, 1), isFalse);
    });

    testWidgets('keeps the pending scale code on the loose card', (tester) async {
      await pumpScreen(tester);
      await pickAcem(tester);
      await goLoose(tester, 1);
      await addScale(tester, tamara);

      expect(find.byKey(const ValueKey('scale-codes')), findsOneWidget);
      expect(find.text('• Carrefour · 2822521'), findsOneWidget);
      expect(find.byKey(const ValueKey('loose-caption-1')), findsOneWidget);
    });

    testWidgets('allows a 1 kg packaging next to the loose leaf', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await pickAcem(tester);
      await type(tester, const ValueKey('size-1'), '1000');
      await tapOn(tester, find.text('Adicionar outra embalagem'));
      await goLoose(tester, 2);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.savedLoose, isTrue);
      expect(spy.savedPackagings, hasLength(1));
    });

    testWidgets('asks for a card when every card was removed', (tester) async {
      await pumpScreen(tester);
      await pickAcem(tester);
      await goLoose(tester, 1);
      await tapOn(tester, find.text('Remover').first);

      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('removing the loose card drops its scale codes', (tester) async {
      await pumpScreen(tester);
      await pickAcem(tester);
      await goLoose(tester, 1);
      await addScale(tester, tamara);
      await tapOn(tester, find.text('Remover').first);

      expect(find.text('• Carrefour · 2822521'), findsNothing);
    });

    testWidgets('writes the scale code on the saved loose leaf, not the first leaf', (tester) async {
      final spy = _LooseNextToPackagings();
      await pumpScreen(
        tester,
        repository: spy,
        request: const NewProductRequest(registrationId: 'reg-2'),
      );
      await addScale(tester, tamara);

      expect(spy.addedCodes.map((e) => e.$1), everyElement('prod-5'));
    });

    testWidgets('edits by adding only the loose leaf', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(
        tester,
        repository: spy,
        request: const NewProductRequest(registrationId: 'reg-1'),
      );
      await tapOn(tester, find.text('Adicionar embalagem'));
      await goLoose(tester, 1);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(spy.addedLoose, isTrue);
    });

    testWidgets('reading a scale label on top creates the loose card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');

      await tapOn(tester, find.byKey(const ValueKey('top-scan')));
      camera.read('02822521001605261107');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scale-store-store-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('loose-caption-2')), findsOneWidget);
    });

    Future<PickedProduct?> Function() openPushed(WidgetTester tester, ProviderContainer container) {
      final router = container.read(appRouterProvider);
      PickedProduct? result;
      unawaited(
        router
            .push<PickedProduct>(Routes.newProduct, extra: const NewProductRequest(returnsSelection: true))
            .then((value) => result = value),
      );
      return () async => result;
    }

    testWidgets('returns the loose leaf to the purchase when it is the last card', (tester) async {
      final container = await pumpScreen(tester);
      final result = openPushed(tester, container);
      await tester.pumpAndSettle();
      await pickAcem(tester);
      await goLoose(tester, 1);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect((await result())?.product.isLoose, isTrue);
    });

    testWidgets('returns the packaging leaf when it is the last card', (tester) async {
      final container = await pumpScreen(tester);
      final result = openPushed(tester, container);
      await tester.pumpAndSettle();
      await pickRefrigerante(tester);
      await type(tester, const ValueKey('size-1'), '350');

      await tapOn(tester, find.byKey(const ValueKey('save')));

      final picked = await result();
      expect(picked?.product.isLoose, isFalse);
      expect(picked?.product.packaging, isNotNull);
    });

    testWidgets('keeps the loose card when saving fails', (tester) async {
      await pumpScreen(tester, repository: _RefusingRepository());
      await pickAcem(tester);
      await goLoose(tester, 1);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.byKey(const ValueKey('loose-caption-1')), findsOneWidget);
    });

    testWidgets('double tap on save with a loose card saves once', (tester) async {
      final spy = _LooseSpy();
      await pumpScreen(tester, repository: spy);
      await pickAcem(tester);
      await goLoose(tester, 1);

      final save = find.byKey(const ValueKey('save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(spy.saveCalls, 1);
    });

    testWidgets('a taken scale code on the loose card is refused on save', (tester) async {
      await pumpScreen(tester, repository: _ScaleTakenOnSave());
      await pickAcem(tester);
      await goLoose(tester, 1);
      await addScale(tester, tamara);

      await tapOn(tester, find.byKey(const ValueKey('save')));

      expect(find.byKey(const ValueKey('loose-caption-1')), findsOneWidget);
      expect(find.text('Produto salvo.'), findsNothing);
    });
  });
}

/// Records the scale codes that reach the save.
class _ScaleSpy extends CatalogRepositoryLocal {
  _ScaleSpy() : super(latency: Duration.zero);

  IList<ScaleCode> savedScaleCodes = const IList.empty();
  int saveCalls = 0;

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) {
    saveCalls++;
    savedScaleCodes = scaleCodes;
    return super.saveRegistrationWithProducts(
      registration: registration,
      packagings: packagings,
      loose: loose,
      scaleCodes: scaleCodes,
    );
  }
}

/// The database refuses the scale code on save: it belongs to another product.
class _ScaleTakenOnSave extends CatalogRepositoryLocal {
  _ScaleTakenOnSave() : super(latency: Duration.zero);

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) {
    if (scaleCodes.isNotEmpty) {
      throw ApiException(
        409,
        'duplicate key value violates unique constraint '
        '"product_barcode_code_key"',
      );
    }
    return super.saveRegistrationWithProducts(
      registration: registration,
      packagings: packagings,
      loose: loose,
      scaleCodes: scaleCodes,
    );
  }
}

/// `prod-5` (Acém moído, loose) comes back with a scale code already on it.
class _WithScaleCodes extends CatalogRepositoryLocal {
  _WithScaleCodes() : super(latency: Duration.zero);

  final added = <ScaleCode>[];
  final removed = <ScaleCode>[];
  Object? failAdd;

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async => (await super.fetchProductsOf(registrationId))
      .map(
        (leaf) => leaf.id == 'prod-5'
            ? leaf.copyWith(
                scaleCodes: [const ScaleCode(storeId: 'store-1', itemCode: '2822521')].lock,
              )
            : leaf,
      )
      .toIList();

  @override
  Future<void> addScaleCode({required String productId, required ScaleCode code}) {
    final failure = failAdd;
    if (failure != null) {
      failAdd = null;
      throw failure;
    }
    added.add(code);
    return super.addScaleCode(productId: productId, code: code);
  }

  @override
  Future<void> removeScaleCode({required String productId, required ScaleCode code}) {
    removed.add(code);
    return super.removeScaleCode(productId: productId, code: code);
  }
}

/// Records what the editing path writes, and can stand a registration in
/// the way of "zero" or refuse the packagings. Recording instead of reading
/// the fake back: an `await` on the fake's `Future.delayed` outside a pump
/// deadlocks a widget test.
class _RecordingRepository extends CatalogRepositoryLocal {
  _RecordingRepository({this.holdsZero = false, this.refusesPackagings = false}) : super(latency: Duration.zero);

  final bool holdsZero;
  final bool refusesPackagings;

  ProductRegistration? updated;
  IList<PackagingWithBarcodes>? added;

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    if (holdsZero && description.trim() == 'zero') {
      return ProductRegistration(
        id: 'reg-9',
        productTypeId: productTypeId,
        brandId: brandId,
        description: 'zero',
        sellingMode: SellingMode.byPiece,
      );
    }
    return super.findRegistration(productTypeId: productTypeId, brandId: brandId, description: description);
  }

  @override
  Future<ProductRegistration> updateRegistration(ProductRegistration registration) async {
    updated = registration;
    return super.updateRegistration(registration);
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) async {
    if (refusesPackagings) throw NetworkException('offline');
    added = packagings;
    return super.addPackagings(registrationId: registrationId, packagings: packagings);
  }
}

/// Never finishes the write, so the reentrancy guard stays down for as long as
/// the test needs it — the deterministic way to reach it now that `save` no
/// longer shares its flag with the three catalog creates.
class _StuckRepository extends CatalogRepositoryLocal {
  _StuckRepository() : super(latency: Duration.zero);

  final _held = Completer<SavedRegistration>();

  void release() => _held.complete(
    SavedRegistration(
      registration: ProductRegistration(id: 'reg-100', productTypeId: 'type-1', sellingMode: SellingMode.byPiece),
      products: const IList.empty(),
    ),
  );

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
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
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) async => throw NetworkException('offline');
}

/// The fake with one row already DEACTIVATED, done by overriding the read.
///
/// Not by awaiting `updateCategory` before the first pump: inside
/// `testWidgets` the clock is fake, so the fakes' `Future.delayed` only fires
/// when a frame is pumped WITH a duration — and an `await` before
/// `pumpWidget` deadlocks the test for ten minutes instead of failing.
class _WithDeactivated extends CatalogRepositoryLocal {
  _WithDeactivated({this.categoryId, this.typeId, this.registrationId}) : super(latency: Duration.zero);

  final String? categoryId;
  final String? typeId;
  final String? registrationId;

  @override
  Future<IList<Category>> fetchCategories() async =>
      (await super.fetchCategories()).map((entry) => entry.id == categoryId ? entry.deactivated() : entry).toIList();

  @override
  Future<IList<ProductType>> fetchTypes() async =>
      (await super.fetchTypes()).map((entry) => entry.id == typeId ? entry.deactivated() : entry).toIList();

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

/// The owners of a code come through the read, never through a write awaited
/// before the first pump: inside `testWidgets` the clock is fake, so that
/// `await` would deadlock the test instead of failing it.
class _WithOwners extends CatalogRepositoryLocal {
  _WithOwners({this.owners = const {}, this.failFind = false}) : super(latency: Duration.zero);

  final Map<Barcode, BarcodeOwner> owners;
  final bool failFind;
  int findOwnersCalls = 0;
  final removedFrom = <String>[];
  IList<PackagingWithBarcodes>? saved;

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    findOwnersCalls++;
    if (failFind) throw NetworkException('offline');
    return {for (final code in codes) code: ?owners[code]}.lock;
  }

  @override
  Future<void> removeBarcode({required String productId, required Barcode code}) {
    removedFrom.add(productId);
    return super.removeBarcode(productId: productId, code: code);
  }

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) {
    saved = packagings;
    return super.saveRegistrationWithProducts(
      registration: registration,
      packagings: packagings,
      loose: loose,
      scaleCodes: scaleCodes,
    );
  }
}

/// The leaf `prod-1` comes back with a code already on it.
class _WithSavedCodes extends CatalogRepositoryLocal {
  _WithSavedCodes(this.code) : super(latency: Duration.zero);

  final String code;

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async => (await super.fetchProductsOf(
    registrationId,
  )).map((leaf) => leaf.id == 'prod-1' ? leaf.copyWith(barcodes: [Barcode.typed(code)].lock) : leaf).toIList();
}

/// The first read of the stores fails; the next one works.
class _FlakyStores extends StoreRepositoryLocal {
  _FlakyStores() : super(latency: Duration.zero);

  bool _failed = false;

  @override
  Future<IList<Store>> fetchAll() {
    if (!_failed) {
      _failed = true;
      throw NetworkException('offline');
    }
    return super.fetchAll();
  }
}

/// Every store is deactivated.
class _NoActiveStores extends StoreRepositoryLocal {
  _NoActiveStores() : super(latency: Duration.zero);

  @override
  Future<IList<Store>> fetchAll() async => (await super.fetchAll()).where((store) => !store.active).toIList();
}

/// Carrefour can be deactivated in the middle of a test.
class _SwitchableStores extends StoreRepositoryLocal {
  _SwitchableStores() : super(latency: Duration.zero);

  bool carrefourOff = false;

  @override
  Future<IList<Store>> fetchAll() async => (await super.fetchAll())
      .map((store) => carrefourOff && store.id == 'store-1' ? store.copyWith(active: false) : store)
      .toIList();
}

/// Holds `findRegistration` until [gate] completes, so a check can land
/// after the registration was opened.
class _GatedIdentity extends CatalogRepositoryLocal {
  _GatedIdentity() : super(latency: Duration.zero);

  Completer<void>? gate;

  @override
  Future<ProductRegistration?> findRegistration({
    required String productTypeId,
    String? brandId,
    required String description,
  }) async {
    await gate?.future;
    return super.findRegistration(productTypeId: productTypeId, brandId: brandId, description: description);
  }
}

/// Records what the screen sends to `saveRegistrationWithProducts` and
/// `addPackagings`, the loose flag included.
class _LooseSpy extends CatalogRepositoryLocal {
  _LooseSpy() : super(latency: Duration.zero);

  int saveCalls = 0;
  bool? savedLoose;
  IList<PackagingWithBarcodes>? savedPackagings;
  bool? addedLoose;
  IList<PackagingWithBarcodes>? addedPackagings;

  @override
  Future<SavedRegistration> saveRegistrationWithProducts({
    required ProductRegistration registration,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) {
    saveCalls++;
    savedLoose = loose;
    savedPackagings = packagings;
    return super.saveRegistrationWithProducts(
      registration: registration,
      packagings: packagings,
      loose: loose,
      scaleCodes: scaleCodes,
    );
  }

  @override
  Future<IList<Product>> addPackagings({
    required String registrationId,
    required IList<PackagingWithBarcodes> packagings,
    bool loose = false,
    IList<ScaleCode> scaleCodes = const IList.empty(),
  }) {
    addedLoose = loose;
    addedPackagings = packagings;
    return super.addPackagings(
      registrationId: registrationId,
      packagings: packagings,
      loose: loose,
      scaleCodes: scaleCodes,
    );
  }
}

/// `reg-2` comes back with a packaging leaf BEFORE the loose `prod-5`, so a
/// scale code written on "the first leaf" lands on the wrong product.
class _LooseNextToPackagings extends _LooseSpy {
  final addedCodes = <(String, ScaleCode)>[];

  @override
  Future<IList<Product>> fetchProductsOf(String registrationId) async {
    final leaves = await super.fetchProductsOf(registrationId);
    if (registrationId != 'reg-2') return leaves;
    return leaves
        .insert(
          0,
          Product(
            id: 'prod-50',
            productRegistrationId: 'reg-2',
            packaging: Packaging(pieceCount: 1, pieceSize: 1000, baseUnit: BaseUnit.gram),
          ),
        )
        .toIList();
  }

  @override
  Future<void> addScaleCode({required String productId, required ScaleCode code}) {
    addedCodes.add((productId, code));
    return super.addScaleCode(productId: productId, code: code);
  }
}

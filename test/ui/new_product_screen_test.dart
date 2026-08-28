import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/shopping_list.dart';

void main() {
  /// Mounted through the real router: screen 4 asks `context.canPop()` to
  /// decide which exit R11 gives it, and that question has no answer without
  /// a GoRouter above it.
  Future<void> pumpScreen(
    WidgetTester tester, {
    CatalogRepository? repository,
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
    router.go(Routes.newProduct);
    await tester.pumpAndSettle();
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
    expect(find.text('Unidade: escolha o tipo do produto primeiro'),
        findsOneWidget);
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
    await tapOn(tester, find.text('A peso'));

    expect(find.text('Embalagens deste produto'), findsNothing);
    expect(find.text('Adicionar embalagem'), findsNothing);
    // Quantity is what the PURCHASE asks for, not the registration.
    expect(find.text('Salvar produto'), findsOneWidget);
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

  testWidgets('creates a type with its category and base unit', (
    tester,
  ) async {
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

    expect(
      tester.widget<Radio<int>>(find.byType(Radio<int>).last).value,
      2,
    );
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

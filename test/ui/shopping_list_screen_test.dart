import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/pending_changes.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/ui/shopping_list/widgets/shopping_list_tile.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';

/// The fake with a switch that makes the next call fail, and a hold that keeps
/// the load pending — the loading state has to be reachable too.
class _SpyRepository extends ShoppingListRepositoryLocal {
  _SpyRepository({super.initial}) : super(latency: Duration.zero);

  Object? failNextCall;

  @override
  Future<IList<ShoppingListItem>> fetchAll() async {
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchAll();
  }
}

ShoppingListItem _item({
  required String id,
  required String typeName,
  required String categoryName,
  String categoryId = 'cat-1',
  int? quantity,
  bool picked = false,
  bool notFound = false,
}) => ShoppingListItem(
  id: id,
  type: ProductType(
    id: 'type-$id',
    name: typeName,
    categoryId: categoryId,
    baseUnit: BaseUnit.milliliter,
  ),
  category: Category(id: categoryId, name: categoryName),
  quantity: quantity,
  enteredOn: DateTime(2026, 8, 28),
  picked: picked,
  notFound: notFound,
);

void main() {
  // Screen 3 is one tap away from here now, and it draws a date —
  // `main()` does not run in a test.
  setUpAll(initializePtBr);

  final seed = [
    _item(id: '1', typeName: 'Leite', categoryName: 'Bebidas', quantity: 6000),
    _item(
      id: '2',
      typeName: 'Sabão em pó',
      categoryId: 'cat-2',
      categoryName: 'Limpeza',
    ),
  ];

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    ShoppingListRepository? repository,
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    // A tall viewport: the list carries three buttons under it, and the
    // default 800×600 leaves them outside the render tree.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(repository: repository),
        ...overrides,
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
    // `settle` is false only for the loading state: a pumpAndSettle over a
    // pending future would wait for it, which is the state being tested.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  testWidgets('shows a spinner while the list has not arrived', (tester) async {
    await pumpScreen(
      tester,
      repository: ShoppingListRepositoryLocal(
        latency: const Duration(seconds: 5),
      ),
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the pending future land, or the test ends with a timer alive.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('says the list is empty, and offers the two ways out', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _SpyRepository(initial: const <ShoppingListItem>[]),
    );

    expect(find.text('Sua lista está vazia.'), findsOneWidget);
    expect(find.text('Adicionar item'), findsOneWidget);
    expect(find.text('Sugerir itens'), findsOneWidget);
  });

  testWidgets('translates a failed load and offers to try again', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _SpyRepository(initial: seed)
        ..failNextCall = NetworkException('offline'),
    );

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
    // The raw exception NEVER reaches the screen.
    expect(find.textContaining('NetworkException'), findsNothing);
    expect(find.textContaining('offline'), findsNothing);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Leite'), findsOneWidget);
  });

  testWidgets('draws the items grouped by category', (tester) async {
    await pumpScreen(tester, repository: _SpyRepository(initial: seed));

    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Limpeza'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Sabão em pó'), findsOneWidget);
    // The quantity of the one that has one, and nothing for the one that does
    // not.
    expect(find.text('6 L'), findsOneWidget);
  });

  testWidgets(
    'strikes through what has been picked and marks what was not found',
    (tester) async {
      await pumpScreen(
        tester,
        repository: _SpyRepository(
          initial: [
            _item(
              id: '1',
              typeName: 'Leite',
              categoryName: 'Bebidas',
              picked: true,
            ),
            _item(
              id: '2',
              typeName: 'Acém',
              categoryName: 'Bebidas',
              notFound: true,
            ),
          ],
        ),
      );

      final picked = tester.widget<Text>(find.text('Leite'));
      expect(picked.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('(não encontrei)'), findsOneWidget);
    },
  );

  group('the banner', () {
    testWidgets('is not there while nothing arrived', (tester) async {
      await pumpScreen(tester, repository: _SpyRepository(initial: seed));

      expect(find.textContaining('atualizar'), findsNothing);
      expect(find.textContaining('A lista mudou'), findsNothing);
    });

    testWidgets('warns, and THE LIST DOES NOT MOVE until it is tapped', (
      tester,
    ) async {
      // The requirement the story is named after: counting the lines before
      // and after the event and demanding the same number.
      final repository = _SpyRepository(initial: seed);
      await pumpScreen(tester, repository: repository);

      final before = tester.widgetList(find.byType(ShoppingListTile)).length;

      // NOT awaited before the clock moves. The fake's latency is a real
      // Timer, and inside testWidgets the clock only advances when a frame is
      // pumped WITH a duration — a bare `pump()` elapses nothing and the
      // timer never fires. Awaiting first deadlocks the test for ten minutes
      // instead of failing it.
      final added = repository.add(
        _item(id: '9', typeName: 'Arroz', categoryName: 'Bebidas'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await added;

      repository.emitRemoteChange(ListChangeKind.added);
      await tester.pumpAndSettle();

      expect(find.text('1 item novo — atualizar'), findsOneWidget);
      expect(
        tester.widgetList(find.byType(ShoppingListTile)).length,
        before,
        reason: 'the list must not move under a finger',
      );

      // And the tap is what redraws it — and takes the banner away.
      await tester.tap(find.text('1 item novo — atualizar'));
      await tester.pumpAndSettle();

      expect(find.text('Arroz'), findsOneWidget);
      expect(find.textContaining('atualizar'), findsNothing);
    });

    testWidgets('a change that is not an addition reads as a change', (
      tester,
    ) async {
      final repository = _SpyRepository(initial: seed);
      await pumpScreen(tester, repository: repository);

      repository.emitRemoteChange(ListChangeKind.changed);
      await tester.pumpAndSettle();

      expect(find.text('A lista mudou — tocar para ver'), findsOneWidget);
    });
  });

  testWidgets('the checkbox marks, and does not take the item off the list', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _SpyRepository(initial: seed));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingListTile), findsNWidgets(2));
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
  });

  testWidgets('[ Sugerir itens ] is a real button now, and it pushes', (
    tester,
  ) async {
    // It used to answer 'A sugestão de itens chega na H17.' — H17 is this
    // delivery, and `_PendingButton` died with the map it read.
    //
    // The navigation itself is `router_test`'s: a screen test must not have to
    // build the next screen whole. What this one holds is that the footer has
    // an enabled button where the greyed-out one used to be.
    await pumpScreen(tester, repository: _SpyRepository(initial: seed));

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('suggest-items')),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Sugerir itens'), findsOneWidget);
    expect(find.textContaining('chega na H'), findsNothing);
  });

  testWidgets('the empty state offers the same button, also enabled', (
    tester,
  ) async {
    // Two `_PendingButton`s died, not one: the empty state has its own, and
    // leaving it behind would be a greyed-out button on the very screen
    // someone with an empty list is looking at.
    await pumpScreen(
      tester,
      repository: _SpyRepository(initial: const <ShoppingListItem>[]),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('suggest-items-empty')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('[ Lançar compra ] navigates, and the screen 1 opens at all', (
    tester,
  ) async {
    // Two assertions in one, and the second is the reason the button stopped
    // being a `_PendingButton` in the same step the map lost `newPurchase`:
    // `_PendingButton` reads that map with a `!`, so a screen 1 that builds
    // its footer at all is the proof the order was not inverted.
    await pumpScreen(
      tester,
      repository: _SpyRepository(initial: seed),
      overrides: purchaseOverrides(),
    );

    await tester.tap(find.byKey(const ValueKey('new-purchase')));
    await tester.pumpAndSettle();

    expect(find.text('Lançar compra'), findsWidgets);
    expect(find.byKey(const ValueKey('field-product')), findsOneWidget);
  });

  testWidgets('the ≡ opens the four doors, none of them explained', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _SpyRepository(initial: seed));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    // `widgetWithText(ListTile, …)` and not a plain `find.text`: with the
    // sheet open over screen 1, "Lançar compra" is written TWICE — the
    // footer's OutlinedButton and this menu's ListTile (decision I-b). A
    // `findsWidgets` here would be satisfied by the footer alone and would
    // stop proving the door exists.
    expect(find.widgetWithText(ListTile, 'Lançar compra'), findsOneWidget);
    // And the footer button did NOT leave: screen 1 keeps BOTH doors, which
    // is decision I-b. Without this line, deleting the footer button one day
    // would leave this test green.
    expect(
      find.widgetWithText(OutlinedButton, 'Lançar compra'),
      findsOneWidget,
    );
    expect(find.text('Histórico de compras'), findsOneWidget);
    expect(find.text('Manutenção do cadastro'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    // "Corrigir compra" left the menu instead of being enabled:
    // `/purchases/:id/edit` does not navigate without an id, and the only
    // screen that knows which is the history, one line above.
    expect(find.text('Corrigir compra'), findsNothing);
    expect(find.textContaining('chega na H'), findsNothing);
  });

  testWidgets('the 👤 asks who is using, with the H1 picker', (tester) async {
    await pumpScreen(tester, repository: _SpyRepository(initial: seed));

    await tester.tap(find.byTooltip('Quem está usando'));
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando?'), findsOneWidget);
    expect(find.byKey(const Key('device-user-Esposa')), findsOneWidget);

    // And picking one saves it and closes the dialog. Since H11 the picker is
    // `showWhoIsUsingDialog`, in a file of its own — screens 1 and 5 both open
    // it, and the write is the half a `findsOneWidget` never reaches.
    await tester.tap(find.byKey(const Key('device-user-Esposa')));
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando?'), findsNothing);
  });
}

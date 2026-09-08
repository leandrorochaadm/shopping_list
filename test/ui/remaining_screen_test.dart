import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/type_consumption.dart';
import 'package:shopping_list/ui/consumption/view_model/monthly_average_view_model.dart';
import 'package:shopping_list/ui/consumption/widgets/remaining_screen.dart';
import 'package:shopping_list/ui/core/online_status.dart';
import 'package:shopping_list/ui/shopping_list/widgets/item_dialog.dart';

import '../helpers/catalog.dart';
import '../helpers/consumption.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/shopping_list.dart';

/// The consumption fake with a switch that makes the next query fail.
class _SpyConsumption extends ConsumptionRepositoryLocal {
  _SpyConsumption({super.lines}) : super(latency: Duration.zero);

  Object? failNextCall;

  @override
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  }) async {
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchTypeConsumption(window: window, month: month);
  }
}

/// The list fake that records what was written — a repository method cannot be
/// awaited from inside `testWidgets` (the frozen clock), so the record is the
/// assertion.
class _SpyList extends ShoppingListRepositoryLocal {
  _SpyList({super.initial}) : super(latency: Duration.zero);

  final List<ShoppingListItem> added = [];
  final List<ShoppingListItem> written = [];

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    added.add(item);
    return super.add(item);
  }

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    written.add(item);
    return super.update(item);
  }
}

/// There is no navigator in the Dart VM, and the stub is deliberately mute —
/// which is why `OnlineStatus` is not `final`: the offline path is reachable
/// only by extending it.
final class _Offline extends OnlineStatus {
  @override
  bool build() => false;
}

final _drinks = Category(id: 'cat-1', name: 'Bebidas');

final _beef = ProductType(
  id: 'type-2',
  name: 'Acém moído',
  categoryId: 'cat-2',
  baseUnit: BaseUnit.gram,
);

ShoppingListItem _listItem({
  required ProductType type,
  int? quantity,
  int writtenOffQuantity = 0,
  bool notFound = false,
  DateTime? enteredOn,
  String id = 'item-1',
}) => ShoppingListItem(
  id: id,
  type: type,
  category: _drinks,
  quantity: quantity,
  writtenOffQuantity: writtenOffQuantity,
  notFound: notFound,
  enteredOn: enteredOn ?? DateTime(2026, 8, 20),
);

void main() {
  // `main()` does not run in a test, and this screen draws a month name.
  setUpAll(initializePtBr);

  Future<void> pumpScreen(
    WidgetTester tester, {
    ConsumptionRepository? consumption,
    _SpyList? list,
    List<Override> overrides = const [],
  }) async {
    // A tall viewport: the two bands plus the button do not fit the default
    // 800×600, and a tile outside the render tree cannot be tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          deviceUserOverride(),
          // The dialog this screen opens loads the leaves of the type through
          // the CatalogViewModel; without this it opens with empty dropdowns
          // and the case fails for a reason that is not its own.
          catalogOverride(),
          consumptionOverride(repository: consumption ?? _SpyConsumption()),
          shoppingListOverride(repository: list ?? _SpyList(initial: const [])),
          // The clock is pinned: the month is August 2026. Without it the case
          // that reads "Agosto/2026" passes in August and fails in September,
          // on a CI nobody touched.
          monthlyAverageViewModelProvider.overrideWith(
            () => MonthlyAverageViewModel(today: testToday),
          ),
          ...overrides,
        ],
        child: const MaterialApp(home: RemainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the month is at the top, because every number is its', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Falta comprar este mês'),
      ),
      findsOneWidget,
    );
    expect(find.text('Agosto/2026'), findsOneWidget);
  });

  testWidgets('the top band holds only what is missing, and says how much', (
    tester,
  ) async {
    await pumpScreen(tester);

    // The written story of requirement 18: average of 8 kg, 6 kg bought in
    // August, faltam 2 kg.
    expect(find.text('Acém moído'), findsOneWidget);
    expect(find.text('faltam 2 kg'), findsOneWidget);
    expect(find.text('Sabão em pó'), findsOneWidget);
    expect(find.text('faltam 1,2 kg'), findsOneWidget);
    // Bought once in the window and never this month — not hidden for being a
    // rare purchase.
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('faltam 700 g'), findsOneWidget);

    // Whoever has no balance is out of the band, behind the button.
    expect(find.text('Refrigerante'), findsNothing);
    expect(find.text('Papel higiênico'), findsNothing);
    expect(find.text('Ver todos (2 sem faltar)'), findsOneWidget);
  });

  testWidgets('"Ver todos" reveals the second band, with the consumed over '
      'the average', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('toggle-show-all')));
    await tester.pumpAndSettle();

    expect(find.text('NADA FALTANDO ESTE MÊS'), findsOneWidget);
    // Bought all three months: 12,6 L ÷ 3 is exactly what August bought.
    expect(find.text('4,2 de 4,2 L'), findsOneWidget);
    // First bought THIS month: its average IS its own purchase, so nothing is
    // ever missing of it — and it needed no flag to say so.
    expect(find.text('12 de 12 un'), findsOneWidget);
    // The top band is still there — it reveals, it does not replace.
    expect(find.text('faltam 2 kg'), findsOneWidget);
    expect(find.text('Mostrar só o que falta'), findsOneWidget);
  });

  testWidgets('the count on the button matches what the band shows', (
    tester,
  ) async {
    // Version 2.0 of the wireframes had to fix exactly this: a count that did
    // not match the band.
    await pumpScreen(tester);
    expect(find.text('Ver todos (2 sem faltar)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-show-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remaining-type-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('remaining-type-3')), findsOneWidget);
  });

  testWidgets('what the list is asking for goes under the number', (
    tester,
  ) async {
    // The two numbers may differ on purpose, and the sub-line is what keeps
    // them from being read as the same one.
    await pumpScreen(
      tester,
      list: _SpyList(
        initial: [
          _listItem(type: _beef, quantity: 6000, writtenOffQuantity: 4000),
        ],
      ),
    );

    expect(find.text('faltam 2 kg'), findsOneWidget);
    expect(find.text('na lista: restam 2 de 6 kg'), findsOneWidget);
  });

  testWidgets('a type NOT on the list has no sub-line', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('na lista'), findsNothing);
  });

  group('the tap opens the dialog of screen 1, already filled in', () {
    testWidgets('on a type NOT on the list it opens in the creating mode', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('remaining-type-2')));
      await tester.pumpAndSettle();

      expect(find.byType(ItemDialog), findsOneWidget);
      // Prefilled with what is missing, in the unit the field is typed in.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('field-quantity')),
      );
      expect(field.controller!.text, '2000');
      // Nothing to mark as not found on a type nobody has asked for.
      expect(find.text('Não encontrei'), findsNothing);
      expect(find.text('Remover da lista'), findsNothing);
    });

    testWidgets('on a type already on the list it EDITS the existing line', (
      tester,
    ) async {
      final list = _SpyList(
        initial: [_listItem(type: _beef, quantity: 6000, id: 'item-9')],
      );
      await pumpScreen(tester, list: list);

      await tester.tap(find.byKey(const ValueKey('remaining-type-2')));
      await tester.pumpAndSettle();

      expect(find.text('Não encontrei'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // It edited; it did not create a second line for the same type.
      expect(list.written, hasLength(1));
      expect(list.written.single.id, 'item-9');
      expect(list.added, isEmpty);
    });

    testWidgets('with two open items of the type it opens the OLDEST (E-i)', (
      tester,
    ) async {
      // The `#1a` panel blocks the duplicate, but the other phone and the
      // history can produce it — and without a tiebreak which item the dialog
      // opens would change on every fetch.
      final list = _SpyList(
        initial: [
          _listItem(
            type: _beef,
            quantity: 6000,
            id: 'item-new',
            enteredOn: DateTime(2026, 8, 28),
          ),
          _listItem(
            type: _beef,
            quantity: 3000,
            id: 'item-old',
            enteredOn: DateTime(2026, 8, 10),
          ),
        ],
      );
      await pumpScreen(tester, list: list);

      await tester.tap(find.byKey(const ValueKey('remaining-type-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(list.written.single.id, 'item-old');
    });

    testWidgets('from the BOTTOM band the field opens empty', (tester) async {
      // Nothing is missing there, and a prefilled `0` would make saving throw
      // InvalidQuantity. He is adding anyway — the soft drink can run out on
      // the 20th even having passed the average.
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('toggle-show-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remaining-type-1')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('field-quantity')),
      );
      expect(field.controller!.text, '');
    });

    testWidgets('the item on the list with no quantity is warned', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        list: _SpyList(initial: [_listItem(type: _beef)]),
      );

      expect(find.text('na lista, sem quantidade'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('remaining-type-2')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'este item está na lista sem quantidade — confirmar passa a '
          'pedir 2 kg',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('the screen touches the list on its own: never', (tester) async {
    // "A tela informa; não mexe na lista": no mark, no write-off, nothing out
    // of anywhere — until a line is tapped and the dialog is confirmed.
    final list = _SpyList(initial: [_listItem(type: _beef, quantity: 6000)]);
    await pumpScreen(tester, list: list);

    expect(list.written, isEmpty);
    expect(list.added, isEmpty);
  });

  testWidgets('nothing missing is not an empty screen', (tester) async {
    // They bought everything they usually buy — and the `[ Ver todos ]` stays
    // standing, for whoever wants to add anyway.
    await pumpScreen(
      tester,
      consumption: _SpyConsumption(
        lines: [
          ConsumptionLine(
            day: DateTime(2026, 8, 10),
            typeId: 'type-1',
            quantityInBaseUnit: 4200,
          ),
        ],
      ),
    );

    expect(
      find.text('Vocês já compraram tudo que costumam comprar em agosto.'),
      findsOneWidget,
    );
    expect(find.text('Ver todos (1 sem faltar)'), findsOneWidget);
  });

  testWidgets('with no history it says so, and offers no action', (
    tester,
  ) async {
    // The state of the first weeks.
    await pumpScreen(tester, consumption: _SpyConsumption(lines: const []));

    expect(
      find.text('Ainda não há compras suficientes para calcular a média.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('toggle-show-all')), findsNothing);
  });

  testWidgets('a failing load occupies the screen, with a way back', (
    tester,
  ) async {
    final consumption = _SpyConsumption()
      ..failNextCall = ApiException(500, 'boom');
    await pumpScreen(tester, consumption: consumption);

    expect(find.byKey(const ValueKey('retry-remaining')), findsOneWidget);
    // The raw exception NEVER reaches the screen — it goes to debugPrint.
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('retry-remaining')));
    await tester.pumpAndSettle();

    expect(find.text('faltam 2 kg'), findsOneWidget);
  });

  testWidgets('offline the screen does not open at all', (tester) async {
    // **The only screen of the app that does not open offline**, and it is the
    // wireframe that says so: every number here comes from outside the phone.
    await pumpScreen(
      tester,
      overrides: [onlineStatusProvider.overrideWith(_Offline.new)],
    );

    expect(
      find.text('Sem conexão — não é possível abrir agora.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('retry-remaining-offline')),
      findsOneWidget,
    );
    // Not a single number is drawn.
    expect(find.text('faltam 2 kg'), findsNothing);
    expect(find.byKey(const ValueKey('toggle-show-all')), findsNothing);
  });

  testWidgets('it is a permanent destination: no Back button', (tester) async {
    // "Alternar entre eles não é voltar" — the same rule screen 1 and screen 5
    // already carry.
    await pumpScreen(tester);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('the ≡ opens the four doors here too', (tester) async {
    // The third screen that mounts this menu, and the one where the new door
    // pays the most: this is where you find out what is missing, which is
    // when you want to register the purchase (decision I-a). No collision
    // here — screen 6 does not write "Lançar compra" anywhere of its own.
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.text('Histórico de compras'), findsOneWidget);
    expect(find.text('Manutenção do cadastro'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:shopping_list/ui/consumption/widgets/suggestions_screen.dart';

import '../helpers/consumption.dart';
import '../helpers/device_user.dart';
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

  Object? failNextWrite;
  final List<ShoppingListItem> added = [];

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    added.add(item);
    return super.add(item);
  }
}

final _drinks = Category(id: 'cat-1', name: 'Bebidas');

ShoppingListItem _listItem({
  required String typeId,
  required String name,
  bool notFound = false,
  DateTime? fulfilledOn,
}) => ShoppingListItem(
  id: 'item-$typeId',
  type: ProductType(
    id: typeId,
    name: name,
    categoryId: 'cat-1',
    baseUnit: BaseUnit.liter,
  ),
  category: _drinks,
  enteredOn: DateTime(2026, 8, 20),
  notFound: notFound,
  fulfilledOn: fulfilledOn,
);

void main() {
  /// A router of its own with the two routes this screen needs, and not the
  /// app's: `context.canPop()` needs a GoRouter in the tree, and a minimal one
  /// is what lets both sides of it be exercised — pushed from screen 1, and
  /// reached by a pasted link.
  Future<void> pumpScreen(
    WidgetTester tester, {
    ConsumptionRepository? consumption,
    _SpyList? list,
    bool pushed = true,
  }) async {
    // A tall viewport: five suggestion lines plus the button do not fit the
    // default 800×600, and a button outside the render tree cannot be tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/suggestions'),
                child: const Text('ir para a sugestão'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/suggestions',
          builder: (context, state) => const SuggestionsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          deviceUserOverride(),
          consumptionOverride(repository: consumption ?? _SpyConsumption()),
          shoppingListOverride(repository: list ?? _SpyList(initial: const [])),
          // The clock is pinned: the closed window is 01/05 → 31/07/2026 and
          // the month is August. Without it these cases pass in August and
          // fail in September, on a CI nobody touched.
          monthlyAverageViewModelProvider.overrideWith(
            () => MonthlyAverageViewModel(today: testToday),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    if (pushed) {
      await tester.tap(find.text('ir para a sugestão'));
    } else {
      // The pasted link: no stack behind it.
      router.go('/suggestions');
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the five types of the fake, grouped by category', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Sugestão de itens'), findsOneWidget);
    expect(
      find.text('Baseado no que compraram nos três meses fechados anteriores.'),
      findsOneWidget,
    );

    // The written story of requirement 8, and every number is a rule:
    // the beef divides by three, the powder by two, the coffee by three with a
    // single purchase in the window, and the toilet paper by nothing.
    expect(find.text('Acém moído — 8 kg'), findsOneWidget);
    expect(find.text('Sabão em pó — 8 kg'), findsOneWidget);
    expect(find.text('Café — 0,7 kg'), findsOneWidget);
    expect(find.text('Refrigerante — 4,2 L'), findsOneWidget);
    expect(find.text('Papel higiênico — 12 un'), findsOneWidget);

    // Grouped by category, alphabetically — the same organization screen 1
    // uses, never "do mais comprado para o menos comprado".
    final categories = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where(
          (text) => const {
            'Bebidas',
            'Carnes',
            'Limpeza',
            'Mercearia',
          }.contains(text),
        )
        .toList();
    expect(categories, ['Bebidas', 'Carnes', 'Limpeza', 'Mercearia']);
  });

  testWidgets('opens with EVERYTHING unticked', (tester) async {
    // The written criterion: ticking everything would tip the whole suggestion
    // into the list with one tap, which is the opposite of "quem decide o que
    // é rotina é ele".
    await pumpScreen(tester);

    final boxes = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(boxes, hasLength(5));
    expect(boxes.every((box) => box.value == false), isTrue);

    // And with nothing ticked the button does nothing — plainly disabled
    // rather than a tap that says nothing.
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('add-selected')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a type already on the list comes LOCKED', (tester) async {
    await pumpScreen(
      tester,
      list: _SpyList(
        initial: [_listItem(typeId: 'type-1', name: 'Refrigerante')],
      ),
    );

    final locked = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('suggestion-type-1')),
    );
    expect(locked.onChanged, isNull, reason: 'it does not answer the tap');
    expect(locked.value, isFalse);
    expect(find.text('(já está na lista)'), findsOneWidget);

    // The others stay tappable.
    final free = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('suggestion-type-5')),
    );
    expect(free.onChanged, isNotNull);
  });

  testWidgets('the one marked "não encontrei" is locked too, and says so', (
    tester,
  ) async {
    // It is still on the list — that is the written criterion.
    await pumpScreen(
      tester,
      list: _SpyList(
        initial: [
          _listItem(typeId: 'type-1', name: 'Refrigerante', notFound: true),
        ],
      ),
    );

    final locked = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('suggestion-type-1')),
    );
    expect(locked.onChanged, isNull);
    expect(find.text('(não encontrei)'), findsOneWidget);
    expect(find.text('(já está na lista)'), findsNothing);
  });

  testWidgets('an item already bought does NOT lock its type', (tester) async {
    // `isOpen` is the filter: a line a purchase closed left the list, and its
    // type has to be offerable again.
    await pumpScreen(
      tester,
      list: _SpyList(
        initial: [
          _listItem(
            typeId: 'type-1',
            name: 'Refrigerante',
            fulfilledOn: DateTime(2026, 8, 25),
          ),
        ],
      ),
    );

    final tile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('suggestion-type-1')),
    );
    expect(tile.onChanged, isNotNull);
    expect(find.text('(já está na lista)'), findsNothing);
  });

  testWidgets('ticking two and adding writes both, with the quantity, and '
      'goes back', (tester) async {
    final list = _SpyList(initial: const []);
    await pumpScreen(tester, list: list);

    await tester.tap(find.byKey(const ValueKey('suggestion-type-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-type-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-selected')));
    await tester.pumpAndSettle();

    expect(list.added, hasLength(2));
    final byName = {for (final item in list.added) item.type.name: item};
    // The suggestion fills the field — and from then on it is the item's, and
    // editable (requirement 13).
    expect(byName['Café']!.quantity, 700);
    expect(byName['Acém moído']!.quantity, 8000);
    // The line carries the whole category (D4).
    expect(byName['Café']!.category.name, 'Mercearia');

    // `pop`, not `go`: screen 1 pushed this one, and the wireframe sends it
    // back there.
    expect(find.byType(SuggestionsScreen), findsNothing);
    expect(find.text('ir para a sugestão'), findsOneWidget);
  });

  testWidgets('a failing add keeps the screen and says why', (tester) async {
    final list = _SpyList(initial: const [])
      ..failNextWrite = ApiException(500, 'boom');
    await pumpScreen(tester, list: list);

    await tester.tap(find.byKey(const ValueKey('suggestion-type-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-selected')));
    await tester.pumpAndSettle();

    expect(find.byType(SuggestionsScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    // The raw exception NEVER reaches the screen.
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('with no history it says so, and offers no action', (
    tester,
  ) async {
    // What the wireframe draws: "Ainda não há compras suficientes para sugerir
    // nada", with no button — there is nothing a tap could do about it.
    await pumpScreen(tester, consumption: _SpyConsumption(lines: const []));

    expect(
      find.text('Ainda não há compras suficientes para sugerir nada.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('add-selected')), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('a failing load occupies the screen, with a way back', (
    tester,
  ) async {
    final consumption = _SpyConsumption()
      ..failNextCall = ApiException(500, 'boom');
    await pumpScreen(tester, consumption: consumption);

    expect(find.byKey(const ValueKey('retry-suggestions')), findsOneWidget);
    // The raw exception NEVER reaches the screen — it goes to debugPrint.
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('retry-suggestions')));
    await tester.pumpAndSettle();

    // The retry worked, and the lines are there.
    expect(find.text('Café — 0,7 kg'), findsOneWidget);
  });

  testWidgets('pushed from screen 1 it carries a Back button', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('with no stack to pop the way out is the house', (tester) async {
    // R11: in a standalone PWA there is no browser Back button, and this
    // screen is reachable by a pasted link.
    await pumpScreen(tester, pushed: false);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/type_consumption.dart';
import 'package:shopping_list/ui/consumption/view_model/monthly_average_view_model.dart';
import 'package:shopping_list/ui/consumption/widgets/suggestions_screen.dart';

import '../helpers/barcode_camera.dart';
import '../helpers/barcode_owners.dart';
import '../helpers/catalog.dart';
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

/// The catalog fake that knows the codes the test gives it: the fake itself
/// starts with none.
class _ScanCatalog extends CatalogRepositoryLocal {
  _ScanCatalog() : super(latency: Duration.zero);

  final owners = <Barcode, BarcodeOwner>{};
  int findOwnersCalls = 0;
  Object? failFindOwners;

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async {
    findOwnersCalls++;
    await super.findOwners(codes);
    final failure = failFindOwners;
    if (failure != null) throw failure;
    return {for (final code in codes) code: ?owners[code]}.lock;
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
    baseUnit: BaseUnit.milliliter,
  ),
  category: _drinks,
  enteredOn: DateTime(2026, 8, 20),
  notFound: notFound,
  fulfilledOn: fulfilledOn,
);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    ConsumptionRepository? consumption,
    _SpyList? list,
    _ScanCatalog? catalog,
    FakeBarcodeCamera? camera,
  }) async {
    // A tall viewport: five suggestion lines plus the button do not fit the
    // default 800×600, and a button outside the render tree cannot be tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          deviceUserOverride(),
          consumptionOverride(repository: consumption ?? _SpyConsumption()),
          shoppingListOverride(repository: list ?? _SpyList(initial: const [])),
          catalogOverride(repository: catalog ?? _ScanCatalog()),
          (camera ?? FakeBarcodeCamera()).override,
          // The clock is pinned: the closed window is 01/05 → 31/07/2026 and
          // the month is August. Without it these cases pass in August and
          // fail in September, on a CI nobody touched.
          monthlyAverageViewModelProvider.overrideWith(
            () => MonthlyAverageViewModel(today: testToday),
          ),
        ],
        child: const MaterialApp(home: SuggestionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the reader and hands it [raw]. The fake clock only advances on a
  /// `pump` WITH a duration.
  Future<void> scan(
    WidgetTester tester,
    FakeBarcodeCamera camera,
    String raw,
  ) async {
    await tester.tap(find.byKey(const ValueKey('scan-pantry')));
    await tester.pumpAndSettle();
    camera.read(raw);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('the five types of the fake, grouped by category', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Conferir despensa'), findsOneWidget);
    expect(find.text('Marque o que acabou em casa.'), findsOneWidget);

    // The written story of requirement 8 — every type appears, with no
    // quantity: PantryCheck never shows or writes one.
    expect(find.text('Acém moído'), findsOneWidget);
    expect(find.text('Sabão em pó'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Refrigerante'), findsOneWidget);
    expect(find.text('Papel higiênico'), findsOneWidget);

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
    final button = tester.widget<FloatingActionButton>(
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

  testWidgets(
    'ticking two and adding writes both, with no quantity, and stays',
    (tester) async {
      final list = _SpyList(initial: const []);
      await pumpScreen(tester, list: list);

      await tester.tap(find.byKey(const ValueKey('suggestion-type-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('suggestion-type-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-selected')));
      // Advances the clock enough to drain both of the fake's own
      // `Future.delayed` writes (Duration.zero still needs a tick), then one
      // more frame for the SnackBar to appear.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('2 itens adicionados à lista.'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(list.added, hasLength(2));
      final byName = {for (final item in list.added) item.type.name: item};
      expect(byName['Café']!.quantity, isNull);
      expect(byName['Acém moído']!.quantity, isNull);
      // The line carries the whole category (D4).
      expect(byName['Café']!.category.name, 'Mercearia');

      // A permanent destination does not leave on its own: the two lines
      // come back locked, and the ticks went with the write — a tick left on
      // a locked line would be added again by the next tap.
      expect(find.byType(SuggestionsScreen), findsOneWidget);
      expect(find.text('(já está na lista)'), findsNWidgets(2));
      final button = tester.widget<FloatingActionButton>(
        find.byKey(const ValueKey('add-selected')),
      );
      expect(button.onPressed, isNull);
    },
  );

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

  testWidgets('the floating button never covers the last line', (tester) async {
    await pumpScreen(tester, list: _SpyList(initial: const []));
    // The width of the iPhone 12, and short enough that the five lines of the
    // fake overflow: with a list that fits, nothing would ever sit under the
    // button and the test would pass without the room at the end.
    tester.view.physicalSize = const Size(390, 480);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('pantry-lines')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    final lastLine = tester.getRect(find.byType(CheckboxListTile).last);
    final button = tester.getRect(find.byKey(const ValueKey('add-selected')));
    expect(lastLine.bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('with no history it says so, and offers no action', (
    tester,
  ) async {
    // What the wireframe draws: "Ainda não há compras suficientes para
    // conferir a despensa", with no button — there is nothing a tap could do
    // about it.
    await pumpScreen(tester, consumption: _SpyConsumption(lines: const []));

    expect(
      find.text('Ainda não há compras suficientes para conferir a despensa.'),
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
    expect(find.text('Café'), findsOneWidget);
  });

  testWidgets('it is a permanent destination: the ≡ and the bar, no Back', (
    tester,
  ) async {
    // "Alternar entre eles não é voltar" — screen 2 took screen 6's slot in
    // the bottom bar on 27/09/2026, and the rule came with the slot.
    await pumpScreen(tester);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-purchase')), findsOneWidget);
  });

  testWidgets('the ≡ opens the doors here too', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.text('Falta comprar este mês'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
  });

  group('the [▥] reads a code', () {
    testWidgets('a read code ticks its line and writes nothing', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final list = _SpyList(initial: const []);
      await pumpScreen(tester, list: list, catalog: catalog, camera: camera);

      await scan(tester, camera, colaCode);

      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('suggestion-type-1')),
      );
      expect(tile.value, isTrue);
      expect(list.added, isEmpty);
      expect(find.text('Adicionar 1 à lista'), findsOneWidget);
    });

    testWidgets('the ticked line scrolls into view', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(coffeeCode)] = coffeeOwner;
      await pumpScreen(tester, catalog: catalog, camera: camera);
      tester.view.physicalSize = const Size(390, 480);
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('suggestion-type-5'));
      expect(line.hitTestable(), findsNothing);

      await scan(tester, camera, coffeeCode);

      expect(line.hitTestable(), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(line).value, isTrue);
    });

    testWidgets('a type already on the list is not ticked and says so', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(colaCode)] = colaOwner;
      final list = _SpyList(
        initial: [_listItem(typeId: 'type-1', name: 'Refrigerante')],
      );
      await pumpScreen(tester, list: list, catalog: catalog, camera: camera);

      await scan(tester, camera, colaCode);

      expect(find.text('Já está na lista.'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('suggestion-type-1')),
      );
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
    });

    testWidgets('a type the pantry lacks offers to put it on the list', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(foilCode)] = foilOwner;
      final list = _SpyList(initial: const []);
      await pumpScreen(tester, list: list, catalog: catalog, camera: camera);

      await scan(tester, camera, foilCode);

      expect(
        find.text('Esse produto ainda não aparece na despensa.'),
        findsOneWidget,
      );
      final action = find.byKey(const ValueKey('scan-notice-action'));
      expect(
        find.descendant(of: action, matching: find.text('Pôr na lista')),
        findsOneWidget,
      );

      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('1 item adicionado à lista.'), findsOneWidget);
      await tester.pumpAndSettle();

      final added = list.added.single;
      expect(added.type.id, 'type-6');
      expect(added.preferredRegistration?.id, 'reg-3');
      expect(added.quantity, isNull);
      expect(added.category.name, 'Limpeza');
      expect(find.byKey(const ValueKey('scan-notice')), findsNothing);
    });

    testWidgets('putting the absent type on the list can fail and says why', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(foilCode)] = foilOwner;
      final list = _SpyList(initial: const [])
        ..failNextWrite = ApiException(500, 'boom');
      await pumpScreen(tester, list: list, catalog: catalog, camera: camera);

      await scan(tester, camera, foilCode);
      await tester.tap(find.byKey(const ValueKey('scan-notice-action')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.byKey(const ValueKey('scan-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-notice-action')), findsOneWidget);
    });

    testWidgets('an unknown code says so, with no way to register', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);

      await scan(tester, camera, foilCode);

      expect(find.text('Nenhum produto com esse código.'), findsOneWidget);
      expect(find.text('Cadastrar produto'), findsNothing);
    });

    testWidgets('a scale label is refused', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog();
      await pumpScreen(tester, catalog: catalog, camera: camera);

      await scan(tester, camera, '02822521001605261107');

      expect(
        find.text('Etiqueta de balança só serve no lançamento da compra.'),
        findsOneWidget,
      );
      expect(catalog.findOwnersCalls, 0);
    });

    testWidgets('a failing lookup shows the SnackBar', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()..failFindOwners = NetworkException('down');
      await pumpScreen(tester, catalog: catalog, camera: camera);

      await scan(tester, camera, colaCode);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('down'), findsNothing);
    });

    testWidgets('ticking a line clears the notice', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, camera: camera);
      await scan(tester, camera, foilCode);
      expect(find.byKey(const ValueKey('scan-notice')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('suggestion-type-5')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scan-notice')), findsNothing);
    });

    testWidgets('the scan button is off when the pantry failed to load', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        consumption: _SpyConsumption()
          ..failNextCall = ApiException(500, 'boom'),
      );

      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('scan-pantry')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('the scan button works on an empty pantry', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _ScanCatalog()
        ..owners[Barcode.typed(foilCode)] = foilOwner;
      await pumpScreen(
        tester,
        consumption: _SpyConsumption(lines: const []),
        catalog: catalog,
        camera: camera,
      );

      await scan(tester, camera, foilCode);

      expect(
        find.text('Esse produto ainda não aparece na despensa.'),
        findsOneWidget,
      );
      expect(find.text('Pôr na lista'), findsOneWidget);
    });
  });
}

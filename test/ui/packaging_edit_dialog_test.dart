import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_maintenance_view_model.dart';
import 'package:shopping_list/ui/catalog/widgets/catalog_entry_edit_dialog.dart';
import 'package:shopping_list/ui/catalog/widgets/packaging_edit_dialog.dart';

import '../helpers/catalog.dart';

/// The shared fake plus the two leaves this dialog needs and it has no room
/// for: one counted BY UNIT — the type measured in `un` has no leaf there —
/// and one already off, which is the only way to read the button as
/// 'Reativar'.
class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  static final counted = Product(
    id: 'prod-9',
    productRegistrationId: 'reg-3',
    packaging: Packaging(
      pieceCount: 4,
      pieceSize: 1,
      baseUnit: BaseUnit.unit,
    ),
  );

  static final inactive = Product(
    id: 'prod-8',
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: 600,
      baseUnit: BaseUnit.milliliter,
    ),
    active: false,
  );

  /// Every leaf the dialog asked to write, in order. An empty list is what
  /// says the domain refused BEFORE any I/O.
  final writes = <Product>[];

  Object? failNextWrite;

  /// Held open, the write never finishes: it is what keeps the dialog in its
  /// saving state long enough to be read.
  Completer<void>? gate;

  @override
  Future<IList<Product>> fetchProducts() async =>
      (await super.fetchProducts()).addAll([counted, inactive]);

  @override
  Future<Product> updateProduct(Product product) async {
    final failure = failNextWrite;
    failNextWrite = null;
    if (failure != null) throw failure;
    await gate?.future;
    writes.add(product);
    return super.updateProduct(product);
  }
}

void main() {
  late _SpyCatalog catalog;

  setUp(() => catalog = _SpyCatalog());

  /// The four leaves of the fake all hang from 'reg-1', which is what makes
  /// the collision guard reachable: 'prod-1' is 1 × 350 ml.
  Product leafOf(
    String id, {
    required int pieceCount,
    required int pieceSize,
    required BaseUnit unit,
  }) => Product(
    id: id,
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: pieceCount,
      pieceSize: pieceSize,
      baseUnit: unit,
    ),
  );

  /// 'prod-2', the 269 ml of the fake: the leaf every correction here starts
  /// from, since it is the one that can be typed onto another one.
  final leaf269 = leafOf(
    'prod-2',
    pieceCount: 1,
    pieceSize: 269,
    unit: BaseUnit.milliliter,
  );

  final countField = find.byKey(const ValueKey('field-piece-count'));
  final sizeField = find.byKey(const ValueKey('field-piece-size'));
  final saveButton = find.byKey(const ValueKey('save-packaging'));
  final toggleButton = find.byKey(const ValueKey('toggle-active'));

  String textOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  Future<void> pumpDialog(
    WidgetTester tester, {
    required Product leaf,
    required BaseUnit baseUnit,
  }) async {
    final container = ProviderContainer.test(
      overrides: [catalogOverride(repository: catalog), storeOverride()],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            // Watching the ViewModel here is what the real screen does, and
            // it is what puts the six catalogs in hand before the dialog
            // saves — without it every save would answer 'Aguarde os
            // cadastros carregarem.' and nothing else would be tested.
            body: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(catalogMaintenanceViewModelProvider);
                if (!state.hasValue) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => PackagingEditDialog.show(
                    context,
                    leaf: leaf,
                    baseUnit: baseUnit,
                  ),
                  child: const Text('abrir'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens written in the base unit, as a whole number', (
    tester,
  ) async {
    // 'prod-3' holds 2000 ml: the field reads '2000', never '2'. The large
    // unit belongs to the reading, not to the typing.
    await pumpDialog(
      tester,
      leaf: leafOf(
        'prod-3',
        pieceCount: 1,
        pieceSize: 2000,
        unit: BaseUnit.milliliter,
      ),
      baseUnit: BaseUnit.milliliter,
    );

    expect(find.text('Corrigir a embalagem'), findsOneWidget);
    expect(textOf(tester, countField), '1');
    expect(textOf(tester, sizeField), '2000');
    expect(find.text(CatalogEntryEditDialog.footnote), findsOneWidget);
  });

  testWidgets('there is no measure to choose: the type already answered', (
    tester,
  ) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    // The field simply says which unit it is typed in. No dropdown, so a
    // '350 g' of soft drink has no way of being typed.
    expect(find.text('Quanto tem cada?'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<BaseUnit>), findsNothing);
  });

  testWidgets('corrects the packaging and closes', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    await tester.enterText(sizeField, '500');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      catalog.writes.single.packaging,
      Packaging(
        pieceCount: 1,
        pieceSize: 500,
        baseUnit: BaseUnit.milliliter,
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('refuses a content the registration already has, under the '
      'field', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    // 'prod-1' is the 350 ml of the same registration.
    await tester.enterText(sizeField, '350');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Este cadastro já tem uma embalagem com esse conteúdo.'),
      findsOneWidget,
    );
    // Still open: the answer is about what was just typed, so it belongs
    // beside it and not in a SnackBar.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(catalog.writes, isEmpty);
  });

  testWidgets('the guard is CONTENT: 2 × 175 ml is the 350 ml leaf', (
    tester,
  ) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    await tester.enterText(countField, '2');
    await tester.enterText(sizeField, '175');
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Este cadastro já tem uma embalagem com esse conteúdo.'),
      findsOneWidget,
    );
    expect(catalog.writes, isEmpty);
  });

  testWidgets('a package with no pieces never reaches the repository', (
    tester,
  ) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    await tester.enterText(countField, '0');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe uma quantidade válida.'), findsOneWidget);
    expect(catalog.writes, isEmpty);
  });

  testWidgets('the size field takes digits and nothing else', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    // Every amount is typed in the small unit, which is a whole number — so
    // the iPhone keyboard must not offer a comma to begin with.
    await tester.enterText(sizeField, '2,5');
    await tester.pumpAndSettle();

    expect(textOf(tester, sizeField), '25');
    expect(
      tester.widget<TextField>(sizeField).keyboardType,
      TextInputType.number,
    );
  });

  testWidgets('a type measured in units has no measure field: the piece IS '
      'the unit', (tester) async {
    await pumpDialog(
      tester,
      leaf: _SpyCatalog.counted,
      baseUnit: BaseUnit.unit,
    );

    expect(find.text('Quantas unidades?'), findsOneWidget);
    expect(find.text('Quantas peças?'), findsNothing);
    expect(sizeField, findsNothing);

    await tester.enterText(countField, '6');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      catalog.writes.single.packaging,
      Packaging(
        pieceCount: 6,
        pieceSize: 1,
        baseUnit: BaseUnit.unit,
      ),
    );
  });

  testWidgets('deactivating writes and closes', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    expect(find.text('Desativar'), findsOneWidget);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    expect(catalog.writes.single.active, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a leaf that is off reads Reativar, and comes back', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      leaf: _SpyCatalog.inactive,
      baseUnit: BaseUnit.milliliter,
    );

    expect(find.text('Reativar'), findsOneWidget);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    expect(catalog.writes.single.active, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a failed deactivation goes to a SnackBar, and the dialog '
      'stays', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    catalog.failNextWrite = ApiException(500, 'boom');
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    expect(
      find.text('O servidor está indisponível. Tente de novo em instantes.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('a failed save goes under the field, without the exception', (
    tester,
  ) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    catalog.failNextWrite = ApiException(500, 'boom');
    await tester.enterText(sizeField, '500');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.text('O servidor está indisponível. Tente de novo em instantes.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('Cancelar closes without writing', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    await tester.enterText(sizeField, '500');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(catalog.writes, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the double tap fires one write: everything goes dead while it '
      'saves', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    catalog.gate = Completer<void>();
    await tester.enterText(sizeField, '500');
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Salvando...'), findsOneWidget);
    expect(tester.widget<TextField>(countField).enabled, isFalse);
    expect(tester.widget<TextField>(sizeField).enabled, isFalse);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(tester.widget<TextButton>(toggleButton).onPressed, isNull);

    await tester.tap(saveButton);
    await tester.pump();

    catalog.gate!.complete();
    await tester.pumpAndSettle();

    expect(catalog.writes, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });
}

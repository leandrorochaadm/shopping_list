import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/barcode_owner.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/ui/catalog/view_model/catalog_maintenance_view_model.dart';
import 'package:shopping_list/ui/catalog/widgets/catalog_entry_edit_dialog.dart';
import 'package:shopping_list/ui/catalog/widgets/packaging_edit_dialog.dart';

import '../helpers/barcode_camera.dart';
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
    packaging: Packaging(pieceCount: 4, pieceSize: 1, baseUnit: BaseUnit.unit),
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

  /// What the code writes record, by product id. No `Record`: one list each.
  final owners = <Barcode, BarcodeOwner>{};
  final added = <String>[];
  final removed = <String>[];
  Object? failNextCodeWrite;
  Completer<void>? codeGate;

  @override
  Future<IMap<Barcode, BarcodeOwner>> findOwners(IList<Barcode> codes) async =>
      {for (final code in codes) code: ?owners[code]}.lock;

  @override
  Future<void> addBarcode({
    required String productId,
    required Barcode code,
  }) async {
    final failure = failNextCodeWrite;
    failNextCodeWrite = null;
    if (failure != null) throw failure;
    await codeGate?.future;
    added.add(productId);
    return super.addBarcode(productId: productId, code: code);
  }

  @override
  Future<void> removeBarcode({
    required String productId,
    required Barcode code,
  }) async {
    final failure = failNextCodeWrite;
    failNextCodeWrite = null;
    if (failure != null) throw failure;
    removed.add(productId);
    return super.removeBarcode(productId: productId, code: code);
  }

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
  final barcodeField = find.byKey(const ValueKey('barcode'));
  final barcodeAdd = find.byKey(const ValueKey('barcode-add'));

  const cola = '7894900011517';
  final colaCode = Barcode.typed(cola);

  BarcodeOwner ownerOf({bool active = true}) => BarcodeOwner(
    product: Product(
      id: 'prod-3',
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: 1,
        pieceSize: 2000,
        baseUnit: BaseUnit.milliliter,
      ),
      active: active,
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: 'brand-1',
      description: 'original',
      sellingMode: SellingMode.byPiece,
    ),
    type: ProductType(
      id: 'type-1',
      name: 'Refrigerante',
      categoryId: 'cat-1',
      baseUnit: BaseUnit.milliliter,
    ),
    brand: Brand(id: 'brand-1', name: 'Coca-Cola'),
  );

  Future<void> include(WidgetTester tester, String raw) async {
    await tester.enterText(
      find.descendant(of: barcodeField, matching: find.byType(TextField)),
      raw,
    );
    await tester.pumpAndSettle();
    await tester.tap(barcodeAdd);
    await tester.pumpAndSettle();
  }

  String errorText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('barcode-error'))).data!;

  /// The `TextField` an `AppTextField` builds: the key is on the wrapper.
  Finder fieldIn(Finder field) =>
      find.descendant(of: field, matching: find.byType(TextField));

  String textOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(fieldIn(field)).controller!.text;

  Future<void> pumpDialog(
    WidgetTester tester, {
    required Product leaf,
    required BaseUnit baseUnit,
    FakeBarcodeCamera? camera,
    Product? other,
  }) async {
    final container = ProviderContainer.test(
      overrides: [
        catalogOverride(repository: catalog),
        storeOverride(),
        ?camera?.override,
      ],
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
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => PackagingEditDialog.show(
                        context,
                        leaf: leaf,
                        baseUnit: baseUnit,
                      ),
                      child: const Text('abrir'),
                    ),
                    if (other != null)
                      TextButton(
                        onPressed: () => PackagingEditDialog.show(
                          context,
                          leaf: other,
                          baseUnit: baseUnit,
                        ),
                        child: const Text('abrir outra'),
                      ),
                  ],
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
    // Typed in millilitres, READ in litres: the mask puts the comma in and
    // the suffix beside it says `L`.
    expect(textOf(tester, sizeField), '2,000');
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
      Packaging(pieceCount: 1, pieceSize: 500, baseUnit: BaseUnit.milliliter),
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

    // The sentence is the DOMAIN's, and it is the one about pieces: the
    // mask writes nothing malformed any more, so what used to be refused by
    // the text parser now reaches `Packaging` and is refused by the rule.
    expect(
      find.text('A embalagem precisa ter pelo menos uma peça.'),
      findsOneWidget,
    );
    expect(catalog.writes, isEmpty);
  });

  testWidgets('the size field takes digits and nothing else', (tester) async {
    await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

    // Every amount is typed in the small unit, which is a whole number — so
    // the iPhone keyboard must not offer a comma to begin with.
    await tester.enterText(sizeField, '2,5');
    await tester.pumpAndSettle();

    // The mask keeps the digits and writes the comma itself: 25 millilitres.
    expect(textOf(tester, sizeField), '0,025');
    expect(
      tester.widget<TextField>(fieldIn(sizeField)).keyboardType,
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
      Packaging(pieceCount: 6, pieceSize: 1, baseUnit: BaseUnit.unit),
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
    expect(tester.widget<TextField>(fieldIn(countField)).enabled, isFalse);
    expect(tester.widget<TextField>(fieldIn(sizeField)).enabled, isFalse);
    expect(tester.widget<TextField>(fieldIn(barcodeField)).enabled, isFalse);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(tester.widget<TextButton>(toggleButton).onPressed, isNull);

    await tester.tap(saveButton);
    await tester.pump();

    catalog.gate!.complete();
    await tester.pumpAndSettle();

    expect(catalog.writes, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('codes', () {
    Future<void> removeCola(WidgetTester tester) async {
      await tester.tap(find.byKey(ValueKey('barcode-remove-${colaCode.code}')));
      await tester.pumpAndSettle();
    }

    testWidgets('a leaf with no code says so', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      expect(find.text('Código de barras (opcional)'), findsOneWidget);
      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('a typed code goes in with + right away, without Salvar', (
      tester,
    ) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      await include(tester, cola);

      expect(catalog.added, ['prod-2']);
      expect(find.text('• ${colaCode.label}'), findsOneWidget);
      expect(
        tester.widget<TextField>(fieldIn(barcodeField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(catalog.writes, isEmpty);
    });

    testWidgets('a camera read goes straight in', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpDialog(
        tester,
        leaf: leaf269,
        baseUnit: BaseUnit.milliliter,
        camera: camera,
      );

      await tester.tap(find.byKey(const ValueKey('barcode-scan')));
      await tester.pumpAndSettle();
      camera.read(cola);
      await tester.pumpAndSettle();

      expect(catalog.added, ['prod-2']);
      expect(find.text('• ${colaCode.label}'), findsOneWidget);
    });

    testWidgets('x removes the code at once', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);
      await include(tester, cola);

      await removeCola(tester);

      expect(catalog.removed, ['prod-2']);
      expect(find.text('Nenhum código.'), findsOneWidget);
    });

    testWidgets('the removed code can go into another leaf', (tester) async {
      final leaf350 = leafOf(
        'prod-1',
        pieceCount: 1,
        pieceSize: 350,
        unit: BaseUnit.milliliter,
      );
      await pumpDialog(
        tester,
        leaf: leaf269,
        baseUnit: BaseUnit.milliliter,
        other: leaf350,
      );
      await include(tester, cola);
      await removeCola(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('abrir outra'));
      await tester.pumpAndSettle();
      await include(tester, cola);

      expect(catalog.added, ['prod-2', 'prod-1']);
      expect(find.byKey(const ValueKey('barcode-error')), findsNothing);
    });

    testWidgets('a code of an active leaf is refused under the field', (
      tester,
    ) async {
      final active = ownerOf();
      catalog.owners[colaCode] = active;
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      await include(tester, cola);

      expect(errorText(tester), 'Esse código já é do ${active.label}.');
      expect(catalog.added, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the same code twice on the leaf is refused', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);
      await include(tester, cola);

      await include(tester, cola);

      expect(errorText(tester), 'Esse código já está nesta embalagem.');
      expect(catalog.added, ['prod-2']);
    });

    testWidgets('a scale label is refused', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      await include(tester, '2822521001605');

      expect(errorText(tester), 'Esse é um código de balança.');
      expect(catalog.added, isEmpty);
    });

    testWidgets('an invalid code is refused', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      await include(tester, '7894900011518');

      expect(errorText(tester), 'Código de barras inválido.');
      expect(catalog.added, isEmpty);
    });

    testWidgets('a code of a deactivated leaf moves here and says where it '
        'came from', (tester) async {
      final inactive = ownerOf(active: false);
      catalog.owners[colaCode] = inactive;
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      await include(tester, cola);

      expect(catalog.removed, ['prod-3']);
      expect(catalog.added, ['prod-2']);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('barcode-notice'))).data,
        releasedBarcodeMessage(inactive),
      );
    });

    testWidgets('a failed write goes to a SnackBar and the dialog stays', (
      tester,
    ) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      catalog.failNextCodeWrite = ApiException(500, 'boom');
      await include(tester, cola);

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(fieldIn(barcodeField)).controller!.text,
        cola,
      );
      expect(find.textContaining('ApiException'), findsNothing);
    });

    testWidgets('a failed removal goes to a SnackBar', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);
      await include(tester, cola);

      catalog.failNextCodeWrite = ApiException(500, 'boom');
      await removeCola(tester);

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
      expect(find.text('• ${colaCode.label}'), findsOneWidget);
    });

    testWidgets('a loose leaf has no code block', (tester) async {
      await pumpDialog(
        tester,
        leaf: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
        baseUnit: BaseUnit.gram,
      );

      expect(find.text('Código de barras (opcional)'), findsNothing);
    });

    testWidgets('everything goes dead while a code is written', (tester) async {
      await pumpDialog(tester, leaf: leaf269, baseUnit: BaseUnit.milliliter);

      catalog.codeGate = Completer<void>();
      await tester.enterText(fieldIn(barcodeField), cola);
      await tester.pumpAndSettle();
      await tester.tap(barcodeAdd);
      await tester.pump();

      expect(tester.widget<TextField>(fieldIn(barcodeField)).enabled, isFalse);
      expect(tester.widget<IconButton>(barcodeAdd).onPressed, isNull);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(tester.widget<TextButton>(toggleButton).onPressed, isNull);

      await tester.tap(barcodeAdd, warnIfMissed: false);
      await tester.pump();

      catalog.codeGate!.complete();
      await tester.pumpAndSettle();

      expect(catalog.added, hasLength(1));
    });
  });
}

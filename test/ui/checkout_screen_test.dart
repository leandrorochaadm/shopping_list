import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:shopping_list/ui/barcode/widgets/barcode_camera_view.dart';
import 'package:shopping_list/ui/core/formatting.dart';
import 'package:shopping_list/ui/purchase/view_model/purchase_draft_view_model.dart';
import 'package:shopping_list/ui/purchase/widgets/checkout_screen.dart';
import 'package:shopping_list/ui/purchase/widgets/purchase_item_edit_dialog.dart';

import '../helpers/barcode_camera.dart';
import '../helpers/beep.dart';
import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/viewport.dart';

/// The first save waits for [gate]: the burst of reads arrives while a write
/// is still running.
class _GatedDrafts extends PurchaseDraftRepositoryLocal {
  _GatedDrafts({super.initial});

  final gate = Completer<void>();
  bool _first = true;

  @override
  Future<void> save(PurchaseDraft draft) async {
    if (_first) {
      _first = false;
      await gate.future;
    }
    return super.save(draft);
  }
}

class _FailingDrafts extends PurchaseDraftRepositoryLocal {
  _FailingDrafts({super.initial});

  Object? failNextSave;

  @override
  Future<void> save(PurchaseDraft draft) async {
    final failure = failNextSave;
    failNextSave = null;
    if (failure != null) throw failure;
    return super.save(draft);
  }
}

class _SpyCatalog extends CatalogRepositoryLocal {
  _SpyCatalog() : super(latency: Duration.zero);

  final linked = <ScaleCode>[];
  final linkedProducts = <String>[];
  Object? failNextLink;

  @override
  Future<void> addScaleCode({
    required String productId,
    required ScaleCode code,
  }) async {
    final failure = failNextLink;
    failNextLink = null;
    if (failure != null) throw failure;
    linkedProducts.add(productId);
    linked.add(code);
  }
}

void main() {
  setUpAll(initializePtBr);

  const crateCode = '7894900011517';
  const canCode = '7894900010015';
  const unknownCode = '7891000053508';
  const label = '2822521001605';

  final withStore = PurchaseDraft(
    purchaseId: 'a1',
    date: DateTime(2026, 8, 18),
    registeredBy: 'Leandro',
    storeId: 'store-1',
  );
  final noStore = PurchaseDraft(
    purchaseId: 'a1',
    date: DateTime(2026, 8, 18),
    registeredBy: 'Leandro',
  );

  final crate = optionByPiece(
    id: 'prod-4',
    brand: cokeBrand,
    pieceCount: 12,
    barcodes: [Barcode.typed(crateCode)].lock,
    priceReference: reference(cents: 6200, quantityInBaseUnit: 4200),
  );
  final can = optionByPiece(
    id: 'prod-1',
    brand: cokeBrand,
    barcodes: [Barcode.typed(canCode)].lock,
  );
  final beef = optionByWeight(
    id: 'prod-5',
    priceReference: reference(cents: 3990, quantityInBaseUnit: 1000),
    scaleCodes: [const ScaleCode(storeId: 'store-1', itemCode: '2822521')].lock,
  );

  late FakeBarcodeCamera camera;
  late SpyBeep beep;
  late int reloads;
  late bool closed;

  setUp(() {
    camera = FakeBarcodeCamera();
    beep = SpyBeep();
    reloads = 0;
    closed = false;
  });

  Future<ProviderContainer> openCheckout(
    WidgetTester tester, {
    required IList<ProductOption> options,
    PurchaseDraft? draft,
    PurchaseDraftRepositoryLocal? drafts,
    CatalogRepository? catalog,
    Future<ProductOption?> Function(Barcode)? onRegister,
    bool keyboard = false,
  }) async {
    if (keyboard) {
      useIPhone12WithKeyboard(tester);
    } else {
      useIPhone12(tester);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceUserOverride(),
          storeOverride(),
          catalogOverride(repository: catalog),
          purchaseDraftRepositoryProvider.overrideWith(
            (ref) =>
                drafts ??
                PurchaseDraftRepositoryLocal(initial: draft ?? withStore),
          ),
          camera.override,
          beep.override,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await CheckoutScreen.show(
                    context,
                    options: () => options,
                    onRegister: onRegister ?? (_) async => null,
                    reloadOptions: () async {
                      reloads++;
                      return null;
                    },
                  );
                  closed = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CheckoutScreen)),
    );
  }

  Future<void> read(WidgetTester tester, String raw) async {
    camera.read(raw);
    await tester.pumpAndSettle();
  }

  // The same code leaves the camera and comes back.
  Future<void> again(WidgetTester tester) => tester.pump(
    BarcodeCameraView.codeGoneGap + const Duration(milliseconds: 1),
  );

  IList<PurchaseItem> itemsOf(ProviderContainer container) =>
      container.read(purchaseDraftViewModelProvider).items;

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  String lastRead(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('checkout-last-read')))
      .data!;

  testWidgets('two reads of the same packaging make one line with 2', (
    tester,
  ) async {
    final container = await openCheckout(tester, options: [crate].lock);

    await read(tester, crateCode);
    await again(tester);
    await read(tester, crateCode);

    final items = itemsOf(container);
    expect(items.length, 1);
    expect(items.first.quantity, 2);
    expect(items.first.paid.cents, 12400);
    expect(items.first.priceOrigin, PriceOrigin.lastPurchase);
  });

  testWidgets('tapping "preço anterior" in the checkout confirms the line', (
    tester,
  ) async {
    final container = await openCheckout(tester, options: [crate].lock);

    await read(tester, crateCode);
    final id = itemsOf(container).single.id;
    final label = find.byKey(ValueKey('price-unconfirmed-$id'));
    expect(label, findsOneWidget);

    await tester.tap(label);
    await tester.pumpAndSettle();

    expect(label, findsNothing);
    final item = itemsOf(container).single;
    expect(item.priceOrigin, PriceOrigin.typed);
    expect(item.quantity, 1);
  });

  testWidgets('three reads in a burst make one line with 3', (tester) async {
    final drafts = _GatedDrafts(initial: withStore);
    final container = await openCheckout(
      tester,
      options: [crate].lock,
      drafts: drafts,
    );

    camera.read(crateCode);
    await again(tester);
    camera.read(crateCode);
    await again(tester);
    camera.read(crateCode);
    drafts.gate.complete();
    await tester.pumpAndSettle();

    expect(itemsOf(container).length, 1);
    expect(itemsOf(container).first.quantity, 3);
  });

  testWidgets('a read beeps, flashes and shows the name with the price', (
    tester,
  ) async {
    await openCheckout(tester, options: [crate].lock);

    await read(tester, crateCode);
    expect(
      lastRead(tester),
      '✓ ${crate.selectedLabel}  ${formatMoney(const Money(6200))}',
    );
    expect(beep.plays, 1);

    await again(tester);
    await read(tester, crateCode);
    // The price of ONE crate, not the one of the line.
    expect(
      lastRead(tester),
      '✓ ${crate.selectedLabel}  ${formatMoney(const Money(6200))}',
    );
    expect(beep.plays, 2);
  });

  testWidgets(
    'a packaging never bought opens the price on its line and stays out',
    (tester) async {
      final container = await openCheckout(tester, options: [can].lock);

      await read(tester, canCode);

      expect(find.byKey(const ValueKey('checkout-price-0')), findsOneWidget);
      expect(find.text('sem compra anterior'), findsOneWidget);
      expect(itemsOf(container), isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('checkout-price-0')),
        '350',
      );
      await tapKey(tester, 'checkout-price-ok-0');

      final items = itemsOf(container);
      expect(items.length, 1);
      expect(items.first.paid, const Money(350));
      expect(items.first.priceOrigin, PriceOrigin.typed);
      expect(find.byKey(const ValueKey('checkout-price-0')), findsNothing);
    },
  );

  testWidgets('OK with no price says so and keeps the line', (tester) async {
    final container = await openCheckout(tester, options: [can].lock);

    await read(tester, canCode);
    await tapKey(tester, 'checkout-price-ok-0');

    expect(find.text('Informe um valor válido.'), findsOneWidget);
    expect(itemsOf(container), isEmpty);
  });

  testWidgets(
    'the same packaging still without price sums on its pending line',
    (tester) async {
      final container = await openCheckout(tester, options: [can].lock);

      await read(tester, canCode);
      await again(tester);
      await read(tester, canCode);

      expect(find.byKey(const ValueKey('checkout-pending-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-pending-1')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('checkout-price-0')),
        '350',
      );
      await tapKey(tester, 'checkout-price-ok-0');

      final items = itemsOf(container);
      expect(items.length, 1);
      expect(items.first.quantity, 2);
      expect(items.first.paid, const Money(700));
    },
  );

  testWidgets('a job that throws does not stop the queue', (tester) async {
    final container = await openCheckout(
      tester,
      options: [crate].lock,
      onRegister: (_) async => throw StateError('boom'),
    );

    await read(tester, unknownCode);
    await tapKey(tester, 'checkout-unknown-register');
    // The test's own Scaffold under the same messenger draws it too.
    expect(find.byType(SnackBar), findsWidgets);

    await again(tester);
    await read(tester, crateCode);
    expect(itemsOf(container).length, 1);

    await tapKey(tester, 'checkout-done');
    expect(closed, isTrue);
  });

  testWidgets('each scale label is a new line', (tester) async {
    final container = await openCheckout(tester, options: [beef].lock);

    await read(tester, label);
    await again(tester);
    await read(tester, label);

    final items = itemsOf(container);
    expect(items.length, 2);
    expect(items.map((item) => item.quantityInBaseUnit), [160, 160]);
    expect(items.first.id, isNot(items.last.id));
  });

  testWidgets('a label read with no store adopts its store', (tester) async {
    final container = await openCheckout(
      tester,
      options: [beef].lock,
      draft: noStore,
    );

    await read(tester, label);

    expect(container.read(purchaseDraftViewModelProvider).storeId, 'store-1');
    expect(itemsOf(container).length, 1);
  });

  testWidgets('a label in two stores asks which one', (tester) async {
    final otherStore = optionByWeight(
      id: 'prod-7',
      priceReference: reference(cents: 3990, quantityInBaseUnit: 1000),
      scaleCodes: [
        const ScaleCode(storeId: 'store-2', itemCode: '2822521'),
      ].lock,
    );
    final container = await openCheckout(
      tester,
      options: [beef, otherStore].lock,
      draft: noStore,
    );

    await read(tester, label);
    expect(
      find.text('Esta etiqueta existe em mais de um mercado. Qual?'),
      findsOneWidget,
    );

    await tapKey(tester, 'scale-store-store-2');

    expect(itemsOf(container).single.option.id, 'prod-7');
    expect(container.read(purchaseDraftViewModelProvider).storeId, 'store-2');
  });

  testWidgets('an unlinked label asks which product and links it', (
    tester,
  ) async {
    final catalog = _SpyCatalog();
    final container = await openCheckout(
      tester,
      options: [
        optionByWeight(
          id: 'prod-5',
          priceReference: reference(cents: 3990, quantityInBaseUnit: 1000),
        ),
      ].lock,
      catalog: catalog,
    );

    await read(tester, label);
    expect(find.text('Qual produto é este?'), findsOneWidget);

    await tapKey(tester, 'scale-link-prod-5');

    expect(catalog.linked, [
      const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
    ]);
    expect(itemsOf(container).single.quantityInBaseUnit, 160);
    expect(reloads, 1);
  });

  testWidgets('a refused link still puts the line and says why', (
    tester,
  ) async {
    final catalog = _SpyCatalog()
      ..failNextLink = ApiException(409, 'duplicate');
    final container = await openCheckout(
      tester,
      options: [
        optionByWeight(
          id: 'prod-5',
          priceReference: reference(cents: 3990, quantityInBaseUnit: 1000),
        ),
      ].lock,
      catalog: catalog,
    );

    await read(tester, label);
    await tapKey(tester, 'scale-link-prod-5');

    expect(find.text(ScaleCode.takenMessage), findsWidgets);
    expect(itemsOf(container).length, 1);
    expect(reloads, 0);
  });

  testWidgets(
    'an unknown code with Depois becomes a line out of the purchase',
    (tester) async {
      final container = await openCheckout(tester, options: [crate].lock);

      await read(tester, unknownCode);
      expect(find.text('Produto não cadastrado'), findsOneWidget);
      await tapKey(tester, 'checkout-unknown-later');

      expect(
        find.text('Produto não cadastrado · 7891000053508'),
        findsOneWidget,
      );
      expect(itemsOf(container), isEmpty);

      await again(tester);
      await read(tester, unknownCode);
      await tapKey(tester, 'checkout-unknown-later');
      expect(
        find.text('Produto não cadastrado · 7891000053508'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Cadastrar opens screen 4 with the code and the new leaf comes back pending',
    (tester) async {
      final registered = <Barcode>[];
      final completer = Completer<ProductOption?>();
      await openCheckout(
        tester,
        options: [crate].lock,
        onRegister: (code) {
          registered.add(code);
          return completer.future;
        },
      );

      await read(tester, unknownCode);
      await tapKey(tester, 'checkout-unknown-register');
      // Screen 4 is on top: the camera is off the tree.
      expect(find.byKey(const ValueKey('fake-camera')), findsNothing);

      completer.complete(
        optionByPiece(
          id: 'prod-9',
          barcodes: [Barcode.typed(unknownCode)].lock,
        ),
      );
      await tester.pumpAndSettle();

      expect(registered, [Barcode.typed(unknownCode)]);
      expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-price-0')), findsOneWidget);
    },
  );

  testWidgets('Cadastrar given up leaves the code out', (tester) async {
    await openCheckout(tester, options: [crate].lock);

    await read(tester, unknownCode);
    await tapKey(tester, 'checkout-unknown-register');

    expect(find.text('Produto não cadastrado · 7891000053508'), findsOneWidget);
  });

  testWidgets('reads while a question is open are not counted', (tester) async {
    final container = await openCheckout(tester, options: [crate].lock);

    await read(tester, unknownCode);
    await read(tester, crateCode);
    await tapKey(tester, 'checkout-unknown-later');

    expect(itemsOf(container), isEmpty);
  });

  testWidgets('an invalid code and a strange label say so over the camera', (
    tester,
  ) async {
    final drafts = PurchaseDraftRepositoryLocal(initial: withStore);
    await openCheckout(tester, options: [crate].lock, drafts: drafts);

    await read(tester, '7894900011518');
    expect(lastRead(tester), 'Código de barras inválido.');

    await again(tester);
    await read(tester, '212345678909');
    expect(
      lastRead(tester),
      'Não conheço esta etiqueta. Escolha o produto pela lista.',
    );
    expect(beep.plays, 0);
    expect(drafts.writes, 0);
  });

  testWidgets('ed edits a line and there is no trash can', (tester) async {
    final container = await openCheckout(tester, options: [crate].lock);

    await read(tester, crateCode);
    expect(find.byTooltip('Remover ${crate.selectedLabel}'), findsNothing);

    await tester.tap(find.byTooltip('Corrigir ${crate.selectedLabel}'));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseItemEditDialog), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '5000');
    await tapKey(tester, 'save-item');

    final item = itemsOf(container).single;
    expect(item.paid, const Money(5000));
    expect(item.priceOrigin, PriceOrigin.typed);
  });

  testWidgets('a refused write shows the sentence and keeps the line', (
    tester,
  ) async {
    final drafts = _FailingDrafts(initial: withStore);
    final container = await openCheckout(
      tester,
      options: [crate].lock,
      drafts: drafts,
    );

    drafts.failNextSave = StateError('denied');
    await read(tester, crateCode);

    // The test's own Scaffold under the same messenger draws it too.
    expect(find.byType(SnackBar), findsWidgets);
    expect(itemsOf(container).length, 1);
    expect(find.byTooltip('Corrigir ${crate.selectedLabel}'), findsOneWidget);
  });

  testWidgets('the total counts only what entered the purchase', (
    tester,
  ) async {
    await openCheckout(tester, options: [crate, can].lock);

    await read(tester, crateCode);
    await again(tester);
    await read(tester, canCode);

    expect(find.text('1 item'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('checkout-total'))).data,
      formatMoney(const Money(6200)),
    );
  });

  testWidgets('Concluir with nothing left out closes and keeps the items', (
    tester,
  ) async {
    final container = await openCheckout(tester, options: [crate].lock);

    await read(tester, crateCode);
    await tapKey(tester, 'checkout-done');

    expect(closed, isTrue);
    expect(itemsOf(container).length, 1);
  });

  testWidgets('Concluir with a line without price warns; Voltar stays', (
    tester,
  ) async {
    final container = await openCheckout(tester, options: [crate, can].lock);

    await read(tester, crateCode);
    await again(tester);
    await read(tester, canCode);

    await tapKey(tester, 'checkout-done');
    expect(find.text('1 item sem preço não entrou na compra.'), findsOneWidget);
    await tapKey(tester, 'checkout-exit-back');
    expect(closed, isFalse);

    await tapKey(tester, 'checkout-done');
    await tapKey(tester, 'checkout-exit-anyway');
    expect(closed, isTrue);
    expect(itemsOf(container).length, 1);
  });

  testWidgets(
    'a line without price and an unregistered code are counted together',
    (tester) async {
      await openCheckout(tester, options: [can].lock);

      await read(tester, canCode);
      await again(tester);
      await read(tester, unknownCode);
      await tapKey(tester, 'checkout-unknown-later');

      await tapKey(tester, 'checkout-done');
      expect(find.text('2 itens não entraram na compra.'), findsOneWidget);
    },
  );

  test('checkoutLeftOutMessage', () {
    expect(
      checkoutLeftOutMessage(withoutPrice: 1, unregistered: 0),
      '1 item sem preço não entrou na compra.',
    );
    expect(
      checkoutLeftOutMessage(withoutPrice: 2, unregistered: 0),
      '2 itens sem preço não entraram na compra.',
    );
    expect(
      checkoutLeftOutMessage(withoutPrice: 0, unregistered: 1),
      '1 item não entrou na compra.',
    );
    expect(
      checkoutLeftOutMessage(withoutPrice: 1, unregistered: 1),
      '2 itens não entraram na compra.',
    );
  });

  testWidgets(
    'without a camera the Settings sentence shows and Concluir still works',
    (tester) async {
      await openCheckout(tester, options: [crate].lock);

      camera.failToOpen();
      await tester.pumpAndSettle();
      expect(
        find.text('Libere a câmera nos Ajustes do iPhone.'),
        findsOneWidget,
      );

      await tapKey(tester, 'checkout-done');
      expect(closed, isTrue);
    },
  );

  testWidgets('with the keyboard up the price field stays above it', (
    tester,
  ) async {
    await openCheckout(tester, options: [can].lock, keyboard: true);

    await read(tester, canCode);

    final field = tester.getRect(
      find.byKey(const ValueKey('checkout-price-0')),
    );
    final ok = tester.getRect(
      find.byKey(const ValueKey('checkout-price-ok-0')),
    );
    expect(field.bottom, lessThanOrEqualTo(iPhone12KeyboardFold));
    expect(ok.bottom, lessThanOrEqualTo(iPhone12KeyboardFold));
    expect(find.byKey(const ValueKey('checkout-total')), findsNothing);
  });
}

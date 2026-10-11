import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/online_status.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/scale_label.dart';
import 'package:shopping_list/domain/models/unit_price.dart';
import 'package:shopping_list/ui/core/unit_specs.dart';
import 'package:tekton_core/tekton_core.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/purchase/view_model/purchase_draft_view_model.dart';
import 'package:shopping_list/ui/purchase/widgets/new_purchase_screen.dart'
    show unconfirmedPricesMessage;
import 'package:shopping_list/ui/purchase/widgets/product_field.dart';
import 'package:shopping_list/ui/purchase/widgets/purchase_item_row.dart';

import '../helpers/barcode_camera.dart';
import '../helpers/beep.dart';
import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';
import '../helpers/spending_cap.dart';
import '../helpers/viewport.dart';

class _SpyPurchases extends PurchaseRepositoryLocal {
  _SpyPurchases({super.sameDayBuyer}) : super(latency: Duration.zero);

  Object? failNextCall;
  Object? failNextSave;
  int saveCalls = 0;
  IList<ProductOption>? options;
  int fetchOptionsCalls = 0;

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    fetchOptionsCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return options ?? await super.fetchProductOptions();
  }

  @override
  Future<bool> save(PurchaseSubmission submission) async {
    saveCalls++;
    final failure = failNextSave;
    failNextSave = null;
    if (failure != null) throw failure;
    return super.save(submission);
  }
}

/// The catalog fake does not know the leaves of the purchase fake, so linking
/// a scale code only records what was asked.
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

final class _Offline extends OnlineStatus {
  @override
  bool build() => false;
}

void main() {
  // `main()` does not run in a test, and this screen draws a date.
  setUpAll(initializePtBr);

  final crate = optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12);

  PurchaseDraft draftWithItem() => PurchaseDraft(
    purchaseId: 'a1',
    date: DateTime(2026, 8, 18),
    registeredBy: 'Leandro',
    storeId: 'store-1',
  ).withItem(purchaseItem(id: 'i1', option: crate, cents: 6200));

  PurchaseDraft draftWithUnconfirmed() => draftWithItem()
      .withItem(
        purchaseItem(
          id: 'i2',
          option: optionByPiece(id: 'prod-1', brand: cokeBrand),
          cents: 350,
          priceOrigin: PriceOrigin.lastPurchase,
        ),
      )
      .withItem(
        purchaseItem(
          id: 'i3',
          option: optionByPiece(id: 'prod-2', brand: cokeBrand, pieceCount: 6),
          cents: 400,
          priceOrigin: PriceOrigin.lastPurchase,
        ),
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    PurchaseRepository? purchases,
    StoreRepository? stores,
    PurchaseDraft? draft,
    SpendingCapRepository? caps,
    CatalogRepository? catalog,
    List<Override> overrides = const [],
  }) async {
    // A tall viewport: the form is long, and the default 800×600 leaves the
    // save button outside the render tree.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        spendingCapOverride(repository: caps),
        catalogOverride(repository: catalog),
        shoppingListOverride(),
        purchaseRepositoryProvider.overrideWith(
          (ref) => purchases ?? _SpyPurchases(),
        ),
        purchaseDraftRepositoryProvider.overrideWith(
          (ref) => PurchaseDraftRepositoryLocal(initial: draft),
        ),
        storeRepositoryProvider.overrideWith(
          (ref) => stores ?? StoreRepositoryLocal(latency: Duration.zero),
        ),
        ...overrides,
      ],
    );

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
        ),
      ),
    );
    router.go(Routes.newPurchase);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> fillItem(
    WidgetTester tester, {
    String product = 'Coca',
    String quantity = '1',
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('field-product')),
      product,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original 12 × 350 ml').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      quantity,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens with today and an empty purchase', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.text('Salvar compra'), findsOneWidget);
    expect(find.text(r'R$ 0,00'), findsOneWidget);
    expect(find.byType(PurchaseItemRow), findsNothing);
  });

  testWidgets('the calendar cannot reach a day after today', (tester) async {
    // Blocking it at the source beats a message afterwards — and
    // `Purchase.checkDate` is still the rule, because a screen may never be
    // the only guard.
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('field-date')));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final today = DateTime.now();
    expect(picker.lastDate, DateTime(today.year, today.month, today.day));
  });

  testWidgets('an empty system says so in both fields', (tester) async {
    await pumpScreen(
      tester,
      purchases: _EmptyCatalog(),
      stores: StoreRepositoryLocal(initial: const [], latency: Duration.zero),
    );

    expect(
      find.text('Nenhum produto ainda — cadastre o primeiro'),
      findsOneWidget,
    );
    expect(
      find.text('Nenhum mercado ainda — cadastre o primeiro'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load disables the fields and KEEPS the purchase', (
    tester,
  ) async {
    // The airplane-mode case, and the reading of H8 that matters: with no
    // network there is no way to pick a product or a store, but nothing that
    // was already typed may be lost. This test has to FAIL if the body is
    // swapped for an error MessageView.
    final purchases = _SpyPurchases()..failNextCall = NetworkException('off');
    await pumpScreen(tester, purchases: purchases, draft: draftWithItem());

    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
    // The purchase is STILL on screen.
    expect(find.byType(PurchaseItemRow), findsOneWidget);
    expect(find.text('Refrigerante Coca-Cola 12 × 350 ml'), findsOneWidget);
    expect(find.text(r'R$ 62,00'), findsWidgets);
    // And the raw exception never reaches it.
    expect(find.textContaining('NetworkException'), findsNothing);
  });

  testWidgets('trying again brings the picker back', (tester) async {
    final purchases = _SpyPurchases()..failNextCall = NetworkException('off');
    await pumpScreen(tester, purchases: purchases);

    await tester.tap(find.byKey(const ValueKey('retry-products')));
    await tester.pumpAndSettle();

    expect(find.text('Tentar de novo'), findsNothing);
  });

  // The search itself moved to `product_field_test.dart` with the widget
  // (step 18): what screen 3 owes is that it MOUNTS the picker, with the
  // options it loaded.
  testWidgets('mounts the shared picker with the loaded options', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(ProductField), findsOneWidget);
    expect(
      tester.widget<ProductField>(find.byType(ProductField)).options,
      isNotEmpty,
    );

    await tester.enterText(find.byKey(const ValueKey('field-product')), 'coca');
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola original 12 × 350 ml'), findsOneWidget);
  });

  testWidgets('the value comes pre-filled from the last purchase', (
    tester,
  ) async {
    // The fake bought the crate for R$ 62,00; one crate again is exactly
    // R$ 62,00 — not R$ 62,04, which a rounded price per litre would give.
    await pumpScreen(tester);
    await fillItem(tester);

    final value = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-value')),
        matching: find.byType(TextField),
      ),
    );
    expect(value.controller!.text, 'R\$\u{A0}62,00');
  });

  testWidgets('the value left empty is refused, and nothing is added', (
    tester,
  ) async {
    // What replaces the old "not a number" refusal: the mask makes a
    // malformed value impossible to type, so the field can only be EMPTY.
    await pumpScreen(tester);
    await fillItem(tester);
    await tester.enterText(find.byKey(const ValueKey('field-value')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    expect(find.text('Informe um valor válido.'), findsOneWidget);
    expect(find.byType(PurchaseItemRow), findsNothing);
  });

  testWidgets('a value typed by hand stops being recomputed', (tester) async {
    await pumpScreen(tester);
    await fillItem(tester);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '5500');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '2');
    await tester.pumpAndSettle();

    final value = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-value')),
        matching: find.byType(TextField),
      ),
    );
    expect(value.controller!.text, 'R\$\u{A0}55,00');
  });

  Future<void> fillLooseItem(
    WidgetTester tester, {
    String quantity = '500',
  }) async {
    await tester.enterText(find.byKey(const ValueKey('field-product')), 'Acém');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acém moído (peso)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      quantity,
    );
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('the price per pricing unit only exists sold by weight', (
    tester,
  ) async {
    // Sold by piece the price already IS the package's: a crate has no
    // "price per litre" to type.
    await pumpScreen(tester);
    await fillItem(tester);
    expect(find.byKey(const ValueKey('field-unit-price')), findsNothing);

    await fillLooseItem(tester);

    expect(find.byKey(const ValueKey('field-unit-price')), findsOneWidget);
    expect(find.text('Valor por kg'), findsOneWidget);
  });

  testWidgets('typing the price per kilo redoes the total paid', (
    tester,
  ) async {
    await pumpScreen(tester);
    await fillLooseItem(tester);

    await tester.enterText(
      find.byKey(const ValueKey('field-unit-price')),
      '3990',
    );
    await tester.pumpAndSettle();

    // Half a kilo at R$ 39,90 the kilo.
    expect(textOf(tester, 'field-value'), 'R\$\u{A0}19,95');
  });

  testWidgets('typing the total paid redoes the price per kilo', (
    tester,
  ) async {
    await pumpScreen(tester);
    await fillLooseItem(tester);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '1995');
    await tester.pumpAndSettle();

    expect(textOf(tester, 'field-unit-price'), 'R\$\u{A0}39,90');
  });

  testWidgets('changing the amount redoes the field that was NOT typed', (
    tester,
  ) async {
    // The price per kilo is what the shelf tag says: it does not change
    // because the piece on the scale weighs more.
    await pumpScreen(tester);
    await fillLooseItem(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field-unit-price')),
      '3990',
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '1000',
    );
    await tester.pumpAndSettle();

    expect(textOf(tester, 'field-unit-price'), 'R\$\u{A0}39,90');
    expect(textOf(tester, 'field-value'), 'R\$\u{A0}39,90');
  });

  testWidgets('the total typed by hand keeps its place when the amount grows', (
    tester,
  ) async {
    await pumpScreen(tester);
    await fillLooseItem(tester);
    await tester.enterText(find.byKey(const ValueKey('field-value')), '1995');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-quantity')),
      '1000',
    );
    await tester.pumpAndSettle();

    // The total is the source, so it stays and the price per kilo halves.
    expect(textOf(tester, 'field-value'), 'R\$\u{A0}19,95');
    expect(textOf(tester, 'field-unit-price'), 'R\$\u{A0}19,95');
  });

  testWidgets('emptying the total empties the price per kilo', (tester) async {
    await pumpScreen(tester);
    await fillLooseItem(tester);
    await tester.enterText(find.byKey(const ValueKey('field-value')), '1995');
    await tester.pumpAndSettle();
    expect(textOf(tester, 'field-unit-price'), isNotEmpty);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '');
    await tester.pumpAndSettle();

    expect(textOf(tester, 'field-unit-price'), isEmpty);
  });

  testWidgets('changing the product clears the amount and both money fields', (
    tester,
  ) async {
    // A different product is a different line: nothing of the previous one
    // may stay in the fields.
    await pumpScreen(tester);
    await fillLooseItem(tester);
    await tester.enterText(
      find.byKey(const ValueKey('field-unit-price')),
      '3990',
    );
    await tester.pumpAndSettle();
    expect(textOf(tester, 'field-value'), isNotEmpty);

    await tester.enterText(find.byKey(const ValueKey('field-product')), 'Coca');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original 12 × 350 ml').last);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'field-quantity'), isEmpty);
    expect(textOf(tester, 'field-value'), isEmpty);
    expect(find.byKey(const ValueKey('field-unit-price')), findsNothing);
  });

  testWidgets('a price 10% over the window average warns while typing (H15)', (
    tester,
  ) async {
    // The fake's two crates — R$ 62,00 and R$ 59,90 for 4200 ml each — make a
    // weighted average of R$ 14,51 a litre. R$ 70,00 for one crate is
    // R$ 16,67 a litre: +15%.
    await pumpScreen(tester);
    await fillItem(tester);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '7000');
    await tester.pumpAndSettle();

    expect(find.text('Subiu 15% sobre a média'), findsOneWidget);
  });

  testWidgets('the suggested value does not warn — no alert under 10%', (
    tester,
  ) async {
    await pumpScreen(tester);
    await fillItem(tester);

    // R$ 62,00 is what the field pre-fills, and it is +7% over the average.
    expect(find.textContaining('sobre a média'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '6200');
    await tester.pumpAndSettle();

    expect(find.textContaining('sobre a média'), findsNothing);
  });

  testWidgets('with the value emptied there is no warning at all (H15)', (
    tester,
  ) async {
    // The alert only exists after quantity AND value: it is the price per
    // base unit that is compared, and it comes out of the two.
    await pumpScreen(tester);
    await fillItem(tester);
    await tester.enterText(find.byKey(const ValueKey('field-value')), '7000');
    await tester.pumpAndSettle();
    expect(find.text('Subiu 15% sobre a média'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '');
    await tester.pumpAndSettle();

    expect(find.textContaining('sobre a média'), findsNothing);
  });

  testWidgets('adding a line redoes the total and clears the form', (
    tester,
  ) async {
    await pumpScreen(tester);
    await fillItem(tester);

    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseItemRow), findsOneWidget);
    expect(find.text(r'R$ 62,00'), findsWidgets);
    final quantity = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-quantity')),
        matching: find.byType(TextField),
      ),
    );
    expect(quantity.controller!.text, isEmpty);
  });

  testWidgets('[ed] reopens the line and corrects it instead of adding one', (
    tester,
  ) async {
    await pumpScreen(tester, draft: draftWithItem());

    await tester.tap(
      find.byTooltip('Corrigir Refrigerante Coca-Cola 12 × 350 ml'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salvar alteração'), findsOneWidget);
    final value = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-value')),
        matching: find.byType(TextField),
      ),
    );
    expect(value.controller!.text, 'R\$\u{A0}62,00');

    await tester.enterText(find.byKey(const ValueKey('field-value')), '5900');
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseItemRow), findsOneWidget, reason: 'not two');
    expect(find.text(r'R$ 59,00'), findsWidgets);
  });

  testWidgets('[Remover] takes the line out and redoes the total', (
    tester,
  ) async {
    await pumpScreen(tester, draft: draftWithItem());

    await tester.tap(
      find.byTooltip('Remover Refrigerante Coca-Cola 12 × 350 ml'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseItemRow), findsNothing);
    expect(find.text(r'R$ 0,00'), findsOneWidget);
  });

  testWidgets('a recovered draft warns, and [Continuar] keeps it', (
    tester,
  ) async {
    await pumpScreen(tester, draft: draftWithItem());

    // The date field shows 18/08/2026 too, so the banner is matched whole.
    expect(
      find.text('Rascunho recuperado: compra de 18/08, 1 item, não salva.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rascunho recuperado'), findsNothing);
    // The purchase is NOT thrown away.
    expect(find.byType(PurchaseItemRow), findsOneWidget);
  });

  testWidgets('[Descartar] throws the recovered purchase away', (tester) async {
    await pumpScreen(tester, draft: draftWithItem());

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rascunho recuperado'), findsNothing);
    expect(find.byType(PurchaseItemRow), findsNothing);
    expect(find.text(r'R$ 0,00'), findsOneWidget);
  });

  testWidgets('with no signal the banner and the button say what happens', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      draft: draftWithItem(),
      overrides: [onlineStatusProvider.overrideWith(_Offline.new)],
    );

    // The wording decided in this story (D3): WebKit has no Background Sync,
    // so nothing goes up with the app closed and the sentence does not
    // promise it.
    expect(
      find.textContaining('será salva quando você abrir o app com sinal'),
      findsOneWidget,
    );
    expect(find.text('Salvar quando eu abrir com sinal'), findsOneWidget);
  });

  testWidgets('saving offline keeps the purchase on screen', (tester) async {
    final purchases = _SpyPurchases();
    await pumpScreen(
      tester,
      purchases: purchases,
      draft: draftWithItem(),
      overrides: [onlineStatusProvider.overrideWith(_Offline.new)],
    );

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    expect(purchases.saveCalls, 0, reason: 'no attempt at all');
    // No navigation: leaving would hide a purchase that is still waiting.
    expect(find.text('Lançar compra'), findsOneWidget);
    expect(find.byType(PurchaseItemRow), findsOneWidget);
  });

  testWidgets('a failed save keeps the purchase and says why', (tester) async {
    final purchases = _SpyPurchases()..failNextSave = ApiException(500, 'boom');
    await pumpScreen(tester, purchases: purchases, draft: draftWithItem());

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    expect(
      find.text('O servidor está indisponível. Tente de novo em instantes.'),
      findsOneWidget,
    );
    expect(find.byType(PurchaseItemRow), findsOneWidget);
    // The raw exception NEVER reaches the screen.
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('a successful save leaves the screen and clears the draft', (
    tester,
  ) async {
    final purchases = _SpyPurchases();
    await pumpScreen(tester, purchases: purchases, draft: draftWithItem());

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    expect(purchases.saveCalls, 1);
    expect(find.text('Lista de compras'), findsOneWidget);
    // Nothing was crossed and nothing repeated: no dialog at all.
    expect(find.byKey(const ValueKey('warnings')), findsNothing);
  });

  testWidgets('the cap warning appears, and [ Entendi ] leads to the list', (
    tester,
  ) async {
    // R$ 1.150 already spent + the R$ 62 of this purchase crosses the R$ 1.200
    // cut of a R$ 1.500 cap.
    await pumpScreen(
      tester,
      draft: draftWithItem(),
      caps: SpendingCapRepositoryLocal(
        latency: Duration.zero,
        today: DateTime(2026, 8, 18),
        cap: SpendingCap(
          amount: const Money(150000),
          effectiveFrom: DateTime(2026, 8, 1),
        ),
        spending: {DateTime(2026, 8, 1): const Money(115000)},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    expect(find.text('O gasto do mês passou de 80% do teto.'), findsOneWidget);
    // The purchase is registered either way: the dialog acknowledges it.
    expect(find.text('Compra salva.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('acknowledge-warnings')));
    await tester.pumpAndSettle();

    expect(find.text('Lista de compras'), findsOneWidget);
  });

  testWidgets('both warnings stack on the same screen, the cap on top', (
    tester,
  ) async {
    // The purchase has to be of TODAY for H14's window, and the screen reads
    // the phone's clock for it.
    final today = DateTime.now();
    final month = DateTime(today.year, today.month);
    final draft = PurchaseDraft(
      purchaseId: 'a1',
      date: today,
      registeredBy: 'Leandro',
      storeId: 'store-1',
    ).withItem(purchaseItem(id: 'i1', option: crate, cents: 6200));

    await pumpScreen(
      tester,
      purchases: _SpyPurchases(sameDayBuyer: 'esposa'),
      draft: draft,
      caps: SpendingCapRepositoryLocal(
        latency: Duration.zero,
        today: today,
        cap: SpendingCap(amount: const Money(150000), effectiveFrom: month),
        spending: {month: const Money(115000)},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    final cap = tester.getTopLeft(
      find.text('O gasto do mês passou de 80% do teto.'),
    );
    final repeat = tester.getTopLeft(
      find.text('Vocês dois compraram Refrigerante hoje.'),
    );

    // The wireframe: the cap above, the repeat below, ONE button.
    expect(cap.dy, lessThan(repeat.dy));
    expect(find.text('Entendi'), findsOneWidget);
  });

  group('unconfirmed prices (M-f)', () {
    PurchaseItem line(ProviderContainer c, String id) => c
        .read(purchaseDraftViewModelProvider)
        .items
        .firstWhere((item) => item.id == id);

    Finder label(String id) => find.byKey(ValueKey('price-unconfirmed-$id'));

    testWidgets('a line at the last purchase price shows the label and a tap '
        'confirms it', (tester) async {
      final container = await pumpScreen(tester, draft: draftWithUnconfirmed());

      expect(label('i2'), findsOneWidget);
      expect(label('i3'), findsOneWidget);
      expect(label('i1'), findsNothing);

      await tester.tap(label('i2'));
      await tester.pumpAndSettle();

      expect(label('i2'), findsNothing);
      expect(line(container, 'i2').priceOrigin, PriceOrigin.typed);
      expect(line(container, 'i3').priceOrigin, PriceOrigin.lastPurchase);
    });

    testWidgets('a draft with every price typed shows no label and no button', (
      tester,
    ) async {
      await pumpScreen(tester, draft: draftWithItem());

      expect(find.text('preço anterior'), findsNothing);
      expect(find.byKey(const ValueKey('confirm-all-prices')), findsNothing);
    });

    testWidgets('correcting the line in [ed] confirms its price', (
      tester,
    ) async {
      final container = await pumpScreen(tester, draft: draftWithUnconfirmed());

      await tester.tap(
        find.byTooltip('Corrigir Refrigerante Coca-Cola 350 ml'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('field-value')), '390');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();

      expect(label('i2'), findsNothing);
      expect(line(container, 'i2').priceOrigin, PriceOrigin.typed);
      expect(line(container, 'i2').paid, const Money(390));
    });

    testWidgets('[ Todos conferidos ] sits above the items and confirms them '
        'all', (tester) async {
      final container = await pumpScreen(tester, draft: draftWithUnconfirmed());

      final button = tester.getTopLeft(
        find.byKey(const ValueKey('confirm-all-prices')),
      );
      final title = tester.getTopLeft(find.text('Itens desta compra'));
      expect(button.dy, lessThan(title.dy));

      await tester.tap(find.byKey(const ValueKey('confirm-all-prices')));
      await tester.pumpAndSettle();

      expect(find.text('preço anterior'), findsNothing);
      expect(find.byKey(const ValueKey('confirm-all-prices')), findsNothing);
      expect(
        container.read(purchaseDraftViewModelProvider).unconfirmedPrices,
        0,
      );
      expect(line(container, 'i1').paid, const Money(6200));
    });

    testWidgets('saving with unconfirmed prices asks first', (tester) async {
      final purchases = _SpyPurchases();
      await pumpScreen(
        tester,
        purchases: purchases,
        draft: draftWithUnconfirmed(),
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();

      expect(find.text('2 preços não conferidos.'), findsOneWidget);
      expect(find.text('Bateu com o cupom?'), findsOneWidget);
      expect(purchases.saveCalls, 0);
    });

    testWidgets('[ Conferir ] saves nothing and keeps the labels', (
      tester,
    ) async {
      final purchases = _SpyPurchases();
      await pumpScreen(
        tester,
        purchases: purchases,
        draft: draftWithUnconfirmed(),
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('check-prices')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(purchases.saveCalls, 0);
      expect(find.text('preço anterior'), findsNWidgets(2));
      expect(find.text('Lançar compra'), findsWidgets);
    });

    testWidgets('[ Conferi, salvar ] confirms them all and saves', (
      tester,
    ) async {
      final purchases = _SpyPurchases();
      await pumpScreen(
        tester,
        purchases: purchases,
        draft: draftWithUnconfirmed(),
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prices-checked-save')));
      await tester.pumpAndSettle();

      expect(purchases.saveCalls, 1);
      expect(find.text('Lista de compras'), findsWidgets);
    });

    testWidgets('[ Conferi, salvar ] with a failed save keeps the prices '
        'confirmed', (tester) async {
      final purchases = _SpyPurchases()
        ..failNextSave = ApiException(500, 'boom');
      final container = await pumpScreen(
        tester,
        purchases: purchases,
        draft: draftWithUnconfirmed(),
      );

      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prices-checked-save')));
      await tester.pumpAndSettle();

      expect(purchases.saveCalls, 1);
      expect(find.text('preço anterior'), findsNothing);
      expect(
        container.read(purchaseDraftViewModelProvider).unconfirmedPrices,
        0,
      );
    });

    testWidgets('a double tap on save opens one question', (tester) async {
      // This test has to FAIL if the `_askingPrices` guard is removed.
      await pumpScreen(tester, draft: draftWithUnconfirmed());

      final save = find.byKey(const ValueKey('save'));
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    test('unconfirmedPricesMessage uses the Portuguese plural', () {
      expect(unconfirmedPricesMessage(1), '1 preço não conferido.');
      expect(unconfirmedPricesMessage(2), '2 preços não conferidos.');
    });
  });

  testWidgets('a double tap on save writes once', (tester) async {
    // The reentrancy guard. This test has to FAIL if it is removed.
    final purchases = _SpyPurchases();
    await pumpScreen(tester, purchases: purchases, draft: draftWithItem());

    final save = find.byKey(const ValueKey('save'));
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(purchases.saveCalls, 1);
  });

  testWidgets('a product registered on the spot comes back selected', (
    tester,
  ) async {
    // The `[+Novo]→4` of the wireframe, all the way round: screen 4 is
    // PUSHED (a `go` would replace the route and take the purchase away),
    // and it pops the leaf the radio marked.
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('new-product')));
    await tester.pumpAndSettle();
    expect(find.text('Novo produto'), findsOneWidget);

    // The dropdowns of screen 4 open in an overlay, so the item is tapped
    // there and not in the field.
    await tester.tap(find.byKey(const ValueKey('field-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refrigerante').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-description')),
      'limão',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('size-1')), '600');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    // Back on screen 3, with the purchase intact and the new leaf chosen.
    expect(find.text('Lançar compra'), findsOneWidget);
    final product = tester.widget<TextField>(
      find.byKey(const ValueKey('field-product')),
    );
    expect(product.controller!.text, contains('limão'));
    // It is selectable straight away, without the picker being reloaded.
    final quantity = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field-quantity')),
        matching: find.byType(TextField),
      ),
    );
    expect(quantity.enabled, isTrue);
  });

  testWidgets('a store registered on the spot is selected', (tester) async {
    // The `[+Novo]↻` of the wireframe: registering the store where it was
    // missed, without leaving the purchase.
    await pumpScreen(
      tester,
      stores: StoreRepositoryLocal(initial: const [], latency: Duration.zero),
    );

    await tester.tap(find.byKey(const ValueKey('new-store')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Carrefour');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // The header folds as soon as the purchase knows its store, and the store
    // it chose is what the folded line says.
    expect(find.textContaining('Carrefour'), findsWidgets);
    // And the picker was NOT reloaded — the product field never went blank.
    expect(find.text('Carregando...'), findsNothing);
  });

  group('the [ Comparar custo ] button (H19)', () {
    testWidgets('appears when the type has two options or more', (
      tester,
    ) async {
      await pumpScreen(tester);
      // Before a product is chosen there is no type, and no button.
      expect(find.byKey(const ValueKey('compare-cost')), findsNothing);

      // The crate — the soft drink type has four packagings.
      await fillItem(tester);
      expect(find.byKey(const ValueKey('compare-cost')), findsOneWidget);
    });

    testWidgets('does NOT appear for a type with a single option', (
      tester,
    ) async {
      // The ground beef is the only product of its type in the fake.
      await pumpScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('field-product')),
        'acém',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acém moído (peso)').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('compare-cost')), findsNothing);
    });

    testWidgets('the panel puts the item in "Itens desta compra" and clears '
        'the form', (tester) async {
      final container = await pumpScreen(tester);
      await fillItem(tester);

      await tester.tap(find.byKey(const ValueKey('compare-cost')));
      await tester.pumpAndSettle();

      // The 2 L bottle is the best cost with the seed of §7.5.
      await tester.tap(find.byKey(const ValueKey('cost-check-prod-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-add')));
      await tester.pumpAndSettle();

      final items = container.read(purchaseDraftViewModelProvider).items;
      expect(items, hasLength(1));
      expect(items.first.option.id, 'prod-3');
      expect(items.first.quantity, 1);
      expect(items.first.paid, Money(1000));
      expect(find.text('Itens desta compra'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('purchase-item-${items.first.id}')),
          matching: find.text('Refrigerante Coca-Cola original 2 L'),
        ),
        findsOneWidget,
      );

      String textOf(String key) => tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;
      final product = tester.widget<TextField>(
        find.byKey(const ValueKey('field-product')),
      );
      expect(product.controller!.text, isEmpty);
      expect(textOf('field-quantity'), isEmpty);
      expect(textOf('field-value'), isEmpty);
      expect(product.focusNode!.hasFocus, isTrue);
    });

    testWidgets('an item put by the panel while editing replaces that line', (
      tester,
    ) async {
      final container = await pumpScreen(tester, draft: draftWithItem());

      await tester.tap(
        find.byTooltip('Corrigir Refrigerante Coca-Cola 12 × 350 ml'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compare-cost')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-check-prod-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-add')));
      await tester.pumpAndSettle();

      final items = container.read(purchaseDraftViewModelProvider).items;
      expect(items, hasLength(1));
      expect(items.first.id, 'i1');
      expect(items.first.option.id, 'prod-3');
    });

    testWidgets('Cadastrar in the panel opens screen 4 with the code on the '
        'first card', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(tester, overrides: [camera.override]);
      await fillItem(tester);

      await tester.tap(find.byKey(const ValueKey('compare-cost')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-scan')));
      await tester.pumpAndSettle();
      camera.read('7891000053508');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-register')));
      await tester.pumpAndSettle();

      expect(find.text('Novo produto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('field-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refrigerante').last);
      await tester.pumpAndSettle();

      expect(find.text('• 7891000053508'), findsOneWidget);
    });

    testWidgets('closing with [ X ] writes nothing and changes nothing', (
      tester,
    ) async {
      // The draft is read from the container `pumpScreen` hands back — it
      // overrides the provider with a `PurchaseDraftRepositoryLocal`, and it
      // is the ONLY tree where there is a repository to spy on, because the
      // panel is handed none. A test of the panel claiming "wrote nothing"
      // would claim only what its constructor already reads as.
      final container = await pumpScreen(tester);
      final drafts =
          container.read(purchaseDraftRepositoryProvider)
              as PurchaseDraftRepositoryLocal;
      await fillItem(tester);
      final writesBefore = drafts.writes;

      await tester.tap(find.byKey(const ValueKey('compare-cost')));
      await tester.pumpAndSettle();
      // Typing inside the panel is not writing anywhere.
      await tester.enterText(
        find.byKey(const ValueKey('cost-price-prod-3')),
        '950',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-close')));
      await tester.pumpAndSettle();

      // Neither Hive nor the draft: the panel leaves no trail.
      expect(drafts.writes, writesBefore);
      // And the purchase is exactly as it was.
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('field-value')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'R\$\u{A0}62,00',
      );
    });
  });

  testWidgets('keeps the typing fields above the keyboard on an iPhone 12', (
    tester,
  ) async {
    // Four items already launched: it is the growth of this list that used
    // to push Produto, Quantidade and Valor down.
    var draft = PurchaseDraft(
      purchaseId: 'a1',
      date: DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: 'store-1',
    );
    for (var i = 1; i <= 4; i++) {
      draft = draft.withItem(
        purchaseItem(id: 'i$i', option: crate, cents: 6200),
      );
    }

    expect(draft.items, hasLength(4));

    await pumpScreen(tester, draft: draft);
    // AFTER the pump helper, which forces a tall viewport of its own.
    useIPhone12WithKeyboard(tester);
    await tester.pumpAndSettle();

    // Quantidade is the deepest field of the normal path, and it opens
    // above the keyboard fold. Valor, right below it, is reached by the
    // scroll Flutter itself does when a field takes focus.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('field-quantity'))).dy,
      lessThan(iPhone12KeyboardFold),
      reason: 'field-quantity is under the keyboard',
    );
    // And so is the button the loop of twenty items comes back to. It is
    // what the folded header and the shared line of fields bought.
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('add-item'))).dy,
      lessThan(iPhone12KeyboardFold),
      reason: '[ + Adicionar à compra ] is under the keyboard',
    );
  });

  group('the Data/Mercado header', () {
    testWidgets('opens by itself while the purchase has no store', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byKey(const ValueKey('field-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('field-store')), findsOneWidget);
      expect(find.textContaining('escolha o mercado'), findsOneWidget);
    });

    testWidgets('folds once the store is known, and a tap brings it back', (
      tester,
    ) async {
      await pumpScreen(tester, draft: draftWithItem());

      expect(find.byKey(const ValueKey('field-date')), findsNothing);
      expect(find.byKey(const ValueKey('field-store')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('purchase-header')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('field-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('field-store')), findsOneWidget);
    });
  });

  group('reading a code in Produto', () {
    const crateCode = '7894900011517';
    const unknownCode = '7891000053508';
    const label = '2822521001605';
    const sodaLabel = '2822538001605';

    final crateWithCode = optionByPiece(
      id: 'prod-4',
      brand: cokeBrand,
      pieceCount: 12,
      barcodes: [Barcode.typed(crateCode)].lock,
    );
    ProductOption beefWithLabel({String store = 'store-1'}) => optionByWeight(
      id: 'prod-5',
      scaleCodes: [ScaleCode(storeId: store, itemCode: '2822521')].lock,
    );
    final sodaByWeight = optionByWeight(
      id: 'prod-6',
      type: softDrinkType,
      scaleCodes: [
        const ScaleCode(storeId: 'store-1', itemCode: '2822538'),
      ].lock,
    );
    final withStore = PurchaseDraft(
      purchaseId: 'a1',
      date: DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: 'store-1',
    );

    String fieldText(WidgetTester tester, String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    String productText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('field-product')))
        .controller!
        .text;

    Future<void> scan(
      WidgetTester tester,
      FakeBarcodeCamera camera,
      String raw,
    ) async {
      await tester.tap(find.byKey(const ValueKey('scan-product')));
      await tester.pumpAndSettle();
      camera.read(raw);
      await tester.pumpAndSettle();
    }

    final grams160 = specOf(BaseUnit.gram).format(160);

    testWidgets('a known code picks the packaging and goes to Quantidade', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [crateWithCode].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, crateCode);

      expect(productText(tester), crateWithCode.selectedLabel);
      final quantity = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('field-quantity')),
          matching: find.byType(TextField),
        ),
      );
      expect(quantity.focusNode!.hasFocus, isTrue);
    });

    testWidgets('an unknown code offers to register it', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [crateWithCode].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, unknownCode);
      expect(
        find.text('Nenhum produto com o código 7891000053508.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('unknown-code-register')));
      await tester.pumpAndSettle();
      expect(find.text('Novo produto'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('field-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refrigerante').last);
      await tester.pumpAndSettle();
      expect(find.text('• 7891000053508'), findsOneWidget);
    });

    testWidgets('Fechar on an unknown code changes nothing', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [crateWithCode].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, unknownCode);
      await tester.tap(find.byKey(const ValueKey('unknown-code-close')));
      await tester.pumpAndSettle();

      expect(productText(tester), isEmpty);
      expect(find.text('Lançar compra'), findsOneWidget);
      expect(find.text('Novo produto'), findsNothing);
    });

    testWidgets('a linked label picks the product and fills 0,160 kg', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final beef = beefWithLabel();
      await pumpScreen(
        tester,
        draft: withStore,
        purchases: _SpyPurchases()..options = [beef].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, label);

      expect(productText(tester), beef.selectedLabel);
      expect(fieldText(tester, 'field-quantity'), grams160);
    });

    testWidgets('a label after the price per kilo redoes the total', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      final beef = beefWithLabel();
      await pumpScreen(
        tester,
        draft: withStore,
        purchases: _SpyPurchases()..options = [beef].lock,
        overrides: [camera.override],
      );

      await tester.enterText(
        find.byKey(const ValueKey('field-product')),
        beef.selectedLabel,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(beef.selectedLabel).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('field-unit-price')),
        '3990',
      );
      await tester.pumpAndSettle();

      await scan(tester, camera, label);

      final expected = UnitSpec.currency.format(
        paidAtPricePerLargeUnit(
          pricePerLargeUnit: const Money(3990),
          quantityInBaseUnit: 160,
          unit: BaseUnit.gram,
        )!.cents,
      );
      expect(fieldText(tester, 'field-value'), expected);
      expect(fieldText(tester, 'field-unit-price'), 'R\$\u{A0}39,90');
    });

    testWidgets(
      'with no store a label found in one store picks that store too',
      (tester) async {
        final camera = FakeBarcodeCamera();
        final container = await pumpScreen(
          tester,
          purchases: _SpyPurchases()..options = [beefWithLabel()].lock,
          overrides: [camera.override],
        );

        await scan(tester, camera, label);

        expect(
          container.read(purchaseDraftViewModelProvider).storeId,
          'store-1',
        );
        expect(find.textContaining('Carrefour'), findsWidgets);
      },
    );

    testWidgets('a label in two stores asks which one', (tester) async {
      final camera = FakeBarcodeCamera();
      final other = optionByWeight(
        id: 'prod-7',
        scaleCodes: [
          const ScaleCode(storeId: 'store-2', itemCode: '2822521'),
        ].lock,
      );
      final container = await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [beefWithLabel(), other].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, label);
      expect(
        find.text('Esta etiqueta existe em mais de um mercado. Qual?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('scale-store-store-2')));
      await tester.pumpAndSettle();

      expect(productText(tester), other.selectedLabel);
      expect(container.read(purchaseDraftViewModelProvider).storeId, 'store-2');
      expect(fieldText(tester, 'field-quantity'), grams160);
    });

    testWidgets(
      'an unlinked label asks which product, with the store of the screen',
      (tester) async {
        final camera = FakeBarcodeCamera();
        final catalog = _SpyCatalog();
        final purchases = _SpyPurchases()
          ..options = [crateWithCode, optionByWeight(id: 'prod-5')].lock;
        await pumpScreen(
          tester,
          draft: withStore,
          purchases: purchases,
          catalog: catalog,
          overrides: [camera.override],
        );
        final before = purchases.fetchOptionsCalls;

        await scan(tester, camera, label);

        expect(find.text('Qual produto é este?'), findsOneWidget);
        expect(find.byKey(const ValueKey('scale-link-prod-4')), findsNothing);
        final store = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('scale-link-store')),
        );
        expect(store.onChanged, isNull);
        expect(find.text('Carrefour'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('scale-link-prod-5')));
        await tester.pumpAndSettle();

        expect(catalog.linked, [
          const ScaleCode(storeId: 'store-1', itemCode: '2822521'),
        ]);
        expect(catalog.linkedProducts, ['prod-5']);
        expect(productText(tester), isNotEmpty);
        expect(fieldText(tester, 'field-quantity'), grams160);
        expect(purchases.fetchOptionsCalls, before + 1);
      },
    );

    testWidgets(
      'a link refused by the store still uses the product and says why',
      (tester) async {
        final camera = FakeBarcodeCamera();
        final catalog = _SpyCatalog()
          ..failNextLink = ApiException(409, 'duplicate');
        final purchases = _SpyPurchases()
          ..options = [optionByWeight(id: 'prod-5')].lock;
        await pumpScreen(
          tester,
          draft: withStore,
          purchases: purchases,
          catalog: catalog,
          overrides: [camera.override],
        );
        final before = purchases.fetchOptionsCalls;

        await scan(tester, camera, label);
        await tester.tap(find.byKey(const ValueKey('scale-link-prod-5')));
        await tester.pumpAndSettle();

        expect(find.text(ScaleCode.takenMessage), findsOneWidget);
        expect(productText(tester), isNotEmpty);
        expect(fieldText(tester, 'field-quantity'), grams160);
        expect(purchases.fetchOptionsCalls, before);
      },
    );

    testWidgets('a strange label says so and writes nothing', (tester) async {
      final camera = FakeBarcodeCamera();
      final catalog = _SpyCatalog();
      final container = await pumpScreen(
        tester,
        draft: withStore,
        purchases: _SpyPurchases()..options = [beefWithLabel()].lock,
        catalog: catalog,
        overrides: [camera.override],
      );
      final draftBefore = container.read(purchaseDraftViewModelProvider);

      await scan(tester, camera, '212345678909');

      expect(
        find.text('Não conheço esta etiqueta. Escolha o produto pela lista.'),
        findsOneWidget,
      );
      expect(productText(tester), isEmpty);
      expect(catalog.linked, isEmpty);
      expect(container.read(purchaseDraftViewModelProvider), draftBefore);
    });

    testWidgets('garbage says the code is invalid', (tester) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [crateWithCode].lock,
        overrides: [camera.override],
      );

      await scan(tester, camera, '7894900011518');

      expect(find.text('Código de barras inválido.'), findsOneWidget);
    });

    testWidgets(
      'a label of a type not in grams leaves Quantidade empty with no '
      'sentence',
      (tester) async {
        final camera = FakeBarcodeCamera();
        await pumpScreen(
          tester,
          draft: withStore,
          purchases: _SpyPurchases()..options = [sodaByWeight].lock,
          overrides: [camera.override],
        );

        await scan(tester, camera, sodaLabel);

        expect(productText(tester), sodaByWeight.selectedLabel);
        expect(fieldText(tester, 'field-quantity'), isEmpty);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('the reader closed with nothing changes nothing', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..options = [crateWithCode].lock,
        overrides: [camera.override],
      );

      await tester.tap(find.byKey(const ValueKey('scan-product')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-close')));
      await tester.pumpAndSettle();

      expect(productText(tester), isEmpty);
      expect(fieldText(tester, 'field-quantity'), isEmpty);
      expect(find.text('Lançar compra'), findsOneWidget);
    });

    testWidgets('the scan button waits for the products', (tester) async {
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..failNextCall = ApiException(503, 'down'),
      );

      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('scan-product')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('checkout', () {
    const crateCode = '7894900011517';
    const unknownCode = '7891000053508';

    final crateWithCode = optionByPiece(
      id: 'prod-4',
      brand: cokeBrand,
      pieceCount: 12,
      barcodes: [Barcode.typed(crateCode)].lock,
      priceReference: reference(cents: 6200, quantityInBaseUnit: 4200),
    );
    final withStore = PurchaseDraft(
      purchaseId: 'a1',
      date: DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: 'store-1',
    );

    testWidgets(
      'Passar no caixa opens the checkout and Concluir shows the items on screen 3',
      (tester) async {
        final camera = FakeBarcodeCamera();
        final beep = SpyBeep();
        await pumpScreen(
          tester,
          draft: withStore,
          purchases: _SpyPurchases()..options = [crateWithCode].lock,
          overrides: [camera.override, beep.override],
        );

        await tester.tap(find.byKey(const ValueKey('checkout-open')));
        await tester.pumpAndSettle();
        expect(find.text('Caixa'), findsOneWidget);
        expect(beep.unlocks, 1);

        camera.read(crateCode);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-done')));
        await tester.pumpAndSettle();

        expect(find.text('Itens desta compra'), findsOneWidget);
        expect(
          find.byTooltip('Corrigir ${crateWithCode.selectedLabel}'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the checkout button waits for the products', (tester) async {
      await pumpScreen(
        tester,
        purchases: _SpyPurchases()..failNextCall = ApiException(503, 'down'),
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('checkout-open')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('opening the checkout drops a correction in progress', (
      tester,
    ) async {
      final camera = FakeBarcodeCamera();
      await pumpScreen(
        tester,
        draft: draftWithItem(),
        overrides: [camera.override, SpyBeep().override],
      );

      await tester.tap(
        find.byTooltip('Corrigir Refrigerante Coca-Cola 12 × 350 ml'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Salvar alteração'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('checkout-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-done')));
      await tester.pumpAndSettle();

      expect(find.text('Salvar alteração'), findsNothing);
      expect(find.text('+ Adicionar à compra'), findsOneWidget);
    });

    testWidgets(
      'a product registered in the checkout shows once in the picker',
      (tester) async {
        final camera = FakeBarcodeCamera();
        await pumpScreen(
          tester,
          draft: withStore,
          purchases: _SpyPurchases()..options = [crateWithCode].lock,
          overrides: [camera.override, SpyBeep().override],
        );

        await tester.tap(find.byKey(const ValueKey('checkout-open')));
        await tester.pumpAndSettle();
        camera.read(unknownCode);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('checkout-unknown-register')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Novo produto'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('field-type')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Refrigerante').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('field-description')),
          'limão',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('size-1')), '600');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('save')));
        await tester.pumpAndSettle();

        // Back in the checkout: the new leaf waits for its price.
        expect(find.byKey(const ValueKey('checkout-price-0')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('checkout-done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-exit-anyway')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('field-product')),
          'limão',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('limão'), findsNWidgets(2));
      },
    );
  });
}

/// A catalog with nothing in it — the first opening of the app.
class _EmptyCatalog extends PurchaseRepositoryLocal {
  _EmptyCatalog() : super(history: const [], latency: Duration.zero);

  @override
  Future<IList<ProductOption>> fetchProductOptions() async =>
      const IList.empty();
}

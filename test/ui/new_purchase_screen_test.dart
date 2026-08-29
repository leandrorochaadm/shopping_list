import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/online_status.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/purchase/widgets/purchase_item_row.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';

class _SpyPurchases extends PurchaseRepositoryLocal {
  _SpyPurchases() : super(latency: Duration.zero);

  Object? failNextCall;
  Object? failNextSave;
  int saveCalls = 0;

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchProductOptions();
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

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    PurchaseRepository? purchases,
    StoreRepository? stores,
    PurchaseDraft? draft,
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
        catalogOverride(),
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
    await tester.enterText(find.byKey(const ValueKey('field-product')), product);
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
    expect(find.text('Coca-Cola 12 × 350 ml'), findsOneWidget);
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

  testWidgets('searching finds by stretch, case and accent alike', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final query in ['coca', 'COCA', 'cocá']) {
      await tester.enterText(
        find.byKey(const ValueKey('field-product')),
        query,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Coca-Cola original 12 × 350 ml'),
        findsOneWidget,
        reason: query,
      );
      // Grouped by type, with the type's name as the header.
      expect(find.text('Refrigerante'), findsWidgets, reason: query);
    }

    // And by the packaging, which is how a shelf is actually searched.
    await tester.enterText(find.byKey(const ValueKey('field-product')), '269');
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola original 269 ml'), findsOneWidget);
  });

  testWidgets('the value comes pre-filled from the last purchase', (
    tester,
  ) async {
    // The fake bought the crate for R$ 62,00; one crate again is exactly
    // R$ 62,00 — not R$ 62,04, which a rounded price per litre would give.
    await pumpScreen(tester);
    await fillItem(tester);

    final value = tester.widget<TextField>(
      find.byKey(const ValueKey('field-value')),
    );
    expect(value.controller!.text, '62,00');
  });

  testWidgets('a value typed by hand stops being recomputed', (tester) async {
    await pumpScreen(tester);
    await fillItem(tester);

    await tester.enterText(find.byKey(const ValueKey('field-value')), '55,00');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-quantity')), '2');
    await tester.pumpAndSettle();

    final value = tester.widget<TextField>(
      find.byKey(const ValueKey('field-value')),
    );
    expect(value.controller!.text, '55,00');
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
      find.byKey(const ValueKey('field-quantity')),
    );
    expect(quantity.controller!.text, isEmpty);
  });

  testWidgets('[ed] reopens the line and corrects it instead of adding one', (
    tester,
  ) async {
    await pumpScreen(tester, draft: draftWithItem());

    await tester.tap(find.byTooltip('Corrigir Coca-Cola 12 × 350 ml'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar alteração'), findsOneWidget);
    final value = tester.widget<TextField>(
      find.byKey(const ValueKey('field-value')),
    );
    expect(value.controller!.text, '62,00');

    await tester.enterText(find.byKey(const ValueKey('field-value')), '59,00');
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseItemRow), findsOneWidget, reason: 'not two');
    expect(find.text(r'R$ 59,00'), findsWidgets);
  });

  testWidgets('[Remover] takes the line out and redoes the total', (
    tester,
  ) async {
    await pumpScreen(tester, draft: draftWithItem());

    await tester.tap(find.byTooltip('Remover Coca-Cola 12 × 350 ml'));
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

  testWidgets('[Descartar] throws the recovered purchase away', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('unit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
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
      find.byKey(const ValueKey('field-quantity')),
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

    expect(find.text('Carrefour'), findsWidgets);
    // And the picker was NOT reloaded — the product field never went blank.
    expect(find.text('Carregando...'), findsNothing);
  });
}

/// A catalog with nothing in it — the first opening of the app.
class _EmptyCatalog extends PurchaseRepositoryLocal {
  _EmptyCatalog() : super(history: const [], latency: Duration.zero);

  @override
  Future<IList<ProductOption>> fetchProductOptions() async =>
      const IList.empty();
}

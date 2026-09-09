import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/shopping_list.dart';

/// The fake with a switch that makes the next call fail, and one that HOLDS
/// the write — the double tap can only be seen while the first one is still
/// in the air.
class _SpyRepository extends PurchaseRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int correctCalls = 0;
  int deleteCalls = 0;

  /// Completed by the test. While it is unresolved, `correct` has not
  /// returned — which is the only window in which a second tap exists.
  Completer<void>? hold;

  @override
  Future<void> correct({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    correctCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    if (hold != null) await hold!.future;
    return super.correct(
      purchase: purchase,
      writeOffs: writeOffs,
      restored: restored,
      capAlerts: capAlerts,
    );
  }

  @override
  Future<void> delete({
    required String purchaseId,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    deleteCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.delete(
      purchaseId: purchaseId,
      restored: restored,
      capAlerts: capAlerts,
    );
  }
}

void main() {
  // The screen draws a date and an amount, and `main()` does not run in a
  // test.
  setUpAll(initializePtBr);

  late _SpyRepository purchases;

  setUp(() => purchases = _SpyRepository());

  /// Opens the correction the way the history does — with a `push`, so the
  /// screen has somewhere to pop back to.
  Future<ProviderContainer> pumpEdit(
    WidgetTester tester, {
    String purchaseId = 'purchase-1',
    SpendingCapRepository? caps,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(purchases: purchases, caps: caps),
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
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider)
      ..go(Routes.purchaseHistory);
    await tester.pumpAndSettle();
    router.push('/purchases/$purchaseId/edit');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('opens with the purchase already filled in', (tester) async {
    await pumpEdit(tester);

    expect(find.text('28/08/2026'), findsOneWidget);
    expect(find.text('Carrefour'), findsWidgets);
    expect(find.text('Refrigerante Coca-Cola original 12 × 350 ml'), findsOneWidget);
    expect(find.text('R\$ 62,00'), findsWidgets);
  });

  testWidgets('a failed load occupies the screen, without the exception', (
    tester,
  ) async {
    await pumpEdit(tester, purchaseId: 'nope');

    expect(find.byKey(const ValueKey('retry-purchase')), findsOneWidget);
    expect(find.textContaining('ArgumentError'), findsNothing);
  });

  testWidgets('saving the correction writes once and goes back', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byKey(const ValueKey('save-correction')));
    await tester.pumpAndSettle();

    expect(purchases.correctCalls, 1);
    expect(find.text('Correção salva.'), findsOneWidget);
    // Back to the history, which is what the `push` of the line promised.
    expect(find.text('Histórico de compras'), findsOneWidget);
  });

  testWidgets('a correction that crosses a cut shows the cap warning', (
    tester,
  ) async {
    // The purchase of the fake is of 28/08/2026, and this correction does not
    // change its amount — so what the re-evaluation finds is the month as it
    // stands: R$ 1.250 over a R$ 1.500 cap, past the R$ 1.200 cut, with
    // neither mark set. That is the state a cap raised and then lowered again
    // leaves behind, and it is exactly what has to warn.
    await pumpEdit(
      tester,
      caps: SpendingCapRepositoryLocal(
        latency: Duration.zero,
        today: DateTime(2026, 8, 28),
        cap: SpendingCap(
          amount: const Money(150000),
          effectiveFrom: DateTime(2026, 8, 1),
        ),
        spending: {DateTime(2026, 8, 1): const Money(125000)},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('save-correction')));
    await tester.pumpAndSettle();

    expect(find.text('O gasto do mês passou de 80% do teto.'), findsOneWidget);
    // …and there is NO repeat warning here: `handoff §H14` puts that on
    // screen 3 and nowhere else.
    expect(find.textContaining('Vocês dois compraram'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('acknowledge-warnings')));
    await tester.pumpAndSettle();

    expect(find.text('Histórico de compras'), findsOneWidget);
  });

  testWidgets('a double tap on [ Salvar correção ] writes once and leaves once',
      (tester) async {
    // The one place where the `null` of the reentrancy guard being read as
    // success shows up: success POPS. Remove the `_saving` of the screen and
    // this test has to fail.
    purchases.hold = Completer<void>();
    await pumpEdit(tester);

    await tester.tap(find.byKey(const ValueKey('save-correction')));
    await tester.pump();
    // Still in flight: the button is disabled and says so.
    expect(find.text('Salvando...'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('save-correction')),
      warnIfMissed: false,
    );
    await tester.pump();

    purchases.hold!.complete();
    await tester.pumpAndSettle();

    expect(purchases.correctCalls, 1);
    expect(find.text('Histórico de compras'), findsOneWidget);
  });

  testWidgets('a failed save keeps the screen and says why', (tester) async {
    await pumpEdit(tester);
    purchases.failNextCall = ApiException(500, 'boom');

    await tester.tap(find.byKey(const ValueKey('save-correction')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    // Rule 10: the raw exception never reaches the screen.
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.text('Corrigir compra'), findsOneWidget);
  });

  testWidgets('a correction that empties the purchase is refused', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byTooltip('Remover Refrigerante Coca-Cola original 12 × 350 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-correction')));
    await tester.pumpAndSettle();

    expect(find.text('Acrescente ao menos um item à compra.'), findsOneWidget);
    expect(purchases.correctCalls, 0);
    // Whoever wants a purchase with no items wants to delete it, and the
    // button for that is right below.
    expect(find.byKey(const ValueKey('delete-purchase')), findsOneWidget);
  });

  testWidgets('apagar asks first, and says what happens to the list', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byKey(const ValueKey('delete-purchase')));
    await tester.pumpAndSettle();

    expect(find.text('Apagar esta compra?'), findsOneWidget);
    expect(
      find.text('Os itens que esta compra tirou da lista voltam para ela.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(purchases.deleteCalls, 0);
  });

  testWidgets('confirming the deletion gives the list its item back', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byKey(const ValueKey('delete-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();

    expect(purchases.deleteCalls, 1);
    expect(find.text('Compra apagada.'), findsOneWidget);
    expect(find.text('Histórico de compras'), findsOneWidget);
    // `item-3` was closed by this purchase AND had its "não encontrei"
    // knocked down: undoing puts both back.
    final restored = purchases.restoredByCorrection.single;
    expect(restored.id, 'item-3');
    expect(restored.fulfilledOn, isNull);
    expect(restored.notFound, isTrue);
  });

  testWidgets('the item dialog corrects the line and redoes the total', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byTooltip('Corrigir Refrigerante Coca-Cola original 12 × 350 ml'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-value')), '38,00');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();

    expect(find.text('R\$ 38,00'), findsWidgets);
    expect(find.text('R\$ 62,00'), findsNothing);
  });

  testWidgets('the item dialog removes the line from the purchase', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.byTooltip('Corrigir Refrigerante Coca-Cola original 12 × 350 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await tester.pumpAndSettle();

    expect(find.text('Refrigerante Coca-Cola original 12 × 350 ml'), findsNothing);
  });

  testWidgets('an amount typed wrong stays in the dialog', (tester) async {
    await pumpEdit(tester);

    await tester.tap(find.byTooltip('Corrigir Refrigerante Coca-Cola original 12 × 350 ml'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-value')), '');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();

    // Still open, with the message under the field.
    expect(find.byKey(const ValueKey('save-item')), findsOneWidget);
  });

  testWidgets('the store field keeps a store that was deactivated', (
    tester,
  ) async {
    // Screen 3 offers only active stores, and rightly. A correction that
    // dropped the purchase's own store would blank the field and make
    // "corrigir só o valor pago" impossible.
    await pumpEdit(tester);

    expect(find.text('Carrefour'), findsWidgets);
  });

  testWidgets('the calendar cannot reach a day after today', (tester) async {
    await pumpEdit(tester);

    await tester.tap(find.byKey(const ValueKey('field-date')));
    await tester.pumpAndSettle();

    // Blocking it at the source beats a message afterwards — and
    // `Purchase.checkDate` is still the rule, because a screen may never be
    // the only guard.
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final today = DateTime.now();
    expect(picker.lastDate, DateTime(today.year, today.month, today.day));
    // And the old purchase's own day is still reachable: `firstDate` counts
    // back from the purchase, not from today.
    expect(picker.firstDate.year, lessThanOrEqualTo(2024));
  });
}

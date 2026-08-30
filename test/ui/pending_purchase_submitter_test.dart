import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/online_status.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/ui/purchase/view_model/pending_purchase_submitter.dart';

import '../helpers/device_user.dart';
import '../helpers/purchase.dart';
import '../helpers/spending_cap.dart';

class _SpyPurchases extends PurchaseRepositoryLocal {
  _SpyPurchases() : super(latency: Duration.zero);

  Object? failNextSave;
  int saveCalls = 0;
  int optionCalls = 0;

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    optionCalls++;
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

/// Waits for the attempt to finish instead of sleeping a fixed amount.
///
/// The chain is several turns of the event loop long — the draft, the list,
/// the write, the clear — and a fixed delay that is generous on one machine
/// is a flake on another.
Future<void> settle(ProviderContainer container) async {
  for (var round = 0; round < 400; round++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (container.read(pendingPurchaseSubmitterProvider) !=
        PendingSubmission.sending) {
      return;
    }
  }
}

/// A listener, not a `read`: without one the provider is disposed before its
/// own microtask runs. In the app the listener is `ShoppingListApp`, which
/// holds it for as long as the app is up.
void keepAlive(ProviderContainer container) =>
    container.listen(pendingPurchaseSubmitterProvider, (_, _) {});

void main() {
  final crate = optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12);

  PurchaseDraft pending({bool marked = true}) {
    final draft = PurchaseDraft(
      purchaseId: 'a1',
      date: DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: 'store-1',
    ).withItem(purchaseItem(id: 'i1', option: crate, cents: 6200));
    return marked ? draft.markedPending() : draft;
  }

  ProviderContainer containerWith({
    _SpyPurchases? purchases,
    PurchaseDraft? draft,
    bool online = true,
    PurchaseDraftRepositoryLocal? drafts,
    SpendingCapRepository? caps,
  }) => ProviderContainer.test(
    overrides: [
      deviceUserOverride(),
      spendingCapOverride(repository: caps),
      purchaseRepositoryProvider.overrideWith(
        (ref) => purchases ?? _SpyPurchases(),
      ),
      purchaseDraftRepositoryProvider.overrideWith(
        (ref) => drafts ?? PurchaseDraftRepositoryLocal(initial: draft),
      ),
      shoppingListRepositoryProvider.overrideWith(
        (ref) => ShoppingListRepositoryLocal(latency: Duration.zero),
      ),
      if (!online) onlineStatusProvider.overrideWith(_Offline.new),
    ],
  );

  test('sends the pending purchase on the opening of the app', () async {
    // "na abertura seguinte" — the criterion, and the reason this lives
    // outside screen 3: on that opening the screen showing is `/`.
    final purchases = _SpyPurchases();
    final drafts = PurchaseDraftRepositoryLocal(initial: pending());
    final container = containerWith(purchases: purchases, drafts: drafts);

    keepAlive(container);
    await settle(container);

    expect(purchases.saveCalls, 1);
    expect(purchases.saved.single.purchase.id, 'a1');
    expect(
      container.read(pendingPurchaseSubmitterProvider),
      PendingSubmission.sent,
    );
    // The draft is gone, which is what stops it being sent a third time.
    expect(drafts.readNow(), isNull);
  });

  test('the automatic resend WRITES the cap mark and shows no dialog', () async {
    // Decision D-g: there is no screen open to receive a dialog, so the marks
    // are written and nothing is shown. Whoever wants to know where the month
    // stands reads the "Gastou X de Y" of the report, which is what
    // requirement 9 asks for.
    final purchases = _SpyPurchases();
    final drafts = PurchaseDraftRepositoryLocal(initial: pending());
    final container = containerWith(
      purchases: purchases,
      drafts: drafts,
      // R$ 1.150 + the R$ 62 of the pending purchase crosses the 80% cut of a
      // R$ 1.500 cap.
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

    keepAlive(container);
    await settle(container);

    // The mark went up, in the same submission as the purchase…
    expect(purchases.capAlertsWritten.single.warned80, isTrue);
    expect(purchases.capAlertsWritten.single.month, DateTime(2026, 8, 1));
    // …and the state is simply `sent`: this notifier has no way to show
    // anything, and that is the decision, not a limitation discovered late.
    expect(
      container.read(pendingPurchaseSubmitterProvider),
      PendingSubmission.sent,
    );
  });

  test('does not touch the catalog when nothing is pending', () async {
    // The order of the exits matters: reading the purchase ViewModel fires
    // the two catalog queries, and EVERY opening of the app would pay for
    // them with nothing to send.
    final purchases = _SpyPurchases();
    final container = containerWith(purchases: purchases);

    keepAlive(container);
    await settle(container);

    expect(purchases.saveCalls, 0);
    expect(purchases.optionCalls, 0, reason: 'no catalog query at all');
    expect(
      container.read(pendingPurchaseSubmitterProvider),
      PendingSubmission.idle,
    );
  });

  test('a draft that was never marked pending is left alone', () async {
    // Someone typing a purchase and closing the app has NOT asked for it to
    // be sent.
    final purchases = _SpyPurchases();
    final container = containerWith(
      purchases: purchases,
      draft: pending(marked: false),
    );

    keepAlive(container);
    await settle(container);

    expect(purchases.saveCalls, 0);
  });

  test('with no signal it does not even try', () async {
    final purchases = _SpyPurchases();
    final container = containerWith(
      purchases: purchases,
      draft: pending(),
      online: false,
    );

    keepAlive(container);
    await settle(container);

    expect(purchases.saveCalls, 0);
    expect(
      container.read(pendingPurchaseSubmitterProvider),
      PendingSubmission.idle,
    );
  });

  test('a failed attempt stays quiet and keeps the purchase', () async {
    // It will be tried again on the next opening; a message about a purchase
    // nobody is looking at is noise.
    final purchases = _SpyPurchases()..failNextSave = ApiException(500, 'boom');
    final drafts = PurchaseDraftRepositoryLocal(initial: pending());
    final container = containerWith(purchases: purchases, drafts: drafts);

    keepAlive(container);
    await settle(container);

    expect(purchases.saveCalls, 1);
    expect(
      container.read(pendingPurchaseSubmitterProvider),
      PendingSubmission.idle,
    );
    // And the purchase is still on the phone.
    expect(drafts.readNow(), isNotNull);
    expect(drafts.readNow()!.pendingSubmission, isTrue);
  });

  test('the connection coming back is the second trigger', () async {
    // With the app OPEN. Nothing happens with it closed — WebKit has no
    // Background Sync, and the offline banner promises no more than that.
    final purchases = _SpyPurchases();
    final container = ProviderContainer.test(
      overrides: [
        deviceUserOverride(),
        spendingCapOverride(),
        purchaseRepositoryProvider.overrideWith((ref) => purchases),
        purchaseDraftRepositoryProvider.overrideWith(
          (ref) => PurchaseDraftRepositoryLocal(initial: pending()),
        ),
        shoppingListRepositoryProvider.overrideWith(
          (ref) => ShoppingListRepositoryLocal(latency: Duration.zero),
        ),
        onlineStatusProvider.overrideWith(_Reconnecting.new),
      ],
    );

    keepAlive(container);
    await settle(container);
    expect(purchases.saveCalls, 0, reason: 'still offline');

    (container.read(onlineStatusProvider.notifier) as _Reconnecting)
        .comeBack();
    await settle(container);

    expect(purchases.saveCalls, 1);
  });
}

/// Offline, then online — the only way to exercise the reconnection in the
/// Dart VM, where there is no navigator to ask.
class _Reconnecting extends OnlineStatus {
  @override
  bool build() => false;

  void comeBack() => state = true;
}

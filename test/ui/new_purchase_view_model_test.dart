import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/core/online_status.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_increase.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/same_day_alert.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/ui/purchase/view_model/new_purchase_view_model.dart';

import '../helpers/device_user.dart';
import '../helpers/purchase.dart';
import '../helpers/spending_cap.dart';

/// The fake with a switch that makes the next call fail — the two error paths
/// without mocktail, which is how the rest of this project does it.
class _SpyPurchases extends PurchaseRepositoryLocal {
  _SpyPurchases({super.sameDayBuyer}) : super(latency: Duration.zero);

  /// Two switches and not one: reading the notifier triggers `build()`,
  /// which calls `fetchProductOptions` — a single switch would be eaten
  /// there and never reach the save under test.
  Object? failNextCall;
  Object? failNextSave;
  int saveCalls = 0;

  /// How many times H14's query was made — zero is the assertion that a
  /// purchase outside the window is not even asked about.
  int sameDayCalls = 0;

  @override
  Future<IList<SameDayAlert>> fetchSameDayTypes({
    required DateTime date,
    required String registeredBy,
    required ISet<String> productTypeIds,
  }) {
    sameDayCalls++;
    return super.fetchSameDayTypes(
      date: date,
      registeredBy: registeredBy,
      productTypeIds: productTypeIds,
    );
  }

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
  final today = DateTime(2026, 8, 28);
  final crate = optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12);

  ProviderContainer containerWith({
    _SpyPurchases? purchases,
    ShoppingListRepository? list,
    PurchaseDraftRepository? drafts,
    SpendingCapRepository? caps,
    bool online = true,
  }) => ProviderContainer.test(
    overrides: [
      deviceUserOverride(),
      spendingCapOverride(repository: caps),
      purchaseRepositoryProvider.overrideWith(
        (ref) => purchases ?? _SpyPurchases(),
      ),
      shoppingListRepositoryProvider.overrideWith(
        (ref) =>
            list ?? ShoppingListRepositoryLocal(latency: Duration.zero),
      ),
      purchaseDraftRepositoryProvider.overrideWith(
        (ref) => drafts ?? PurchaseDraftRepositoryLocal(),
      ),
      if (!online) onlineStatusProvider.overrideWith(_Offline.new),
    ],
  );

  PurchaseDraft draft({
    String? storeId = 'store-1',
    bool withItem = true,
    DateTime? date,
  }) {
    var value = PurchaseDraft(
      purchaseId: 'a1',
      date: date ?? DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: storeId,
    );
    if (withItem) {
      value = value.withItem(
        purchaseItem(id: 'i1', option: crate, cents: 6200),
      );
    }
    return value;
  }

  group('rankOptions', () {
    test('orders by how often each leaf was bought', () {
      final options = [
        optionByPiece(id: 'prod-1'),
        optionByPiece(id: 'prod-4', pieceCount: 12),
      ].lock;
      final history = [
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(6200),
          purchasedOn: DateTime(2026, 8, 18),
        ),
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(5990),
          purchasedOn: DateTime(2026, 7, 30),
        ),
      ].lock;

      final ranked = rankOptions(options, history);

      expect(ranked.first.id, 'prod-4');
      expect(ranked.first.purchaseCount, 2);
      expect(ranked.last.purchaseCount, 0);
    });

    test('the reference is the MOST RECENT purchase, whatever the order', () {
      // The query that brought these has no `order`: ordering an embedded
      // table in PostgREST orders the children, not the parents.
      final history = [
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(5990),
          purchasedOn: DateTime(2026, 7, 30),
        ),
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(6200),
          purchasedOn: DateTime(2026, 8, 18),
        ),
      ].lock;

      final ranked = rankOptions(
        [optionByPiece(id: 'prod-4', pieceCount: 12)].lock,
        history,
      );

      expect(ranked.single.priceReference!.paid, const Money(6200));
      expect(ranked.single.lastPurchasedOn, DateTime(2026, 8, 18));
    });

    test('a leaf never bought has no reference — the empty comparison', () {
      final ranked = rankOptions(
        [optionByPiece(id: 'prod-1')].lock,
        const IList.empty(),
      );

      expect(ranked.single.priceReference, isNull);
      expect(ranked.single.purchaseCount, 0);
    });

    test('attaches the LEAF average to a leaf that HAS a brand (H15)', () {
      // Two crates: R$ 62,00 and R$ 59,90 for 4200 ml each — one weighted
      // average of R$ 14,51 a litre, and NOT the average of two averages.
      final history = [
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(6200),
          purchasedOn: DateTime(2026, 8, 18),
        ),
        PurchaseHistoryEntry(
          productId: 'prod-4',
          productTypeId: 'type-1',
          quantityInBaseUnit: 4200,
          paid: const Money(5990),
          purchasedOn: DateTime(2026, 7, 30),
        ),
        // Another leaf of the same type, which must NOT reach the branded
        // one: with a brand, the comparison is against itself.
        PurchaseHistoryEntry(
          productId: 'prod-1',
          productTypeId: 'type-1',
          quantityInBaseUnit: 350,
          paid: const Money(900),
          purchasedOn: DateTime(2026, 8, 20),
        ),
      ].lock;

      final ranked = rankOptions(
        [
          optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12),
        ].lock,
        history,
      );

      expect(
        ranked.single.baseline,
        PriceBaseline(paid: const Money(12190), quantityInBaseUnit: 8400),
      );
    });

    test('attaches the TYPE average to a leaf with no brand (H15)', () {
      // Ground beef has nobody to compare itself with, so the comparison
      // climbs to the type — which is where the leaf of another package of
      // the same type joins in.
      final history = [
        PurchaseHistoryEntry(
          productId: 'prod-5',
          productTypeId: 'type-2',
          quantityInBaseUnit: 1500,
          paid: const Money(4500),
          purchasedOn: DateTime(2026, 8, 10),
        ),
        PurchaseHistoryEntry(
          productId: 'prod-6',
          productTypeId: 'type-2',
          quantityInBaseUnit: 2000,
          paid: const Money(6800),
          purchasedOn: DateTime(2026, 8, 5),
        ),
      ].lock;

      final ranked = rankOptions([optionByWeight(id: 'prod-5')].lock, history);

      expect(
        ranked.single.baseline,
        PriceBaseline(paid: const Money(11300), quantityInBaseUnit: 3500),
      );
    });

    test('a window with no purchase of it leaves the baseline null', () {
      // The silence of the requirement: never a comparison against a similar
      // product.
      final ranked = rankOptions(
        [optionByPiece(id: 'prod-1', brand: cokeBrand)].lock,
        [
          PurchaseHistoryEntry(
            productId: 'prod-4',
            productTypeId: 'type-1',
            quantityInBaseUnit: 4200,
            paid: const Money(6200),
            purchasedOn: DateTime(2026, 8, 18),
          ),
        ].lock,
      );

      expect(ranked.single.baseline, isNull);
    });
  });

  group('build', () {
    test('brings the picker ranked, in one pass', () async {
      final container = containerWith();

      final options = await container.read(
        newPurchaseViewModelProvider.future,
      );

      expect(options, isNotEmpty);
      // The fake's seed bought the crate twice.
      expect(options.first.id, 'prod-4');
      expect(options.first.priceReference!.paid, const Money(6200));
    });

    test('a failed load occupies the field, not a spinner forever', () async {
      final container = containerWith(
        purchases: _SpyPurchases()..failNextCall = NetworkException('offline'),
      );

      await expectLater(
        container.read(newPurchaseViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(newPurchaseViewModelProvider).hasError, isTrue);
    });

    test('refresh that works puts the picker back', () async {
      final purchases = _SpyPurchases()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(purchases: purchases);
      await expectLater(
        container.read(newPurchaseViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );

      final error = await container
          .read(newPurchaseViewModelProvider.notifier)
          .refresh();

      expect(error, isNull);
      expect(container.read(newPurchaseViewModelProvider).value, isNotEmpty);
    });

    test('a failed refresh with data on screen keeps the data', () async {
      final purchases = _SpyPurchases();
      final container = containerWith(purchases: purchases);
      await container.read(newPurchaseViewModelProvider.future);

      purchases.failNextCall = NetworkException('offline');
      final error = await container
          .read(newPurchaseViewModelProvider.notifier)
          .refresh();

      expect(error, 'Sem conexão. Verifique a internet e tente de novo.');
      expect(container.read(newPurchaseViewModelProvider).value, isNotEmpty);
      expect(container.read(newPurchaseViewModelProvider).hasError, isFalse);
    });

    test('a failed refresh with NOTHING on screen becomes an error', () async {
      final purchases = _SpyPurchases()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(purchases: purchases);
      await expectLater(
        container.read(newPurchaseViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );

      purchases.failNextCall = NetworkException('still offline');
      await container.read(newPurchaseViewModelProvider.notifier).refresh();

      // Leaving it in AsyncLoading would be a spinner that never resolves.
      expect(container.read(newPurchaseViewModelProvider).hasError, isTrue);
    });
  });

  group('save', () {
    test('registers the purchase and kills the draft', () async {
      final purchases = _SpyPurchases();
      final drafts = PurchaseDraftRepositoryLocal(initial: draft());
      final container = containerWith(purchases: purchases, drafts: drafts);

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<PurchaseSaved>());
      expect(purchases.saveCalls, 1);
      expect(purchases.saved.single.purchase.id, 'a1');
      // The one guard against registering the same purchase twice.
      expect(drafts.readNow(), isNull);
    });

    test('writes the list off in the same submission', () async {
      // The crate is 4200 ml of "Refrigerante", and the fake list asks for
      // 4200 ml of it — so the line closes. The purchase is dated the day
      // that line entered, which is the boundary of decision 25.
      final purchases = _SpyPurchases();
      final container = containerWith(purchases: purchases);

      await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: DateTime(2026, 8, 28)), today: today);

      final writeOffs = purchases.saved.single.writeOffs;
      expect(writeOffs, isNotEmpty);
      final closed = writeOffs.firstWhere(
        (off) => off.shoppingListItemId == 'item-3',
      );
      expect(closed.quantityWrittenOff, 4200);
      expect(closed.fulfills, isTrue);
      // The line that entered AFTER the purchase date is untouched
      // (decision 25).
      expect(
        writeOffs.map((off) => off.shoppingListItemId),
        isNot(contains('item-5')),
      );
    });

    test('refuses a future date, with the domain sentence', () async {
      final container = containerWith();

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: DateTime(2026, 8, 29)), today: today);

      expect(
        outcome,
        isA<SaveFailed>().having(
          (o) => o.message,
          'message',
          'A compra não pode ter data futura.',
        ),
      );
    });

    test('refuses a purchase with no store and one with no item', () async {
      final container = containerWith();
      final notifier = container.read(newPurchaseViewModelProvider.notifier);

      expect(
        await notifier.save(draft: draft(storeId: null), today: today),
        isA<SaveFailed>().having(
          (o) => o.message,
          'message',
          'Escolha o mercado desta compra.',
        ),
      );
      expect(
        await notifier.save(draft: draft(withItem: false), today: today),
        isA<SaveFailed>().having(
          (o) => o.message,
          'message',
          'Acrescente ao menos um item à compra.',
        ),
      );
    });

    test('with no signal it keeps the purchase instead of trying', () async {
      final purchases = _SpyPurchases();
      final drafts = PurchaseDraftRepositoryLocal(initial: draft());
      final container = containerWith(
        purchases: purchases,
        drafts: drafts,
        online: false,
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<PurchaseHeldOffline>());
      expect(purchases.saveCalls, 0, reason: 'no attempt at all');
      expect(drafts.readNow()!.pendingSubmission, isTrue);
      // And the purchase is still there, key included.
      expect(drafts.readNow()!.purchaseId, 'a1');
    });

    test('a transport failure while "online" also becomes pending', () async {
      // A hotel Wi-Fi or a captive portal: the browser says online and the
      // request never lands. Without this, "nada se perde" would depend on
      // the browser having noticed the drop.
      final purchases = _SpyPurchases()
        ..failNextSave = NetworkException('captive portal');
      final drafts = PurchaseDraftRepositoryLocal(initial: draft());
      final container = containerWith(purchases: purchases, drafts: drafts);

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<PurchaseHeldOffline>());
      expect(drafts.readNow()!.pendingSubmission, isTrue);
    });

    test('another failure answers a sentence and keeps the purchase', () async {
      final purchases = _SpyPurchases()
        ..failNextSave = ApiException(500, 'boom');
      final drafts = PurchaseDraftRepositoryLocal(initial: draft());
      final container = containerWith(purchases: purchases, drafts: drafts);

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<SaveFailed>());
      final message = (outcome! as SaveFailed).message;
      // The sentence, never the raw exception.
      expect(message, isNot(contains('ApiException')));
      expect(message, isNot(contains('boom')));
      // And the purchase is still on the phone.
      expect(drafts.readNow(), isNotNull);
    });

    test('a resend that arrives twice does not become a second purchase',
        () async {
      // The `on conflict (id) do nothing` of `create_purchase`, seen from
      // here: the second call is the same success, and the draft dies all the
      // same.
      final purchases = _SpyPurchases();
      final container = containerWith(purchases: purchases);
      final notifier = container.read(newPurchaseViewModelProvider.notifier);

      expect(
        await notifier.save(draft: draft(), today: today),
        isA<PurchaseSaved>(),
      );
      expect(
        await notifier.save(draft: draft(), today: today),
        isA<PurchaseSaved>(),
      );

      expect(purchases.saved, hasLength(1), reason: 'one purchase, not two');
    });

    test('a double tap saves once', () async {
      // The guard of rule 14. This test has to FAIL if it is removed.
      final purchases = _SpyPurchases();
      final container = containerWith(purchases: purchases);
      final notifier = container.read(newPurchaseViewModelProvider.notifier);

      final first = notifier.save(draft: draft(), today: today);
      final second = notifier.save(draft: draft(), today: today);

      expect(await first, isA<PurchaseSaved>());
      expect(await second, isNull, reason: 'the guard answers null');
      expect(purchases.saveCalls, 1);
    });

    test('saves even with the picker in error — the resend path', () async {
      // The automatic resend runs on the app's opening, with screen 3 never
      // opened and, on the phone that just came back online, a catalog that
      // may still be failing. A save that needed the picker would blow up on
      // a purchase the person thinks is already safe.
      //
      // It works because every line of the draft carries its own leaf, so
      // the type each one writes off is known with no catalog at all.
      final purchases = _SpyPurchases()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(purchases: purchases);
      await expectLater(
        container.read(newPurchaseViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<PurchaseSaved>());
      expect(purchases.saved, hasLength(1));
    });

    test('a list that failed to load does not lose the purchase', () async {
      // Reading the list is what the write-off needs; the purchase itself
      // does not depend on it. A failure here is still a failure — but it
      // must leave the draft on the phone.
      final purchases = _SpyPurchases();
      final drafts = PurchaseDraftRepositoryLocal(initial: draft());
      final container = containerWith(
        purchases: purchases,
        drafts: drafts,
        list: _FailingList(),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect(outcome, isA<PurchaseHeldOffline>());
      expect(purchases.saveCalls, 0);
      expect(drafts.readNow(), isNotNull);
    });
  });

  group('the spending cap (H13)', () {
    /// A cap of R$ 1.500 in force since August, over a month that has already
    /// spent [spent] cents. The purchase every case below saves costs R$ 62.
    SpendingCapRepositoryLocal capsWith({
      required int spent,
      bool warned80 = false,
      bool warned100 = false,
      bool hasCap = true,
    }) => SpendingCapRepositoryLocal(
      latency: Duration.zero,
      today: today,
      cap: hasCap
          ? SpendingCap(
              amount: const Money(150000),
              effectiveFrom: DateTime(2026, 8, 1),
            )
          // A cap that only starts in September is a month with none.
          : SpendingCap(
              amount: const Money(150000),
              effectiveFrom: DateTime(2026, 9, 1),
            ),
      spending: {DateTime(2026, 8, 1): Money(spent)},
      alerts: {
        DateTime(2026, 8, 1): CapAlerts(
          month: DateTime(2026, 8, 1),
          warned80: warned80,
          warned100: warned100,
        ),
      },
    );

    test('the purchase that takes the month past 80% warns', () async {
      // R$ 1.150 + R$ 62 = R$ 1.212, over the R$ 1.200 cut.
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 115000),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect((outcome! as PurchaseSaved).capAlert, CapThreshold.approaching);
      // The mark travels WITH the purchase, in the same submission — never as
      // a second write after it.
      expect(purchases.saved.single.capAlerts.single.warned80, isTrue);
      expect(purchases.saved.single.capAlerts.single.month, DateTime(2026, 8, 1));
    });

    test('the one that blows the cap says only the graver sentence', () async {
      // R$ 1.490 + R$ 62 crosses BOTH cuts in the same write (D-h).
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 149000),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect((outcome! as PurchaseSaved).capAlert, CapThreshold.exceeded);
      // …and both marks go up, which is what stops the next purchase from
      // firing the 100% on its own.
      expect(purchases.saved.single.capAlerts.single.warned80, isTrue);
      expect(purchases.saved.single.capAlerts.single.warned100, isTrue);
    });

    test('the next purchase of the month does not repeat the warning', () async {
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 130000, warned80: true),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect((outcome! as PurchaseSaved).capAlert, isNull);
      // The mark is written again all the same: the SQL preserves the first
      // stamp, and `false` here would be a rearm nobody asked for.
      expect(purchases.saved.single.capAlerts.single.warned80, isTrue);
    });

    test('a month with no cap warns nothing and writes no mark', () async {
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 900000, hasCap: false),
      );

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(), today: today);

      expect((outcome! as PurchaseSaved).capAlert, isNull);
      // Empty and not "both false": there is no row to touch.
      expect(purchases.saved.single.capAlerts, isEmpty);
    });

    test('it is the month of the PURCHASE, not the current one', () async {
      // A forgotten receipt of August registered in September pushes AUGUST
      // across its cut, and it is August's cap that applies.
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 115000),
      );

      await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(
            draft: draft(date: DateTime(2026, 8, 18)),
            today: DateTime(2026, 9, 30),
          );

      expect(purchases.saved.single.capAlerts.single.month, DateTime(2026, 8, 1));
    });

    test('a resend that arrived twice warns about nothing', () async {
      // Its `spent` was read BEFORE the first send, so adding the total again
      // would overstate the month — and the purchase is already there.
      final purchases = _SpyPurchases();
      final container = containerWith(
        purchases: purchases,
        caps: capsWith(spent: 149000),
      );
      final notifier = container.read(newPurchaseViewModelProvider.notifier);

      await notifier.save(draft: draft(), today: today);
      final second = await notifier.save(draft: draft(), today: today);

      expect((second! as PurchaseSaved).capAlert, isNull);
      expect((second as PurchaseSaved).sameDay, isEmpty);
    });
  });

  group('the same-day repeat (H14)', () {
    _SpyPurchases spyWithBuyer() => _SpyPurchases(sameDayBuyer: 'esposa');

    test('a purchase of TODAY warns, and says "hoje"', () async {
      final container = containerWith(purchases: spyWithBuyer());

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: today), today: today);

      final alerts = (outcome! as PurchaseSaved).sameDay;
      expect(alerts, hasLength(1));
      expect(
        alerts.single.messageFor(today: today, shortDate: '28/08'),
        'Vocês dois compraram Refrigerante hoje.',
      );
    });

    test('a purchase of YESTERDAY warns, and names the day', () async {
      final yesterday = DateTime(2026, 8, 27);
      final container = containerWith(purchases: spyWithBuyer());

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: yesterday), today: today);

      expect(
        (outcome! as PurchaseSaved).sameDay.single.messageFor(
          today: today,
          shortDate: '27/08',
        ),
        'Vocês dois compraram Refrigerante no dia 27/08.',
      );
    });

    test('a purchase older than yesterday is not even asked about', () async {
      final purchases = spyWithBuyer();
      final container = containerWith(purchases: purchases);

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: DateTime(2026, 8, 5)), today: today);

      expect((outcome! as PurchaseSaved).sameDay, isEmpty);
      // Outside the window there is no question to ask, so the query does not
      // happen at all.
      expect(purchases.sameDayCalls, 0);
    });

    test('a purchase of one\'s own never warns', () async {
      // The `<>` of the query: the label registering is the one filtered out.
      final container = containerWith(purchases: _SpyPurchases(sameDayBuyer: 'Leandro'));

      final outcome = await container
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft(date: today), today: today);

      expect((outcome! as PurchaseSaved).sameDay, isEmpty);
    });
  });
}

class _FailingList extends ShoppingListRepositoryLocal {
  _FailingList() : super(latency: Duration.zero);

  @override
  Future<IList<ShoppingListItem>> fetchAll() async =>
      throw NetworkException('offline');
}

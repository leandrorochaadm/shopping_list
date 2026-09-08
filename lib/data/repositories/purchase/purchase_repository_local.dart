import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/purchase_summary.dart';
import '../../../domain/models/same_day_alert.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/write_off_undo.dart';
import 'purchase_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// **The leaves are the very ones `CatalogRepositoryLocal` has** — `prod-1` to
/// `prod-5`, under the same registrations and types. Two fakes telling
/// different stories would make screen 3 and screen 4 disagree in debug for a
/// reason that is only the fake's.
///
/// The seeded purchases exist so the pre-filled value can be SEEN without a
/// database: one crate of soft drink and one weighed beef, which are also the
/// two shapes the conversion treats differently.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class PurchaseRepositoryLocal implements PurchaseRepository {
  PurchaseRepositoryLocal({
    Iterable<PurchaseHistoryEntry>? history,
    this.sameDayBuyer,
    this.latency = const Duration(milliseconds: 400),
  }) : _history = [...history ?? _seedHistory()];

  /// The label the fake pretends bought the soft drink on WHATEVER day is
  /// asked about (H14) — see [fetchSameDayTypes].
  ///
  /// **Null answers nothing, and that is the default on purpose.** `debug`
  /// passes 'esposa' in `config/dependencies.dart`, which is what makes H14
  /// demonstrable without a database; a test that wants the alert asks for it
  /// by name, and the ten tests that only happen to save a purchase are not
  /// interrupted by a dialog belonging to another story.
  final String? sameDayBuyer;

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<PurchaseHistoryEntry> _history;

  /// The registered purchases, newest first — what the history pages over and
  /// what the correction opens. Twenty-five of them, because pages are twenty:
  /// this is the ONLY place "carregar mais" is exercised without a database.
  late final List<PurchaseDetail> _purchases = _seedPurchases();

  /// What was written, so a test can look at it — and so the SECOND save of
  /// the same purchase answers `true`, exactly like the `on conflict` of the
  /// real function. Without that here, the resend of H8 would be exercised
  /// against a fake that has no idea what idempotence is.
  final List<PurchaseSubmission> saved = [];

  /// What the correction and the deletion wrote, so a test can look at them
  /// without a database.
  final List<Purchase> corrected = [];
  final List<String> deleted = [];
  final List<RestoredListItem> restoredByCorrection = [];

  /// Every cap mark the three write doors sent, in order — the fake's half of
  /// `apply_cap_alerts`. It is what lets a test prove the automatic resend
  /// WRITES the mark while showing no dialog (D-g), which no screen can show.
  final List<CapAlerts> capAlertsWritten = [];

  static final _drinks = ProductType(
    id: 'type-1',
    name: 'Refrigerante',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.milliliter,
  );
  static final _beef = ProductType(
    id: 'type-2',
    name: 'Acém moído',
    categoryId: 'cat-2',
    baseUnit: BaseUnit.gram,
  );
  static final _coke = Brand(id: 'brand-1', name: 'Coca-Cola');

  static final _softDrink = ProductRegistration(
    id: 'reg-1',
    productTypeId: 'type-1',
    brandId: 'brand-1',
    description: 'original',
    sellingMode: SellingMode.byPiece,
  );
  static final _groundBeef = ProductRegistration(
    id: 'reg-2',
    productTypeId: 'type-2',
    sellingMode: SellingMode.byWeight,
  );

  static List<PurchaseHistoryEntry> _seedHistory() => [
    // A crate: 12 × 350 ml for R$ 62,00 — the case where a rounded price per
    // litre would answer R$ 62,04 for the very same purchase.
    //
    // The VALUES are not touched by H15: the two of them make an average of
    // R$ 14,51 a litre, so typing R$ 70,00 for one crate on screen 3 answers
    // "Subiu 15% sobre a média" in debug. Moving them to force the "18%" of
    // the wireframe would break the R$ 62,00 pre-fill two test files fix.
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
    // Weighed: 1,5 kg of beef — no brand, so its average is the TYPE's.
    PurchaseHistoryEntry(
      productId: 'prod-5',
      productTypeId: 'type-2',
      quantityInBaseUnit: 1500,
      paid: const Money(4500),
      purchasedOn: DateTime(2026, 8, 10),
    ),
    // **H19** — the two other packagings of the soft drink, so the `#3a`
    // panel opens with three priced lines in debug and tells the story of
    // requirement 17: the 2 L bottle is the best cost.
    //
    // The CRATE is not moved: its R$ 62,00 is the pre-filled value two test
    // files fix, and dropping it to the R$ 42,00 of the document would break
    // H7 and H15 in one go. The verdict in debug is the wireframe's — the
    // bottle — but the losers' percentages are NOT the document's, and this
    // is what the screen shows in debug:
    //
    //   bottle 2 L      R$ 10,00 / 2000 ml  ->  R$  5,00/L   ★
    //   can 350 ml      R$  4,00 /  350 ml  ->  R$ 11,43/L   −56%
    //   crate 12×350    R$ 62,00 / 4200 ml  ->  R$ 14,76/L   −66%
    //
    // The footer repeats the BIGGEST difference, which is against the crate:
    // "Coca-Cola original 2 L — 66% mais barato o litro". In the document
    // that sentence says 56%, because there the crate costs R$ 42,00.
    //
    // H15 in debug is untouched: `prod-1` and `prod-3` belong to `reg-1`,
    // which HAS a brand, so `PriceBaselines.forLeaf` reads `byProduct` and
    // the crate's average stays its own R$ 14,51 a litre.
    PurchaseHistoryEntry(
      productId: 'prod-1',
      productTypeId: 'type-1',
      quantityInBaseUnit: 350,
      paid: const Money(400),
      purchasedOn: DateTime(2026, 8, 12),
    ),
    PurchaseHistoryEntry(
      productId: 'prod-3',
      productTypeId: 'type-1',
      quantityInBaseUnit: 2000,
      paid: const Money(1000),
      purchasedOn: DateTime(2026, 8, 15),
    ),
  ];

  /// The three situations H9 and H10 have to SHOW, and none of them can be
  /// seen against a fake that only knows how to register:
  ///
  ///   * a list item CLOSED by a purchase, with its trail — so deleting has
  ///     something to give back;
  ///   * a PARTIAL write-off — 6 L asked, 2 L bought, item still open — which
  ///     is the "restam 4 litros" of the screen;
  ///   * a purchase that knocked a "não encontrei" down, so undoing puts the
  ///     mark back.
  static List<PurchaseDetail> _seedPurchases() {
    final crate = _byPiece('prod-4', 12, 350, BaseUnit.milliliter);
    final bottle = _byPiece('prod-3', 1, 2000, BaseUnit.milliliter);

    ListWriteOff off({
      required String purchaseItem,
      required String item,
      required int amount,
      bool clearedNotFound = false,
    }) => ListWriteOff(
      purchaseItemId: purchaseItem,
      shoppingListItemId: item,
      quantityWrittenOff: amount,
      clearedNotFound: clearedNotFound,
    );

    PurchaseDetail detail({
      required String id,
      required DateTime date,
      required String storeId,
      required String registeredBy,
      required List<PurchaseItem> items,
      List<ListWriteOff> trail = const [],
    }) {
      final purchase = Purchase(
        id: id,
        date: date,
        storeId: storeId,
        registeredBy: registeredBy,
        items: items.lock,
      );
      return PurchaseDetail(
        purchase: purchase,
        items: items.lock,
        trail: trail.lock,
      );
    }

    return [
      // 1. Closed an item, and knocked its "não encontrei" down along the way
      //    — `item-3` of `ShoppingListRepositoryLocal`, the only line of the
      //    fake list that carries brand AND packaging.
      detail(
        id: 'purchase-1',
        date: DateTime(2026, 8, 28),
        storeId: 'store-1',
        registeredBy: 'Leandro',
        items: [
          PurchaseItem(
            id: 'pi-1',
            option: crate,
            quantity: 1,
            paid: const Money(6200),
          ),
        ],
        trail: [
          off(
            purchaseItem: 'pi-1',
            item: 'item-3',
            amount: 4200,
            clearedNotFound: true,
          ),
        ],
      ),
      // 2. A PARTIAL write-off: `item-1` asked for 6 kg and this took 2 —
      //    the line stays on the list with 4 left.
      detail(
        id: 'purchase-2',
        date: DateTime(2026, 8, 27),
        storeId: 'store-2',
        registeredBy: 'esposa',
        items: [
          PurchaseItem(
            id: 'pi-2',
            option: _groundBeefOption,
            quantity: 2000,
            paid: const Money(4500),
          ),
        ],
        trail: [off(purchaseItem: 'pi-2', item: 'item-1', amount: 2000)],
      ),
      // 3. …and twenty-three more, so the second page exists. They write
      //    nothing off: what they are for is the paging.
      for (var i = 3; i <= 25; i++)
        detail(
          id: 'purchase-$i',
          date: DateTime(2026, 8, 26).subtract(Duration(days: i - 3)),
          storeId: i.isEven ? 'store-1' : 'store-2',
          registeredBy: i.isEven ? 'Leandro' : 'esposa',
          items: [
            PurchaseItem(
              id: 'pi-$i',
              option: bottle,
              quantity: 1,
              paid: Money(500 + i * 10),
            ),
          ],
        ),
    ];
  }

  static final _groundBeefOption = ProductOption(
    product: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
    registration: _groundBeef,
    type: _beef,
  );

  static ProductOption _byPiece(
    String id,
    int pieceCount,
    int pieceSize,
    BaseUnit unit,
  ) => ProductOption(
    product: Product(
      id: id,
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: pieceCount,
        pieceSize: pieceSize,
        baseUnit: unit,
      ),
    ),
    registration: _softDrink,
    type: _drinks,
    brand: _coke,
  );

  @override
  Future<IList<ProductOption>> fetchProductOptions() async {
    await Future<void>.delayed(latency);
    return [
      _byPiece('prod-1', 1, 350, BaseUnit.milliliter),
      _byPiece('prod-2', 1, 269, BaseUnit.milliliter),
      _byPiece('prod-3', 1, 2000, BaseUnit.milliliter),
      _byPiece('prod-4', 12, 350, BaseUnit.milliliter),
      // Sold by weight: the leaf exists, the packaging does not (decision B1).
      ProductOption(
        product: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
        registration: _groundBeef,
        type: _beef,
      ),
    ].lock;
  }

  @override
  Future<IList<PurchaseHistoryEntry>> fetchRecentItems(DateTime since) async {
    await Future<void>.delayed(latency);
    return _history
        .where((entry) => !entry.purchasedOn.isBefore(since))
        .toIList();
  }

  @override
  Future<bool> save(PurchaseSubmission submission) async {
    await Future<void>.delayed(latency);

    // The fake's half of `on conflict (id) do nothing`: the same purchase
    // arriving twice is registered once and says so.
    final already = saved.any(
      (entry) => entry.purchase.id == submission.purchase.id,
    );
    if (already) return true;

    saved.add(submission);
    capAlertsWritten.addAll(submission.capAlerts);
    for (final item in submission.purchase.items) {
      _history.add(
        PurchaseHistoryEntry(
          productId: item.productId,
          productTypeId: item.productTypeId,
          quantityInBaseUnit: item.quantityInBaseUnit,
          paid: item.paid,
          purchasedOn: submission.purchase.date,
        ),
      );
    }
    return false;
  }

  @override
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  }) async {
    await Future<void>.delayed(latency);
    // Newest first, and the tiebreaker is the id — the same stable order the
    // real query gets from `created_at`, without which a purchase on the
    // boundary shows up twice or vanishes.
    final ordered = [..._purchases]..sort((a, b) {
      final byDate = b.purchase.date.compareTo(a.purchase.date);
      return byDate != 0 ? byDate : a.purchase.id.compareTo(b.purchase.id);
    });

    final page = ordered.skip(offset).take(limit + 1).toList();
    return PurchaseHistoryPage(
      purchases: [
        for (final entry in page.take(limit)) _summaryOf(entry),
      ].lock,
      hasMore: page.length > limit,
    );
  }

  @override
  Future<PurchaseDetail> fetchDetail(String purchaseId) async {
    await Future<void>.delayed(latency);
    final found = _purchases
        .where((entry) => entry.purchase.id == purchaseId)
        .firstOrNull;
    if (found == null) {
      throw ArgumentError.value(purchaseId, 'purchaseId', 'purchase not found');
    }
    return found;
  }

  @override
  Future<void> correct({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    await Future<void>.delayed(latency);
    corrected.add(purchase);
    capAlertsWritten.addAll(capAlerts);
    restoredByCorrection
      ..clear()
      ..addAll(restored);

    final index = _purchases.indexWhere(
      (entry) => entry.purchase.id == purchase.id,
    );
    final next = PurchaseDetail(
      purchase: purchase,
      items: purchase.items,
      trail: writeOffs,
    );
    if (index >= 0) {
      _purchases[index] = next;
    } else {
      _purchases.add(next);
    }
  }

  @override
  Future<void> delete({
    required String purchaseId,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  }) async {
    await Future<void>.delayed(latency);
    deleted.add(purchaseId);
    capAlertsWritten.addAll(capAlerts);
    restoredByCorrection
      ..clear()
      ..addAll(restored);
    _purchases.removeWhere((entry) => entry.purchase.id == purchaseId);
  }

  /// **The seeded purchases cannot answer this, and that is why it is
  /// written the way it is** (D-m). `_seedPurchases` uses FIXED dates — the
  /// most recent is 28/08/2026 — and the caller only asks inside
  /// `isWithinRepeatWindow(date, today)`, whose `today` is the real clock. In
  /// any month after August 2026 the seed is outside the window forever, so
  /// searching it would make H14 undemonstrable in debug.
  ///
  /// So the fake ANSWERS for any day: whoever is not [sameDayBuyer] is told
  /// the buyer already brought [_sameDayType] home that day. No
  /// `DateTime.now()` enters here, and a test that wants the empty answer
  /// registers as [sameDayBuyer].
  @override
  Future<IList<SameDayAlert>> fetchSameDayTypes({
    required DateTime date,
    required String registeredBy,
    required ISet<String> productTypeIds,
  }) async {
    await Future<void>.delayed(latency);

    // The `<>` of the query: a purchase of one's own never warns. And with
    // nobody configured there is nobody to have bought anything.
    if (sameDayBuyer == null || registeredBy == sameDayBuyer) {
      return const IList.empty();
    }
    if (!productTypeIds.contains(_sameDayTypeId)) return const IList.empty();

    return [
      SameDayAlert(
        productTypeId: _sameDayTypeId,
        typeName: _sameDayTypeName,
        purchasedOn: date,
      ),
    ].lock;
  }

  /// The soft drink — the type every leaf of the picker but the beef hangs
  /// from, so the alert shows up in debug on the most ordinary purchase. Two
  /// constants and not a record: this project has none (rule 16).
  static const _sameDayTypeId = 'type-1';
  static const _sameDayTypeName = 'Refrigerante';

  /// The store's NAME is resolved here the way the real query resolves it
  /// through the embed — the purchase itself only holds the key.
  PurchaseSummary _summaryOf(PurchaseDetail entry) => PurchaseSummary(
    id: entry.purchase.id,
    purchaseDate: entry.purchase.date,
    storeName: _storeNames[entry.purchase.storeId] ?? '',
    registeredBy: entry.purchase.registeredBy,
    total: entry.purchase.total,
    itemCount: entry.items.length,
  );

  /// The very stores `StoreRepositoryLocal` has: two fakes telling different
  /// stories would make the history and the picker disagree in debug for a
  /// reason that is only the fake's.
  static const _storeNames = {
    'store-1': 'Carrefour',
    'store-2': 'Feira do Bairro',
    'store-3': 'Mercearia do Zé',
  };
}

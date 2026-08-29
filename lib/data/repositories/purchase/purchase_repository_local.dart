import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
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
    this.latency = const Duration(milliseconds: 400),
  }) : _history = [...history ?? _seedHistory()];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<PurchaseHistoryEntry> _history;

  /// What was written, so a test can look at it — and so the SECOND save of
  /// the same purchase answers `true`, exactly like the `on conflict` of the
  /// real function. Without that here, the resend of H8 would be exercised
  /// against a fake that has no idea what idempotence is.
  final List<PurchaseSubmission> saved = [];

  static final _drinks = ProductType(
    id: 'type-1',
    name: 'Refrigerante',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.liter,
  );
  static final _beef = ProductType(
    id: 'type-2',
    name: 'Acém moído',
    categoryId: 'cat-2',
    baseUnit: BaseUnit.kilogram,
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
    PurchaseHistoryEntry(
      productId: 'prod-4',
      quantityInBaseUnit: 4200,
      paid: const Money(6200),
      purchasedOn: DateTime(2026, 8, 18),
    ),
    PurchaseHistoryEntry(
      productId: 'prod-4',
      quantityInBaseUnit: 4200,
      paid: const Money(5990),
      purchasedOn: DateTime(2026, 7, 30),
    ),
    // Weighed: 1,5 kg of beef.
    PurchaseHistoryEntry(
      productId: 'prod-5',
      quantityInBaseUnit: 1500,
      paid: const Money(4500),
      purchasedOn: DateTime(2026, 8, 10),
    ),
  ];

  static ProductOption _byPiece(
    String id,
    int pieceCount,
    int pieceSize,
    MeasureUnit unit,
  ) => ProductOption(
    product: Product(
      id: id,
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: pieceCount,
        pieceSize: pieceSize,
        pieceSizeUnit: unit,
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
      _byPiece('prod-1', 1, 350, MeasureUnit.milliliter),
      _byPiece('prod-2', 1, 269, MeasureUnit.milliliter),
      _byPiece('prod-3', 1, 2000, MeasureUnit.liter),
      _byPiece('prod-4', 12, 350, MeasureUnit.milliliter),
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
    for (final item in submission.purchase.items) {
      _history.add(
        PurchaseHistoryEntry(
          productId: item.productId,
          quantityInBaseUnit: item.quantityInBaseUnit,
          paid: item.paid,
          purchasedOn: submission.purchase.date,
        ),
      );
    }
    return false;
  }
}

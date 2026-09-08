import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/base_unit.dart';
import '../../../domain/models/brand.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/packaging.dart';
import '../../../domain/models/period_report.dart';
import '../../../domain/models/price_quote.dart';
import '../../../domain/models/price_reference.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/product_registration.dart';
import '../../../domain/models/product_type.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/store.dart';
import 'report_repository.dart';

/// One purchase line, flattened the way the `report_period` query flattens it:
/// the day, the whole chain from category to brand, and the two numbers that
/// get summed.
///
/// A `final class` and not a record (rule 16): this is the shape the whole
/// fake is written against, and a record would have no name to say so.
final class ReportLine {
  const ReportLine({
    required this.day,
    required this.categoryId,
    required this.categoryName,
    required this.productTypeId,
    required this.productTypeName,
    required this.baseUnit,
    required this.brandId,
    required this.brandName,
    required this.quantityInBaseUnit,
    required this.paid,
  });

  final DateTime day;
  final String categoryId;
  final String categoryName;
  final String productTypeId;
  final String productTypeName;
  final BaseUnit baseUnit;

  /// Null is a VALUE: the product with no brand (decision B2).
  final String? brandId;
  final String? brandName;

  final int quantityInBaseUnit;
  final Money paid;
}

/// In-memory fake: debug without --dart-define, and every test.
///
/// **It filters by the period for real, and aggregates in Dart** — a fake that
/// always answered the same report would hide both the empty state and the two
/// month shortcuts, which are precisely what this screen is made of.
///
/// The seed is the written story of requirement 4, over the SAME catalog
/// `CatalogRepositoryLocal` holds: 6 kg of ground beef for R$ 192,00 at
/// R$ 32,00/kg, and 6,8 kg of washing powder for R$ 136,00 at R$ 20,00/kg
/// splitting into Omo and Tixan. Two fakes telling different stories would
/// make screen 3 and screen 5 disagree in debug for a reason that is only the
/// fake's.
///
/// **Since H16 it holds a SECOND seed**, of price quotes — see [_seedQuotes].
/// The two are independent: the summary aggregates, the comparison does not,
/// and neither is computed from the other.
///
/// **Since H17 the first seed is shared with `ConsumptionRepositoryLocal`**
/// (decision E-l): that fake holds the SAME purchases, month by month, with no
/// price. Screens 5 and 6 answer different questions about the same history,
/// and two seeds telling different stories would make them disagree about the
/// same month in debug for a reason that is only the fake's. **The sync is
/// manual and no test defends it** — whoever adds a line here adds it there.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class ReportRepositoryLocal implements ReportRepository {
  ReportRepositoryLocal({
    Iterable<ReportLine>? lines,
    Iterable<PriceQuote>? quotes,
    this.latency = const Duration(milliseconds: 400),
  }) : _lines = [...lines ?? _seed()],
       _quotes = [...quotes ?? _seedQuotes()];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<ReportLine> _lines;

  /// The second seed, of H16 — see [_seedQuotes].
  final List<PriceQuote> _quotes;

  static List<ReportLine> _seed() => [
    // ── March, May, June and the second line of July are H17's (decision
    //    E-l): `ConsumptionRepositoryLocal` holds the SAME purchases with no
    //    price, so screen 5 and screen 6 never disagree about the same month
    //    in debug. **Change one seed and you have to change the other** —
    //    there is no test defending it, and the failure is silent.
    //
    //    March is deliberately OUTSIDE both windows of a 15/08/2026 clock: it
    //    is what makes the coffee divide by three with a single purchase
    //    inside the closed window.
    _line(DateTime(2026, 3, 10), _coffee, quantity: 1000, cents: 3200),
    _line(
      DateTime(2026, 5, 5),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 6100,
    ),
    _line(DateTime(2026, 5, 12), _beef, quantity: 12000, cents: 38400),
    _line(
      DateTime(2026, 6, 5),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 6150,
    ),
    // The FIRST purchase of the washing powder: it is what makes its divisor
    // two instead of three.
    _line(
      DateTime(2026, 6, 5),
      _powder,
      brandId: 'brand-2',
      brandName: 'Omo',
      quantity: 8000,
      cents: 16000,
    ),
    _line(DateTime(2026, 6, 10), _beef, quantity: 10000, cents: 32000),
    // The only coffee inside the closed window — 2 kg over three months, which
    // is the 0,7 kg of `wireframes §Tela 2`.
    _line(DateTime(2026, 6, 20), _coffee, quantity: 2000, cents: 6600),
    _line(
      DateTime(2026, 7, 10),
      _powder,
      brandId: 'brand-2',
      brandName: 'Omo',
      quantity: 8000,
      cents: 16000,
    ),
    // ── Requirement 4, first example: 5 kg at R$ 30 and 1 kg at R$ 42 make
    //    6 kg at R$ 32,00/kg — and NOT the R$ 36 an average of averages gives.
    _line(DateTime(2026, 8, 10), _beef, quantity: 5000, cents: 15000),
    _line(DateTime(2026, 8, 18), _beef, quantity: 1000, cents: 4200),
    // ── Requirement 4, second example: one type adding up two brands.
    _line(
      DateTime(2026, 8, 12),
      _powder,
      brandId: 'brand-2',
      brandName: 'Omo',
      quantity: 4300,
      cents: 8600,
    ),
    _line(
      DateTime(2026, 8, 20),
      _powder,
      brandId: 'brand-4',
      brandName: 'Tixan',
      quantity: 2500,
      cents: 5000,
    ),
    _line(
      DateTime(2026, 8, 18),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 6200,
    ),
    // A type with no brand in a category that also holds a branded one: it is
    // what makes decision D-a visible while developing.
    _line(DateTime(2026, 8, 5), _paper, quantity: 12, cents: 3600),
    // ── The month before, so `‹ Julho` answers something different instead of
    //    looking broken.
    _line(
      DateTime(2026, 7, 30),
      _softDrink,
      brandId: 'brand-1',
      brandName: 'Coca-Cola',
      quantity: 4200,
      cents: 5990,
    ),
    _line(DateTime(2026, 7, 15), _beef, quantity: 2000, cents: 6000),
  ];

  static const _softDrink = _Type(
    'type-1',
    'Refrigerante',
    'cat-1',
    'Bebidas',
    BaseUnit.milliliter,
  );
  static const _beef = _Type(
    'type-2',
    'Acém moído',
    'cat-2',
    'Carnes',
    BaseUnit.gram,
  );
  static const _paper = _Type(
    'type-3',
    'Papel higiênico',
    'cat-3',
    'Limpeza',
    BaseUnit.unit,
  );
  static const _powder = _Type(
    'type-4',
    'Sabão em pó',
    'cat-3',
    'Limpeza',
    BaseUnit.gram,
  );
  // Born with H17, in `CatalogRepositoryLocal` too: it is the type of the
  // written story of `requisitos §8` — bought before the window and once
  // inside it, so it divides by three and is suggested at 0,7 kg.
  static const _coffee = _Type(
    'type-5',
    'Café',
    'cat-4',
    'Mercearia',
    BaseUnit.gram,
  );

  static ReportLine _line(
    DateTime day,
    _Type type, {
    String? brandId,
    String? brandName,
    required int quantity,
    required int cents,
  }) => ReportLine(
    day: day,
    categoryId: type.categoryId,
    categoryName: type.categoryName,
    productTypeId: type.id,
    productTypeName: type.name,
    baseUnit: type.baseUnit,
    brandId: brandId,
    brandName: brandName,
    quantityInBaseUnit: quantity,
    paid: Money(cents),
  );

  /// The story of H16, over the SAME leaves of `CatalogRepositoryLocal` and
  /// the SAME stores of `StoreRepositoryLocal` — two fakes telling different
  /// stories would make screen 3 and screen 5 disagree in debug for a reason
  /// that is only the fake's.
  ///
  /// What it shows is exactly what the two `*` of the wireframe explain:
  ///
  ///   * **"Este produto" on the crate** repeats the wireframe's table: the
  ///     Carrefour leads at R$ 11,43/L, and that price is from 03/07 while
  ///     the two dearer ones are from August. The date is the caveat, and the
  ///     cheapest is the oldest.
  ///   * **"Tipo inteiro"** turns the Carrefour inside out: the most recent
  ///     Refrigerante there is the single CAN of 20/08 at R$ 15,00/L, so it
  ///     goes from first to last. That is the view that answers "does the
  ///     crate pay off?", and it answers yes, and where.
  ///   * the **beef** exercises the leaf with no brand and the `/kg` on the
  ///     same screen.
  ///   * the **Mercearia do Zé is deactivated** in `StoreRepositoryLocal` and
  ///     shows up all the same: buying there is a fact of the past, and
  ///     deactivating does not rewrite the past (requirement 16).
  static List<PriceQuote> _seedQuotes() => [
    _quote(_crate, _carrefour, DateTime(2026, 7, 3), 4200, 4800),
    _quote(_crate, _streetMarket, DateTime(2026, 8, 12), 4200, 5670),
    _quote(_crate, _grocery, DateTime(2026, 8, 18), 4200, 6200),
    _quote(_can, _carrefour, DateTime(2026, 8, 20), 350, 525),
    _quote(
      _beefLeaf,
      _streetMarket,
      DateTime(2026, 8, 10),
      1500,
      4500,
      meat: true,
    ),
    _quote(_beefLeaf, _carrefour, DateTime(2026, 8, 5), 2000, 6800, meat: true),
  ];

  static PriceQuote _quote(
    ProductOption option,
    Store store,
    DateTime day,
    int quantity,
    int cents, {
    bool meat = false,
  }) => PriceQuote(
    option: option,
    categoryId: meat ? 'cat-2' : 'cat-1',
    categoryName: meat ? 'Carnes' : 'Bebidas',
    store: store,
    price: PriceReference(
      paid: Money(cents),
      quantityInBaseUnit: quantity,
      purchasedOn: day,
    ),
  );

  static final _carrefour = Store(id: 'store-1', name: 'Carrefour');
  static final _streetMarket = Store(id: 'store-2', name: 'Feira do Bairro');
  // Deactivated in `StoreRepositoryLocal`, and it has to arrive deactivated
  // here too: the `==` of PriceQuote depends on it.
  static final _grocery = Store(
    id: 'store-3',
    name: 'Mercearia do Zé',
    active: false,
  );

  static final _drinksType = ProductType(
    id: 'type-1',
    name: 'Refrigerante',
    categoryId: 'cat-1',
    baseUnit: BaseUnit.milliliter,
  );
  static final _beefType = ProductType(
    id: 'type-2',
    name: 'Acém moído',
    categoryId: 'cat-2',
    baseUnit: BaseUnit.gram,
  );
  static final _cokeBrand = Brand(id: 'brand-1', name: 'Coca-Cola');

  /// The three leaves, with the SAME ids `CatalogRepositoryLocal` gives them.
  /// The history comes empty on purpose: here the option is identity and
  /// label, not ranking.
  static final _crate = ProductOption(
    product: Product(
      id: 'prod-4',
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: 12,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
      ),
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: 'brand-1',
      sellingMode: SellingMode.byPiece,
    ),
    type: _drinksType,
    brand: _cokeBrand,
  );
  static final _can = ProductOption(
    product: Product(
      id: 'prod-1',
      productRegistrationId: 'reg-1',
      packaging: Packaging(
        pieceCount: 1,
        pieceSize: 350,
        baseUnit: BaseUnit.milliliter,
      ),
    ),
    registration: ProductRegistration(
      id: 'reg-1',
      productTypeId: 'type-1',
      brandId: 'brand-1',
      sellingMode: SellingMode.byPiece,
    ),
    type: _drinksType,
    brand: _cokeBrand,
  );
  static final _beefLeaf = ProductOption(
    product: const Product(id: 'prod-5', productRegistrationId: 'reg-2'),
    registration: ProductRegistration(
      id: 'reg-2',
      productTypeId: 'type-2',
      sellingMode: SellingMode.byWeight,
    ),
    type: _beefType,
  );

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    await Future<void>.delayed(latency);

    // The window filters, and NOTHING else: no ordering and no reduction, the
    // same as the `select` of the real thing. Whoever chooses the most recent
    // purchase of each store is `buildComparison`, in the domain.
    return _quotes
        .where((quote) => !quote.purchasedOn.isBefore(since))
        .toIList();
  }

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    await Future<void>.delayed(latency);

    // Closed at both ends, exactly like `between` in the query.
    final lines = _lines
        .where(
          (line) =>
              !line.day.isBefore(period.from) && !line.day.isAfter(period.to),
        )
        .toList();

    final categories = <String, CategorySpending>{};
    for (final line in lines) {
      final current = categories[line.categoryId];
      categories[line.categoryId] = CategorySpending(
        categoryId: line.categoryId,
        name: line.categoryName,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    final types = <String, TypeSpending>{};
    for (final line in lines) {
      final current = types[line.productTypeId];
      types[line.productTypeId] = TypeSpending(
        productTypeId: line.productTypeId,
        categoryId: line.categoryId,
        name: line.productTypeName,
        baseUnit: line.baseUnit,
        quantityInBaseUnit:
            (current?.quantityInBaseUnit ?? 0) + line.quantityInBaseUnit,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    final brands = <String, BrandSpending>{};
    for (final line in lines) {
      // The null brand groups with itself, and it is the query's null group:
      // what to do with it is rule C2, and it is decided in the domain.
      final key = '${line.productTypeId}/${line.brandId ?? ''}';
      final current = brands[key];
      brands[key] = BrandSpending(
        productTypeId: line.productTypeId,
        brandId: line.brandId,
        name: line.brandName,
        quantityInBaseUnit:
            (current?.quantityInBaseUnit ?? 0) + line.quantityInBaseUnit,
        spent: (current?.spent ?? Money.zero) + line.paid,
      );
    }

    // No ordering here either, for the same reason the query has none: whoever
    // orders is `buildReportSections`, and a second ordering is a second thing
    // to diverge.
    return PeriodReport(
      categories: categories.values.toIList(),
      types: types.values.toIList(),
      brands: brands.values.toIList(),
    );
  }
}

/// The chain a line hangs from, written once so the seed above reads as a
/// list of purchases and not as a list of ids.
final class _Type {
  const _Type(
    this.id,
    this.name,
    this.categoryId,
    this.categoryName,
    this.baseUnit,
  );

  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final BaseUnit baseUnit;
}

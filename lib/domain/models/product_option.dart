import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'base_unit.dart';
import 'brand.dart';
import 'money.dart';
import 'name_normalization.dart';
import 'price_increase.dart';
import 'price_reference.dart';
import 'product.dart';
import 'product_registration.dart';
import 'product_type.dart';
import 'selling_choice.dart';

/// One line of the Produto picker on screen 3 — and an ENTITY, not a DTO: it
/// carries the rules of decision C1 (how the search matches, how the list is
/// ordered) and the conversion of what was typed into the base unit.
///
/// It is a leaf plus everything the aisle needs to recognize it — the
/// registration, the type, the brand — and the two numbers that come from the
/// history: how many times it was bought in the last three months, and what
/// the last purchase paid. Fetching those per selected product would be a
/// round trip in the middle of a purchase.
final class ProductOption {
  const ProductOption({
    required this.product,
    required this.registration,
    required this.type,
    this.brand,
    this.purchaseCount = 0,
    this.lastPurchasedOn,
    this.priceReference,
    this.baseline,
  });

  /// Reads the PostgREST embed: the leaf comes with its registration nested,
  /// and the registration with its type and its brand.
  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final registration = json['product_registration'] as Map<String, dynamic>;
    final brand = registration['brand'] as Map<String, dynamic>?;

    return ProductOption(
      product: Product.fromJson(json),
      registration: ProductRegistration.fromJson(registration),
      type: ProductType.fromJson(
        registration['product_type'] as Map<String, dynamic>,
      ),
      // Null is "Sem marca" (decision B2) — a real answer, not missing data,
      // which is why the embed comes without `!inner`.
      brand: brand == null ? null : Brand.fromJson(brand),
    );
  }

  /// The way back to [fromJson] — the SAME nested shape PostgREST returns.
  ///
  /// It exists for the purchase DRAFT: an item kept in Hive has to be drawn
  /// and re-edited with no network at all, which is the whole point of H8.
  /// Storing only the leaf's id would mean looking it up in a catalog that,
  /// in airplane mode, never loaded.
  ///
  /// The history is deliberately left out: [purchaseCount],
  /// [lastPurchasedOn], [priceReference] and [baseline] are what the last
  /// three months say, not what this option IS, and they are recomputed on
  /// every load.
  Map<String, dynamic> toJson() => {
    ...product.toJson(),
    'product_registration': {
      ...registration.toJson(),
      'product_type': type.toJson(),
      'brand': brand?.toJson(),
    },
  };

  final Product product;
  final ProductRegistration registration;

  /// The level that SUMS — it carries the base unit, and it is the header of
  /// the group this option belongs to.
  final ProductType type;

  /// Null is "Sem marca" (decision B2).
  final Brand? brand;

  /// How many purchase items of this leaf happened in the last three months.
  /// It ORDERS the picker and never reaches the screen: the count is not
  /// information anyone asked for, and `★` belongs to the `#3a` panel of H19.
  final int purchaseCount;

  /// The tiebreak when two options were bought the same number of times.
  final DateTime? lastPurchasedOn;

  /// What the last purchase of this leaf paid. Null is the wireframe's "sem
  /// base de comparação" — a product never bought pre-fills nothing.
  final PriceReference? priceReference;

  /// **H15** — the average of the rolling window this typed price is compared
  /// against, ALREADY resolved: the leaf's when the registration has a brand,
  /// the type's when it does not. Whoever resolves it is
  /// `PriceBaselines.forLeaf`, inside `rankOptions`, and never the screen.
  ///
  /// Null is the silence of the requirement: a product with no purchase at
  /// all in the window has no base, and the system stays quiet.
  final PriceBaseline? baseline;

  String? get id => product.id;

  BaseUnit get baseUnit => type.baseUnit;

  bool get isSoldByWeight => registration.isSoldByWeight;

  /// 'Coca-Cola 12 × 350 ml', 'Coca-Cola zero 2 L', 'Acém moído (peso)'.
  ///
  /// The loose product is named after the grandeza of its TYPE — '(peso)' in
  /// the kilogram, '(volume)' in the litre — because "a peso" does not name
  /// bulk olive oil, which is measured in litres. `looseNameOf` is the single
  /// place that word lives.
  ///
  /// Brand, description and packaging, in that order, skipping whatever does
  /// not exist. The TYPE is not in it because the picker is grouped by type
  /// and the group header already says it — except when nothing else is left,
  /// which is the weight-sold product with no brand and no description: there
  /// the type name IS the name of the thing.
  String get label {
    final parts = [
      if (brand != null) brand!.name,
      if (registration.description.isNotEmpty) registration.description,
      if (product.packaging != null) product.packaging!.label,
    ];
    if (parts.isEmpty) parts.add(type.name);
    if (isSoldByWeight) {
      parts.add('(${SellingChoice.looseNameOf(baseUnit).toLowerCase()})');
    }
    return parts.join(' ');
  }

  /// The C1 search: it matches a STRETCH of the name, ignoring case, blanks
  /// and accents — `normalizeName` on both sides, then `contains`.
  ///
  /// It looks at the type as well as at brand, description and packaging, so
  /// 'lei' finds every milk and 'italac' finds it by brand alone. And '350'
  /// finds it by the packaging, which is how a shelf is actually searched.
  bool matches(String query) {
    final needle = normalizeName(query);
    if (needle.isEmpty) return true;
    return normalizeName('${type.name} $label').contains(needle);
  }

  /// **H15** — did this price go up? The View ASKS (rule 11); it does not
  /// compare cents inside `build()`.
  ///
  /// [quantityInBaseUnit] is what [toBaseUnit] already converted — the screen
  /// never hands the raw typed number over.
  PriceIncrease? priceIncreaseFor({
    required Money paid,
    required int quantityInBaseUnit,
  }) => evaluatePriceIncrease(
    baseline: baseline,
    paid: paid,
    quantityInBaseUnit: quantityInBaseUnit,
  );

  /// Turns what was typed into the type's base unit — and this is the only
  /// place that conversion exists.
  ///
  /// Sold by piece, the typed number is a count of packages: "1 fardo de
  /// 12 × 350 ml" is 4200 ml, and so is "12 garrafas de 350 ml". Sold by
  /// weight, the amount was already parsed by the screen through
  /// `baseUnit.parseAmount`, so it arrives in grams, millilitres or
  /// centimetres and passes straight through.
  int toBaseUnit(int typedQuantity) {
    final packaging = product.packaging;
    if (isSoldByWeight || packaging == null) return typedQuantity;
    return typedQuantity * packaging.totalContent;
  }

  /// The label of the Quantidade field.
  ///
  /// Sold by piece it is just 'Quantidade': the packaging name right above it
  /// already says what is being counted, and "Quantidade (un)" beside
  /// "12 × 350 ml" reads as twelve units. Sold by weight the unit has to be
  /// on the field, because there is no packaging to say it.
  String get quantityLabel {
    if (!isSoldByWeight) return 'Quantidade';
    return switch (baseUnit) {
      BaseUnit.gram => 'Peso (g)',
      BaseUnit.milliliter => 'Volume (ml)',
      BaseUnit.unit => 'Quantidade (un)',
      BaseUnit.centimeter => 'Tamanho (cm)',
    };
  }

  /// The history, attached after the leaves and the recent purchases have
  /// been crossed. A method and not a `copyWith` because two of the three
  /// fields are nullable, and `??` cannot tell "keep" from "clear".
  ProductOption withHistory({
    required int purchaseCount,
    DateTime? lastPurchasedOn,
    PriceReference? priceReference,
    PriceBaseline? baseline,
  }) => ProductOption(
    product: product,
    registration: registration,
    type: type,
    brand: brand,
    purchaseCount: purchaseCount,
    lastPurchasedOn: lastPurchasedOn,
    priceReference: priceReference,
    baseline: baseline,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductOption &&
          other.product == product &&
          other.registration == registration &&
          other.type == type &&
          other.brand == brand &&
          other.purchaseCount == purchaseCount &&
          other.lastPurchasedOn == lastPurchasedOn &&
          other.priceReference == priceReference &&
          other.baseline == baseline);

  @override
  int get hashCode => Object.hash(
    product,
    registration,
    type,
    brand,
    purchaseCount,
    lastPurchasedOn,
    priceReference,
    baseline,
  );

  @override
  String toString() => 'ProductOption($label, bought $purchaseCount)';
}

/// Decision C1 in one place: most bought in the last three months first, ties
/// go to the most recently bought, and then alphabetical — so the order never
/// flickers between two options nobody has ever bought.
int compareForPicker(ProductOption a, ProductOption b) {
  final byCount = b.purchaseCount.compareTo(a.purchaseCount);
  if (byCount != 0) return byCount;

  final mine = a.lastPurchasedOn;
  final theirs = b.lastPurchasedOn;
  if (mine != null && theirs != null && mine != theirs) {
    return theirs.compareTo(mine);
  }
  if (mine == null && theirs != null) return 1;
  if (mine != null && theirs == null) return -1;

  // Normalized, because 'Açaí'.compareTo('Bebida') in Dart compares code
  // units and would land the 'ç' after the 'z'.
  final byName = normalizeName(a.label).compareTo(normalizeName(b.label));
  if (byName != 0) return byName;

  // The id breaks the tie so the order is STABLE across fetches.
  return (a.id ?? '').compareTo(b.id ?? '');
}

/// One header and its options, in the order the picker draws them.
final class ProductGroup {
  const ProductGroup({required this.header, required this.options});

  /// pt-BR: the group header inside the picker. On screen 3 it is the name of
  /// the TYPE (decision C1); on the comparison tab of screen 5 it is the name
  /// of the CATEGORY. The widget is the same one, which is why it takes text
  /// and not an entity (decision D-u).
  final String header;

  final IList<ProductOption> options;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductGroup &&
          other.header == header &&
          other.options == options;

  @override
  int get hashCode => Object.hash(header, options);
}

/// The picker is GROUPED BY TYPE, so a flat sort is not enough: ordering by
/// count alone would put a soft drink between two milks.
///
/// Each group is sorted inside by [compareForPicker], and the groups
/// themselves by their best option — so the type he buys most opens the list.
IList<ProductGroup> groupForPicker(IList<ProductOption> options) {
  final byType = <String, List<ProductOption>>{};
  final types = <String, ProductType>{};

  for (final option in options) {
    // A type with no id has not been written yet and cannot be the one an
    // option points at — the name is the fallback so nothing is dropped.
    final key = option.type.id ?? option.type.name;
    types[key] = option.type;
    (byType[key] ??= []).add(option);
  }

  for (final entry in byType.entries) {
    entry.value.sort(compareForPicker);
  }

  final keys = byType.keys.toList()
    ..sort((a, b) {
      final best = compareForPicker(byType[a]!.first, byType[b]!.first);
      if (best != 0) return best;
      return normalizeName(
        types[a]!.name,
      ).compareTo(normalizeName(types[b]!.name));
    });

  return [
    for (final key in keys)
      ProductGroup(header: types[key]!.name, options: byType[key]!.toIList()),
  ].toIList();
}

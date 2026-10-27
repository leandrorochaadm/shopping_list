import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'barcode.dart';
import 'packaging.dart';
import 'product_registration.dart';
import 'scale_label.dart';

/// The LEAF: a registration plus one packaging. It is what a purchase points
/// at, and where price and history live.
///
/// **The leaf exists even when the product is sold by weight** (decision B1):
/// ground beef has no "350 ml", so [packaging] is null and the purchase still
/// has a single kind of target. The alternative — pointing sometimes at the
/// registration, sometimes at the leaf — would double every price query,
/// every report and every store comparison.
final class Product {
  const Product({
    this.id,
    required this.productRegistrationId,
    this.packaging,
    this.active = true,
    this.barcodes = const IList.empty(),
    this.scaleCodes = const IList.empty(),
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rows =
        (json[barcodesKey] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Product(
      id: json['id'] as String?,
      productRegistrationId: json['product_registration_id'] as String,
      packaging: Packaging.fromLeafJson(json),
      active: json['active'] as bool? ?? true,
      barcodes: [
        for (final row in rows)
          if (!ScaleCode.isScaleCodeRow(row))
            Barcode.fromJson(row[ScaleCode.codeKey] as String),
      ].lock,
      scaleCodes: [
        for (final row in rows)
          if (ScaleCode.isScaleCodeRow(row)) ScaleCode.fromJson(row),
      ].lock,
    );
  }

  /// The key of the embed in the PostgREST row (it is the table's name).
  static const barcodesKey = 'product_barcode';

  final String? id;

  final String productRegistrationId;

  /// Null for a product sold by weight — and only for those.
  final Packaging? packaging;

  /// Its own `active` (decision 23): this is what "deactivate the packaging"
  /// reaches, without touching the registration above it.
  final bool active;

  /// The packaging codes: the rows of `product_barcode` with no store.
  final IList<Barcode> barcodes;

  /// The codes a store gives this leaf on its scale, one per (store, item).
  final IList<ScaleCode> scaleCodes;

  /// The codes are left out: they live in another table, and the purchase
  /// draft spreads this map. They exist to FIND the option, not to remember it.
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_registration_id': productRegistrationId,
    ...?packaging?.toJson(),
    'active': active,
  };

  bool get isSoldByWeight => packaging == null;

  /// Only a leaf WITH a packaging takes barcodes; the loose (by weight) leaf
  /// keeps scale codes, edited on screen 4. It is what the pencil of the
  /// maintenance asks before showing the code block.
  bool get acceptsBarcodes => packaging != null;

  /// Is the leaf on the shelf? `handoff §H10` is explicit: "desativar o
  /// produto desativa o cadastro e, com ele, todas as folhas". A leaf is
  /// inactive when IT or its registration is — a `&&` on the READ (D7), and
  /// not a second write that would have to walk the leaves one by one and
  /// that nobody would know how to undo.
  ///
  /// `fetchProductOptions` already filters both flags in SQL and does not
  /// change. What asks this is the maintenance screen, and any list that
  /// loads leaves without that filter.
  bool isEffectivelyActiveIn(ProductRegistration registration) =>
      active && registration.active;

  /// Two leaves of the same registration are the same packaging when they
  /// hold the same amount — "1 × 0,35 L" and "1 × 350 ml" included. A
  /// weight-sold leaf has no content, and a registration may only have one.
  bool hasSameContentAs(Product other) {
    if (productRegistrationId != other.productRegistrationId) return false;
    final mine = packaging;
    final theirs = other.packaging;
    if (mine == null || theirs == null) return mine == null && theirs == null;
    return mine.hasSameContentAs(theirs);
  }

  /// The same packaging never keeps the same code twice.
  Product withBarcode(Barcode code) {
    if (barcodes.contains(code)) throw const BarcodeAlreadyOnPackaging();
    return copyWith(barcodes: barcodes.add(code));
  }

  Product withoutBarcode(Barcode code) =>
      copyWith(barcodes: barcodes.remove(code));

  Product deactivated() => copyWith(active: false);

  Product reactivated() => copyWith(active: true);

  Product copyWith({
    String? id,
    String? productRegistrationId,
    Packaging? packaging,
    bool? active,
    IList<Barcode>? barcodes,
    IList<ScaleCode>? scaleCodes,
  }) => Product(
    id: id ?? this.id,
    productRegistrationId: productRegistrationId ?? this.productRegistrationId,
    packaging: packaging ?? this.packaging,
    active: active ?? this.active,
    barcodes: barcodes ?? this.barcodes,
    scaleCodes: scaleCodes ?? this.scaleCodes,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == id &&
          other.productRegistrationId == productRegistrationId &&
          other.packaging == packaging &&
          other.active == active &&
          other.barcodes == barcodes &&
          other.scaleCodes == scaleCodes);

  @override
  int get hashCode => Object.hash(
    id,
    productRegistrationId,
    packaging,
    active,
    barcodes,
    scaleCodes,
  );

  @override
  String toString() =>
      'Product(${packaging?.label ?? 'a peso'}, active: $active)';
}

/// The packaging already has this code.
final class BarcodeAlreadyOnPackaging implements Exception {
  const BarcodeAlreadyOnPackaging();

  String get message => 'Esse código já está nesta embalagem.';

  @override
  String toString() => 'BarcodeAlreadyOnPackaging: $message';
}

/// The packaging code that [raw] gives; a whole scale label throws
/// [InStoreBarcode], the rest goes through [Barcode.typed].
Barcode packagingCodeOf(String raw) {
  // The whole scale label (QR or EAN-13) is a scale code, not "invalid":
  // its 20-digit QR would otherwise fall to the length check.
  if (ScaleLabel.parse(raw) != null) throw const InStoreBarcode();
  return Barcode.typed(raw);
}

/// The codes of ONE packaging after [raw] goes in.
///
/// Throws [InStoreBarcode], [InvalidBarcode] or [BarcodeAlreadyOnPackaging];
/// whoever calls shows `e.message`. It is the rule of the card on screen 4,
/// where the packaging is not a [Product] yet.
IList<Barcode> packagingCodesWith(IList<Barcode> codes, String raw) {
  final code = packagingCodeOf(raw);
  // `Barcode` is normalized: UPC-A and EAN-13 of one number are the same.
  if (codes.contains(code)) throw const BarcodeAlreadyOnPackaging();
  return codes.add(code);
}

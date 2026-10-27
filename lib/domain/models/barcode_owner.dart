import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'barcode.dart';
import 'brand.dart';
import 'product.dart';
import 'product_registration.dart';
import 'product_type.dart';

/// Who holds a packaging code: the leaf, and everything the screen needs to
/// name it in a sentence ("Esse código já é do Guaraná 2L.").
final class BarcodeOwner {
  const BarcodeOwner({
    required this.product,
    required this.registration,
    required this.type,
    this.brand,
  });

  /// Reads the leaf with its registration nested, the same shape
  /// `ProductOption.fromJson` reads. The embed of an owner does not carry
  /// `product_barcode`, so `product.barcodes` comes back empty.
  factory BarcodeOwner.fromJson(Map<String, dynamic> json) {
    final registration = json[registrationKey] as Map<String, dynamic>;
    final brand = registration[brandKey] as Map<String, dynamic>?;

    return BarcodeOwner(
      product: Product.fromJson(json),
      registration: ProductRegistration.fromJson(registration),
      type: ProductType.fromJson(registration[typeKey] as Map<String, dynamic>),
      brand: brand == null ? null : Brand.fromJson(brand),
    );
  }

  /// The keys of the nested map the `_remote` builds from the PocketBase `expand`.
  static const registrationKey = 'product_registration';
  static const typeKey = 'product_type';
  static const brandKey = 'brand';

  final Product product;
  final ProductRegistration registration;
  final ProductType type;
  final Brand? brand;

  /// The leaf AND its registration are on the shelf.
  bool get isActive => product.isEffectivelyActiveIn(registration);

  /// Type + brand + description + packaging. Not `labelWith`: without brand
  /// and description it answers 'Sem marca', and the sentence would read
  /// "Esse código já é do Sem marca 30 m."
  String get label => [
    type.name,
    ?brand?.name,
    if (registration.description.isNotEmpty) registration.description,
    ?product.packaging?.label,
  ].join(' ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BarcodeOwner &&
          other.product == product &&
          other.registration == registration &&
          other.type == type &&
          other.brand == brand);

  @override
  int get hashCode => Object.hash(product, registration, type, brand);

  @override
  String toString() => 'BarcodeOwner($label, active: $isActive)';
}

/// Why a set of codes cannot be saved as it is.
sealed class BarcodeConflict {
  const BarcodeConflict();

  Barcode get code;
}

/// The same code twice on the screen — a mistake of the screen, found before
/// the database is asked.
final class RepeatedOnScreen extends BarcodeConflict {
  const RepeatedOnScreen(this.code);

  @override
  final Barcode code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepeatedOnScreen && other.code == code);

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'RepeatedOnScreen($code)';
}

/// The code already belongs to an ACTIVE leaf.
final class TakenByActive extends BarcodeConflict {
  const TakenByActive({required this.code, required this.owner});

  @override
  final Barcode code;
  final BarcodeOwner owner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TakenByActive && other.code == code && other.owner == owner);

  @override
  int get hashCode => Object.hash(code, owner);

  @override
  String toString() => 'TakenByActive($code, $owner)';
}

/// The first conflict of [codes], or null. A code held by a deactivated owner
/// is not a conflict, and neither is one held by [ownProductId] itself.
BarcodeConflict? conflictOf(
  IList<Barcode> codes,
  IMap<Barcode, BarcodeOwner> owners, {
  String? ownProductId,
}) {
  final duplicate = Barcode.findDuplicateIn(codes);
  if (duplicate != null) return RepeatedOnScreen(duplicate);

  for (final code in codes) {
    final owner = owners[code];
    if (owner != null && owner.isActive && owner.product.id != ownProductId) {
      return TakenByActive(code: code, owner: owner);
    }
  }
  return null;
}

/// The codes whose owner is deactivated: what the save has to release with
/// `removeBarcode` before writing the new holder.
IMap<Barcode, BarcodeOwner> inactiveHoldersOf(
  IList<Barcode> codes,
  IMap<Barcode, BarcodeOwner> owners, {
  String? ownProductId,
}) => {
  for (final code in codes)
    if (owners[code] case final owner?
        when !owner.isActive && owner.product.id != ownProductId)
      code: owner,
}.lock;

/// The sentence for a [conflict]. Lives here, with the rule that finds it:
/// three ViewModels and four screens show it.
String barcodeConflictMessage(BarcodeConflict conflict) => switch (conflict) {
  RepeatedOnScreen() => 'Esse código já está em outra embalagem desta tela.',
  TakenByActive(:final owner) => 'Esse código já é do ${owner.label}.',
};

/// What the user reads after a code was released from a deactivated [owner].
String releasedBarcodeMessage(BarcodeOwner owner) =>
    'Esse código era do ${owner.label}, que está desativado. Agora é deste.';

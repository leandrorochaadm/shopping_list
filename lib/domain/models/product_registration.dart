import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'name_normalization.dart';
import 'packaging.dart';

/// How the product is bought — and it is a property of the REGISTRATION, not
/// of the type (decision B4).
///
/// The wireframe puts it on screen 4 between Unit and Brand, and it holds in
/// any base unit: bulk olive oil is measured in litres and is still sold by
/// weight. Hanging it on the type would force "mussarela em pacote" and
/// "mussarela do balcão" into two different types, splitting the per-type
/// total that every report is built on.
enum SellingMode {
  byWeight,
  byPiece;

  static SellingMode fromJson(String value) => switch (value) {
    'by_weight' => SellingMode.byWeight,
    'by_piece' => SellingMode.byPiece,
    _ => throw ArgumentError.value(value, 'selling_mode'),
  };

  String toJson() => switch (this) {
    SellingMode.byWeight => 'by_weight',
    SellingMode.byPiece => 'by_piece',
  };
}

/// **`tipo + marca + descrição`** — the thing that must not repeat, and where
/// the duplicate guard answers the user.
///
/// The description is free text and NEVER null: an empty description is a
/// value, and it is what tells "Coca-Cola" from "Coca-Cola zero".
final class ProductRegistration {
  factory ProductRegistration({
    String? id,
    required String productTypeId,
    String? brandId,
    String description = '',
    required SellingMode sellingMode,
    bool active = true,
  }) => ProductRegistration._(
    id: id,
    productTypeId: productTypeId,
    brandId: brandId,
    description: description.trim(),
    sellingMode: sellingMode,
    active: active,
  );

  const ProductRegistration._({
    this.id,
    required this.productTypeId,
    required this.brandId,
    required this.description,
    required this.sellingMode,
    required this.active,
  });

  factory ProductRegistration.fromJson(Map<String, dynamic> json) =>
      ProductRegistration(
        id: json['id'] as String?,
        productTypeId: json['product_type_id'] as String,
        brandId: json['brand_id'] as String?,
        description: json['description'] as String? ?? '',
        sellingMode: SellingMode.fromJson(json['selling_mode'] as String),
        active: json['active'] as bool? ?? true,
      );

  final String? id;

  final String productTypeId;

  /// Null is "Sem marca" (decision B2) — a real answer, not missing data.
  final String? brandId;

  /// Never null, always trimmed, possibly ''.
  final String description;

  final SellingMode sellingMode;

  final bool active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_type_id': productTypeId,
    'brand_id': brandId,
    'description': description,
    'selling_mode': sellingMode.toJson(),
    'active': active,
  };

  bool get isSoldByWeight => sellingMode == SellingMode.byWeight;

  /// The identity of decision "cadastro único": type + brand + normalized
  /// description, with a null brand counting as a value.
  ///
  /// This is the Dart mirror of the `NULLS NOT DISTINCT` unique index — and
  /// it is the app, not the index, that has to answer the user.
  bool hasSameIdentityAs(ProductRegistration other) =>
      productTypeId == other.productTypeId &&
      brandId == other.brandId &&
      normalizeName(description) == normalizeName(other.description);

  /// The duplicate guard for registrations, INCLUDING the deactivated ones
  /// (decision B3): a deactivated "Coca-Cola 2 L" blocks a new one, and the
  /// screen offers to reactivate it.
  ProductRegistration? conflictIn(Iterable<ProductRegistration> existing) {
    for (final entry in existing) {
      if (hasSameIdentityAs(entry)) return entry;
    }
    return null;
  }

  /// The two rules the selling mode carries, and they are opposites:
  ///
  /// * sold BY PIECE with no packaging is refused — without one there is no
  ///   way to convert what the receipt says into the base unit;
  /// * sold BY WEIGHT with packaging is refused — the whole list disappears
  ///   from the screen, so a row arriving here means the screen kept state it
  ///   should have dropped.
  void checkPackagings(IList<Packaging> packagings) {
    if (isSoldByWeight && packagings.isNotEmpty) {
      throw const UnexpectedPackaging();
    }
    if (!isSoldByWeight && packagings.isEmpty) {
      throw const MissingPackaging();
    }
  }

  ProductRegistration deactivated() => copyWith(active: false);

  ProductRegistration reactivated() => copyWith(active: true);

  ProductRegistration copyWith({
    String? id,
    String? productTypeId,
    String? brandId,
    String? description,
    SellingMode? sellingMode,
    bool? active,
  }) => ProductRegistration(
    id: id ?? this.id,
    productTypeId: productTypeId ?? this.productTypeId,
    // Null is a value here, so `??` cannot be used to clear it: a caller that
    // wants "Sem marca" passes an empty string.
    brandId: brandId == null
        ? this.brandId
        : (brandId.isEmpty ? null : brandId),
    description: description ?? this.description,
    sellingMode: sellingMode ?? this.sellingMode,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductRegistration &&
          other.id == id &&
          other.productTypeId == productTypeId &&
          other.brandId == brandId &&
          other.description == description &&
          other.sellingMode == sellingMode &&
          other.active == active);

  @override
  int get hashCode => Object.hash(
    id,
    productTypeId,
    brandId,
    description,
    sellingMode,
    active,
  );

  @override
  String toString() =>
      'ProductRegistration(type: $productTypeId, brand: $brandId, '
      '"$description", ${sellingMode.toJson()}, active: $active)';
}

/// Sold by piece and no packaging listed.
final class MissingPackaging implements Exception {
  const MissingPackaging();

  String get message => 'Informe ao menos uma embalagem para este produto.';

  @override
  String toString() => 'MissingPackaging: $message';
}

/// Sold loose and a packaging came along anyway.
///
/// The sentence says "solto" and not "a peso" because the same mode covers
/// both grandezas: bulk olive oil is `by_weight` and is measured in litres.
final class UnexpectedPackaging implements Exception {
  const UnexpectedPackaging();

  String get message => 'Produto vendido solto não tem embalagem.';

  @override
  String toString() => 'UnexpectedPackaging: $message';
}

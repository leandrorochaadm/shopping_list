import 'brand.dart';
import 'name_normalization.dart';

export 'registration_leaves.dart' show MissingPackaging, UnexpectedScaleCode;

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
    bool active = true,
  }) => ProductRegistration._(
    id: id,
    productTypeId: productTypeId,
    brandId: brandId,
    description: description.trim(),
    active: active,
  );

  const ProductRegistration._({
    this.id,
    required this.productTypeId,
    required this.brandId,
    required this.description,
    required this.active,
  });

  factory ProductRegistration.fromJson(Map<String, dynamic> json) => ProductRegistration(
    id: json['id'] as String?,
    productTypeId: json['product_type_id'] as String,
    brandId: json['brand_id'] as String?,
    description: json['description'] as String? ?? '',
    active: json['active'] as bool? ?? true,
  );

  final String? id;

  final String productTypeId;

  /// Null is "Sem marca" (decision B2) — a real answer, not missing data.
  final String? brandId;

  /// Never null, always trimmed, possibly ''.
  final String description;

  final bool active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_type_id': productTypeId,
    'brand_id': brandId,
    'description': description,
    'active': active,
  };

  /// What the item dialog and the list line write for this registration:
  /// 'Italac integral', 'Italac', 'integral' — or 'Sem marca' when there is
  /// neither, so the option never reads as a blank line.
  ///
  /// It takes the [Brand] because the registration only keeps [brandId]: the
  /// name lives in the catalog (in the dialog) or in the embed (on the line).
  String labelWith(Brand? brand) {
    final parts = [?brand?.name, if (description.isNotEmpty) description];
    return parts.isEmpty ? 'Sem marca' : parts.join(' ');
  }

  /// The identity of decision "cadastro único": type + brand + normalized
  /// description, with a null brand counting as a value.
  ///
  /// This is the Dart mirror of the `NULLS NOT DISTINCT` unique index — and
  /// it is the app, not the index, that has to answer the user.
  bool hasSameIdentityAs(ProductRegistration other) =>
      productTypeId == other.productTypeId &&
      brandId == other.brandId &&
      normalizeName(description) == normalizeName(other.description);

  /// Whether saving this over [original] writes anything to the identity.
  ///
  /// RAW comparison, on purpose — not [hasSameIdentityAs]: "acem" corrected to
  /// "acém" is the same identity for the duplicate guard and still an edit the
  /// person wants saved.
  bool changesIdentityOf(ProductRegistration original) =>
      productTypeId != original.productTypeId || brandId != original.brandId || description != original.description;

  /// The duplicate guard for registrations, INCLUDING the deactivated ones
  /// (decision B3): a deactivated "Coca-Cola 2 L" blocks a new one, and the
  /// screen offers to reactivate it.
  ProductRegistration? conflictIn(Iterable<ProductRegistration> existing) {
    for (final entry in existing) {
      if (hasSameIdentityAs(entry)) return entry;
    }
    return null;
  }

  ProductRegistration deactivated() => copyWith(active: false);

  ProductRegistration reactivated() => copyWith(active: true);

  ProductRegistration copyWith({
    String? id,
    String? productTypeId,
    String? brandId,
    String? description,
    bool? active,
  }) => ProductRegistration(
    id: id ?? this.id,
    productTypeId: productTypeId ?? this.productTypeId,
    // Null is a value here, so `??` cannot be used to clear it: a caller that
    // wants "Sem marca" passes an empty string.
    brandId: brandId == null ? this.brandId : (brandId.isEmpty ? null : brandId),
    description: description ?? this.description,
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
          other.active == active);

  @override
  int get hashCode => Object.hash(id, productTypeId, brandId, description, active);

  @override
  String toString() =>
      'ProductRegistration(type: $productTypeId, brand: $brandId, '
      '"$description", active: $active)';
}

/// The sentence of the registration duplicate guard. Deactivated or not
/// changes the sentence (decision B3), never whether it blocks.
String registrationConflictMessage(ProductRegistration conflict) =>
    conflict.active ? 'Já existe esse produto cadastrado.' : 'Esse produto já existe, mas está desativado.';

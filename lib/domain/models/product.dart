import 'packaging.dart';

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
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String?,
    productRegistrationId: json['product_registration_id'] as String,
    packaging: json['total_content'] == null
        ? null
        : Packaging.fromJson(json),
    active: json['active'] as bool? ?? true,
  );

  final String? id;

  final String productRegistrationId;

  /// Null for a product sold by weight — and only for those.
  final Packaging? packaging;

  /// Its own `active` (decision 23): this is what "deactivate the packaging"
  /// reaches, without touching the registration above it.
  final bool active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_registration_id': productRegistrationId,
    ...?packaging?.toJson(),
    'active': active,
  };

  bool get isSoldByWeight => packaging == null;

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

  Product deactivated() => copyWith(active: false);

  Product reactivated() => copyWith(active: true);

  Product copyWith({
    String? id,
    String? productRegistrationId,
    Packaging? packaging,
    bool? active,
  }) => Product(
    id: id ?? this.id,
    productRegistrationId: productRegistrationId ?? this.productRegistrationId,
    packaging: packaging ?? this.packaging,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == id &&
          other.productRegistrationId == productRegistrationId &&
          other.packaging == packaging &&
          other.active == active);

  @override
  int get hashCode =>
      Object.hash(id, productRegistrationId, packaging, active);

  @override
  String toString() =>
      'Product(${packaging?.label ?? 'a peso'}, active: $active)';
}

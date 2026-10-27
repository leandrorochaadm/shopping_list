import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'product.dart';
import 'product_registration.dart';

/// The purchase count per product type: the count per product (from the
/// `purchase_item_totals` view) added up through the catalog.
///
/// A type with no purchase is ABSENT from the map — readers do
/// `counts[id] ?? 0`. Products and registrations that cannot be placed are
/// ignored, and `active` is not filtered: the old view counted everything.
IMap<String, int> purchaseCountsByType({
  required IList<Product> products,
  required IList<ProductRegistration> registrations,
  required IMap<String, int> countByProduct,
}) {
  final typeByRegistration = <String, String>{
    for (final registration in registrations)
      if (registration.id != null) registration.id!: registration.productTypeId,
  };

  final totals = <String, int>{};
  for (final product in products) {
    final id = product.id;
    if (id == null) continue;
    final count = countByProduct[id] ?? 0;
    if (count <= 0) continue;
    final typeId = typeByRegistration[product.productRegistrationId];
    if (typeId == null) continue;
    totals[typeId] = (totals[typeId] ?? 0) + count;
  }
  return totals.toIMap();
}

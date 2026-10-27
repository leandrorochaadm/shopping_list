import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/purchase_count.dart';

ProductRegistration registration(
  String? id,
  String typeId, {
  bool active = true,
}) => ProductRegistration(
  id: id,
  productTypeId: typeId,
  sellingMode: SellingMode.byPiece,
  active: active,
);

Product product(String? id, String registrationId, {bool active = true}) =>
    Product(id: id, productRegistrationId: registrationId, active: active);

final registrations = [
  registration('r1', 'milk'),
  registration('r2', 'milk'),
  registration('r3', 'rice'),
  registration('r4', 'beans'),
].toIList();

final products = [
  product('p1', 'r1'),
  product('p2', 'r1'),
  product('p3', 'r2'),
  product('p4', 'r3'),
  product('p5', 'r4'),
].toIList();

void main() {
  test('sums every product of every registration into its type', () {
    final counts = purchaseCountsByType(
      products: products,
      registrations: registrations,
      countByProduct: {'p1': 2, 'p2': 3, 'p3': 4, 'p4': 1}.toIMap(),
    );
    expect(counts['milk'], 9);
    expect(counts['rice'], 1);
  });

  test('leaves out a type with no purchase', () {
    final counts = purchaseCountsByType(
      products: products,
      registrations: registrations,
      countByProduct: {'p1': 2}.toIMap(),
    );
    expect(counts.containsKey('beans'), isFalse);
    expect(counts.containsKey('rice'), isFalse);
  });

  test('returns an empty map when nothing was bought', () {
    expect(
      purchaseCountsByType(
        products: products,
        registrations: registrations,
        countByProduct: const IMapConst({}),
      ),
      isEmpty,
    );
  });

  test('ignores products and counts it cannot place', () {
    final counts = purchaseCountsByType(
      products: [
        product(null, 'r1'),
        product('p9', 'unknown'),
        product('p10', 'r-null'),
        product('p5', 'r4'),
        ...products,
      ].toIList(),
      registrations: [registration(null, 'ghost'), ...registrations].toIList(),
      countByProduct: {
        'p9': 5,
        'p10': 5,
        'orphan': 7,
        'p5': 0,
        'p1': 1,
      }.toIMap(),
    );
    expect(counts.unlock, {'milk': 1});
  });

  test('counts deactivated products and registrations', () {
    final counts = purchaseCountsByType(
      products: [product('p1', 'r1', active: false)].toIList(),
      registrations: [registration('r1', 'milk', active: false)].toIList(),
      countByProduct: {'p1': 3}.toIMap(),
    );
    expect(counts['milk'], 3);
  });
}

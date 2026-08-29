import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_registration.dart';

/// The two pairs the catalog contract hands back. They were records until
/// 29/08/2026 and got their equality for free; written by hand, a forgotten
/// field is silent — Riverpod simply stops filtering the update.
void main() {
  ProductRegistration registration({String id = 'reg-1', String type = 't1'}) =>
      ProductRegistration(
        id: id,
        productTypeId: type,
        sellingMode: SellingMode.byPiece,
      );

  Product leaf({String id = 'prod-1', int pieceSize = 350}) => Product(
    id: id,
    productRegistrationId: 'reg-1',
    packaging: Packaging(
      pieceCount: 1,
      pieceSize: pieceSize,
      pieceSizeUnit: MeasureUnit.milliliter,
    ),
  );

  group('SavedRegistration', () {
    SavedRegistration saved({String regId = 'reg-1', String leafId = 'prod-1'}) =>
        SavedRegistration(
          registration: registration(id: regId),
          products: [leaf(id: leafId)].lock,
        );

    test('equality covers every field', () {
      expect(saved(), saved());
      expect(saved().hashCode, saved().hashCode);
      expect(saved(), isNot(saved(regId: 'reg-2')));
      expect(saved(), isNot(saved(leafId: 'prod-2')));
    });
  });

  group('TypeLeaf', () {
    TypeLeaf pair({String leafId = 'prod-1', String regId = 'reg-1'}) =>
        TypeLeaf(product: leaf(id: leafId), registration: registration(id: regId));

    test('equality covers every field', () {
      expect(pair(), pair());
      expect(pair().hashCode, pair().hashCode);
      expect(pair(), isNot(pair(leafId: 'prod-2')));
      expect(pair(), isNot(pair(regId: 'reg-2')));
    });
  });
}

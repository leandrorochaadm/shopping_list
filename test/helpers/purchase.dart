import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/brand.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/packaging.dart';
import 'package:shopping_list/domain/models/price_reference.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';

import 'catalog.dart';

/// The catalog H7's tests are written against, in ONE place — the same three
/// types `CatalogRepositoryLocal` and `ShoppingListRepositoryLocal` already
/// use, so a test that mixes a list, a catalog and a purchase does not have
/// to reconcile three different milks.
final drinks = Category(id: 'cat-1', name: 'Bebidas');
final meat = Category(id: 'cat-2', name: 'Carnes');
final cleaning = Category(id: 'cat-3', name: 'Limpeza');

final softDrinkType = ProductType(
  id: 'type-1',
  name: 'Refrigerante',
  categoryId: 'cat-1',
  baseUnit: BaseUnit.liter,
);
final beefType = ProductType(
  id: 'type-2',
  name: 'Acém moído',
  categoryId: 'cat-2',
  baseUnit: BaseUnit.kilogram,
);
final paperType = ProductType(
  id: 'type-3',
  name: 'Papel higiênico',
  categoryId: 'cat-3',
  baseUnit: BaseUnit.unit,
);
/// The second example of requirement 4: the type that adds up two brands.
final powderType = ProductType(
  id: 'type-4',
  name: 'Sabão em pó',
  categoryId: 'cat-3',
  baseUnit: BaseUnit.kilogram,
);

final cokeBrand = Brand(id: 'brand-1', name: 'Coca-Cola');
final omoBrand = Brand(id: 'brand-2', name: 'Omo');
final tixanBrand = Brand(id: 'brand-4', name: 'Tixan');

/// A leaf sold by piece: `pieceCount × pieceSize` of [unit].
ProductOption optionByPiece({
  required String id,
  ProductType? type,
  Brand? brand,
  String description = '',
  int pieceCount = 1,
  int pieceSize = 350,
  MeasureUnit unit = MeasureUnit.milliliter,
  int purchaseCount = 0,
  DateTime? lastPurchasedOn,
  PriceReference? priceReference,
}) {
  final resolved = type ?? softDrinkType;
  return ProductOption(
    product: Product(
      id: id,
      productRegistrationId: 'reg-$id',
      packaging: Packaging(
        pieceCount: pieceCount,
        pieceSize: pieceSize,
        pieceSizeUnit: unit,
      ),
    ),
    registration: ProductRegistration(
      id: 'reg-$id',
      productTypeId: resolved.id!,
      brandId: brand?.id,
      description: description,
      sellingMode: SellingMode.byPiece,
    ),
    type: resolved,
    brand: brand,
    purchaseCount: purchaseCount,
    lastPurchasedOn: lastPurchasedOn,
    priceReference: priceReference,
  );
}

/// A leaf sold by weight: no packaging at all (decision B1).
ProductOption optionByWeight({
  required String id,
  ProductType? type,
  Brand? brand,
  int purchaseCount = 0,
  DateTime? lastPurchasedOn,
  PriceReference? priceReference,
}) {
  final resolved = type ?? beefType;
  return ProductOption(
    product: Product(id: id, productRegistrationId: 'reg-$id'),
    registration: ProductRegistration(
      id: 'reg-$id',
      productTypeId: resolved.id!,
      brandId: brand?.id,
      sellingMode: SellingMode.byWeight,
    ),
    type: resolved,
    brand: brand,
    purchaseCount: purchaseCount,
    lastPurchasedOn: lastPurchasedOn,
    priceReference: priceReference,
  );
}

PurchaseItem purchaseItem({
  required String id,
  required ProductOption option,
  int quantity = 1,
  int cents = 600,
}) => PurchaseItem(
  id: id,
  option: option,
  quantity: quantity,
  paid: Money(cents),
);

/// A line of the list. [enteredOn] defaults to well before every purchase
/// date the tests use, so a test that does not care about decision 25 does
/// not have to state a day.
ShoppingListItem listItem({
  required String id,
  ProductType? type,
  Category? category,
  int? quantity,
  DateTime? enteredOn,
  bool picked = false,
  bool notFound = false,
  int writtenOffQuantity = 0,
  int writeOffCount = 0,
  DateTime? fulfilledOn,
  DateTime? removedOn,
}) => ShoppingListItem(
  id: id,
  type: type ?? softDrinkType,
  category: category ?? drinks,
  quantity: quantity,
  enteredOn: enteredOn ?? DateTime(2026, 8, 1),
  picked: picked,
  notFound: notFound,
  writtenOffQuantity: writtenOffQuantity,
  writeOffCount: writeOffCount,
  fulfilledOn: fulfilledOn,
  removedOn: removedOn,
);

/// The three overrides screen 3 needs, in ONE place — the purchase
/// repository, the draft box's fake, and the stores. Every widget test that
/// can reach `/purchases/new` needs all three, and the router test reaches it
/// just by enumerating the routes.
///
/// The latency is zero, not the fakes' 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay.
List<Override> purchaseOverrides({
  PurchaseRepository? purchases,
  PurchaseDraft? draft,
}) => [
  purchaseRepositoryProvider.overrideWith(
    (ref) => purchases ?? PurchaseRepositoryLocal(latency: Duration.zero),
  ),
  purchaseDraftRepositoryProvider.overrideWith(
    (ref) => PurchaseDraftRepositoryLocal(initial: draft),
  ),
  storeOverride(),
];

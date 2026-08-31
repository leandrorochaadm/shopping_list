import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/price_increase.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/domain/models/price_reference.dart';
import 'package:shopping_list/domain/models/product.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/product_registration.dart';
import 'package:shopping_list/domain/models/store.dart';

import 'purchase.dart';

/// The three stores of `StoreRepositoryLocal`, so a test that mixes a
/// comparison and a purchase does not have to reconcile two Carrefours.
///
/// The Mercearia is DEACTIVATED on purpose: buying there is a fact of the
/// past, and deactivating does not rewrite the past (requirement 16).
final carrefour = Store(id: 'store-1', name: 'Carrefour');
final streetMarket = Store(id: 'store-2', name: 'Feira do Bairro');
final grocery = Store(id: 'store-3', name: 'Mercearia do Zé', active: false);

/// The crate of requirement 6: 12 × 350 ml, 4200 ml a purchase.
final cokeCrate = optionByPiece(
  id: 'prod-4',
  brand: cokeBrand,
  pieceCount: 12,
);

/// The single can of the same type — what makes "Tipo inteiro" answer
/// something different from "Este produto".
final cokeCan = optionByPiece(id: 'prod-1', brand: cokeBrand);

/// Sold by weight and with NO brand: the leaf whose H15 comparison climbs to
/// the type, and whose H16 "Este produto" does NOT (decision D-v).
final groundBeef = optionByWeight(id: 'prod-5');

/// A SECOND leaf of the same type as [groundBeef] — what proves "Este
/// produto" stays on the leaf and only "Tipo inteiro" puts the two together.
final otherBeefLeaf = optionByWeight(id: 'prod-6');

/// A leaf that was never written — no id at all. The picker cannot offer it,
/// and nothing compares against it.
final unsavedLeaf = ProductOption(
  product: const Product(productRegistrationId: 'reg-x'),
  registration: ProductRegistration(
    productTypeId: softDrinkType.id!,
    brandId: cokeBrand.id,
    sellingMode: SellingMode.byWeight,
  ),
  type: softDrinkType,
  brand: cokeBrand,
);

/// One purchase of one leaf in one store.
PriceQuote quote({
  ProductOption? option,
  Store? store,
  required int quantity,
  required int cents,
  required DateTime on,
  String categoryId = 'cat-1',
  String categoryName = 'Bebidas',
}) => PriceQuote(
  option: option ?? cokeCrate,
  categoryId: categoryId,
  categoryName: categoryName,
  store: store ?? carrefour,
  price: PriceReference(
    paid: Money(cents),
    quantityInBaseUnit: quantity,
    purchasedOn: on,
  ),
);

/// A quote of the meat category, so the picker has two groups to sort.
PriceQuote meatQuote({
  ProductOption? option,
  Store? store,
  required int quantity,
  required int cents,
  required DateTime on,
}) => quote(
  option: option ?? groundBeef,
  store: store,
  quantity: quantity,
  cents: cents,
  on: on,
  categoryId: 'cat-2',
  categoryName: 'Carnes',
);

/// The window average of H15, written as the pair it is.
PriceBaseline baseline({required int cents, required int quantity}) =>
    PriceBaseline(paid: Money(cents), quantityInBaseUnit: quantity);

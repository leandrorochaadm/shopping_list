import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';

import '../helpers/purchase.dart';

void main() {
  final leaf = optionByPiece(id: 'prod-1');

  PurchaseItem fromCheckout() => purchaseItem(
    id: 'item-1',
    option: leaf,
    quantity: 3,
    cents: 500,
    priceOrigin: PriceOrigin.lastPurchase,
  );

  test('confirmedPrice turns lastPurchase into typed and keeps the rest', () {
    final confirmed = fromCheckout().confirmedPrice();
    expect(confirmed.priceOrigin, PriceOrigin.typed);
    expect(confirmed.id, 'item-1');
    expect(confirmed.quantity, 3);
    expect(confirmed.paid.cents, 500);
  });

  test('confirmedPrice of a typed line is the same line', () {
    final typed = purchaseItem(id: 'item-1', option: leaf);
    expect(typed.confirmedPrice(), typed);
  });

  test('isPriceUnconfirmed is true only for lastPurchase', () {
    expect(fromCheckout().isPriceUnconfirmed, isTrue);
    expect(purchaseItem(id: 'a', option: leaf).isPriceUnconfirmed, isFalse);
  });

  test('the origin defaults to typed', () {
    expect(purchaseItem(id: 'a', option: leaf).priceOrigin, PriceOrigin.typed);
  });

  test('copyWith keeps the origin', () {
    final edited = fromCheckout().copyWith(quantity: 4);
    expect(edited.priceOrigin, PriceOrigin.lastPurchase);
    expect(edited.id, 'item-1');
  });

  test('toJson has no price_origin', () {
    expect(fromCheckout().toJson().containsKey('price_origin'), isFalse);
  });

  test('the draft json carries the origin and reads back equal', () {
    final json = fromCheckout().toDraftJson();
    expect(json['price_origin'], 'last_purchase');
    expect(PurchaseItem.fromJson(json), fromCheckout());
  });

  test('a draft stored before the field reads typed', () {
    final json = fromCheckout().toDraftJson()..remove('price_origin');
    expect(PurchaseItem.fromJson(json).priceOrigin, PriceOrigin.typed);
  });

  test('an unknown origin reads lastPurchase', () {
    final json = fromCheckout().toDraftJson()
      ..['price_origin'] = 'from_the_future';
    expect(PurchaseItem.fromJson(json).priceOrigin, PriceOrigin.lastPurchase);
  });

  test('fromApi round-trips every apiValue', () {
    for (final origin in PriceOrigin.values) {
      expect(PriceOrigin.fromApi(origin.apiValue), origin);
    }
  });

  test('lastPurchase stays first: it is the fromApi default', () {
    expect(PriceOrigin.values.first, PriceOrigin.lastPurchase);
  });

  test('equality covers the origin', () {
    final typed = fromCheckout().confirmedPrice();
    expect(typed, isNot(fromCheckout()));
    expect(typed.hashCode, isNot(fromCheckout().hashCode));
    expect(fromCheckout().hashCode, fromCheckout().hashCode);
  });
}

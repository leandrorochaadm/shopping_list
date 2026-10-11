import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/scan_resolution.dart';

import '../helpers/purchase.dart';

void main() {
  final leaf = optionByPiece(id: 'prod-1');
  final draft = PurchaseDraft(
    purchaseId: 'p-1',
    date: DateTime(2026, 10, 10),
    registeredBy: 'Ana',
  );

  PurchaseDraft withItems(PurchaseDraft base) => base.copyWith(
    items: [
      purchaseItem(
        id: 'a',
        option: leaf,
        priceOrigin: PriceOrigin.lastPurchase,
      ),
      purchaseItem(id: 'b', option: leaf, cents: 700),
      purchaseItem(
        id: 'c',
        option: leaf,
        cents: 900,
        priceOrigin: PriceOrigin.lastPurchase,
      ),
    ].lock,
  );

  test('unconfirmedPrices counts only the lastPurchase lines', () {
    expect(withItems(draft).unconfirmedPrices, 2);
  });

  test('an empty draft has none', () {
    expect(draft.unconfirmedPrices, 0);
  });

  test('allPricesConfirmed zeroes the count and keeps order, ids and paid', () {
    final before = withItems(draft);
    final after = before.allPricesConfirmed();
    expect(after.unconfirmedPrices, 0);
    expect(after.items.map((item) => item.id).toList(), ['a', 'b', 'c']);
    expect(after.items.map((item) => item.paid).toList(), [
      for (final item in before.items) item.paid,
    ]);
    expect(after.items[1], before.items[1]);
  });

  test('the origin of every line survives toJson/fromJson', () {
    final before = withItems(draft);
    final back = PurchaseDraft.fromJson(before.toJson());
    expect(back, before);
    expect(back.unconfirmedPrices, 2);
  });

  group('storeAdoptedFrom', () {
    final scale = ScaleMatch(option: leaf, storeId: 'store-9', quantity: 160);

    test('a draft with no store adopts the one of the label', () {
      expect(draft.storeAdoptedFrom(scale), 'store-9');
    });

    test('a chosen store is never replaced', () {
      expect(
        draft.copyWith(storeId: 'store-1').storeAdoptedFrom(scale),
        isNull,
      );
    });

    test('a packaging read adopts nothing', () {
      expect(draft.storeAdoptedFrom(PackagingMatch(option: leaf)), isNull);
    });
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/record_id.dart';
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

  test('startedOn draws a record id for the purchase', () {
    final draft = PurchaseDraft.startedOn(DateTime(2026, 8, 18), 'Leandro');
    expect(isRecordId(draft.purchaseId), isTrue);
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

  group('hasUnconfirmedPrices', () {
    test('true with exactly one line at the last purchase price', () {
      final one = draft.copyWith(
        items: [
          purchaseItem(
            id: 'a',
            option: leaf,
            priceOrigin: PriceOrigin.lastPurchase,
          ),
          purchaseItem(id: 'b', option: leaf, cents: 700),
        ].lock,
      );
      expect(one.hasUnconfirmedPrices, isTrue);
    });

    test('false when every price is typed', () {
      final typed = draft.copyWith(
        items: [purchaseItem(id: 'b', option: leaf, cents: 700)].lock,
      );
      expect(typed.hasUnconfirmedPrices, isFalse);
      expect(draft.hasUnconfirmedPrices, isFalse);
    });

    test('false after allPricesConfirmed', () {
      final confirmed = withItems(draft).allPricesConfirmed();
      expect(confirmed.hasUnconfirmedPrices, isFalse);
    });
  });

  group('withPriceConfirmed', () {
    test('confirms only the line with that id', () {
      final before = withItems(draft);
      final after = before.withPriceConfirmed('a');
      expect(after.items[0].priceOrigin, PriceOrigin.typed);
      expect(after.items[2].priceOrigin, PriceOrigin.lastPurchase);
      expect(before.unconfirmedPrices, 2);
      expect(after.unconfirmedPrices, 1);
    });

    test('keeps the order, the ids and what was paid', () {
      final before = withItems(draft);
      final after = before.withPriceConfirmed('a');
      expect(after.items.map((item) => item.id).toList(), ['a', 'b', 'c']);
      expect(after.items.map((item) => item.paid).toList(), [
        for (final item in before.items) item.paid,
      ]);
    });

    test('an unknown id changes nothing', () {
      final before = withItems(draft);
      expect(before.withPriceConfirmed('zzz'), before);
    });
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

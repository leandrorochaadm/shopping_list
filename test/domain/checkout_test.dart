import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/checkout.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/scan_resolution.dart';

import '../helpers/purchase.dart';

void main() {
  final can = optionByPiece(
    id: 'can',
    priceReference: reference(cents: 500, quantityInBaseUnit: 3 * 350),
  );
  final pack = optionByPiece(
    id: 'pack',
    pieceCount: 12,
    priceReference: reference(cents: 3000, quantityInBaseUnit: 4200),
  );
  final neverBought = optionByPiece(id: 'never');
  final cheese = optionByWeight(
    id: 'cheese',
    priceReference: reference(cents: 3000, quantityInBaseUnit: 1000),
  );
  final unpriced = optionByWeight(id: 'unpriced');

  CheckoutStep scan(ScanResolution resolution, [List<PurchaseItem>? items]) =>
      checkoutScan(resolution, (items ?? const <PurchaseItem>[]).lock);

  group('PackagingMatch', () {
    test('a new packaging is added with the last purchase price', () {
      final step = scan(PackagingMatch(option: can));
      expect(step, isA<ItemAdded>());
      final item = (step as ItemAdded).item;
      expect(item.quantity, 1);
      expect(item.paid, can.priceReference!.estimateFor(350));
      expect(item.priceOrigin, PriceOrigin.lastPurchase);
    });

    test('the same packaging increases the existing line', () {
      final line = purchaseItem(id: 'line', option: can, cents: 167);
      final step = scan(PackagingMatch(option: can), [line]);
      final item = (step as QuantityIncreased).item;
      expect(item.id, 'line');
      expect(item.quantity, 2);
      expect(item.paid.cents, 334);
    });

    test('the rule of three rounds half up: 3 for 5.00 -> 4 for 6.67', () {
      final line = purchaseItem(
        id: 'line',
        option: can,
        quantity: 3,
        cents: 500,
      );
      final step = scan(PackagingMatch(option: can), [line]);
      final item = (step as QuantityIncreased).item;
      expect(item.quantity, 4);
      expect(item.paid.cents, 667);
    });

    test('the origin of the line is kept when it grows', () {
      final fromCheckout = purchaseItem(
        id: 'a',
        option: can,
        priceOrigin: PriceOrigin.lastPurchase,
      );
      final typed = purchaseItem(id: 'a', option: can);
      final grownFromCheckout =
          scan(PackagingMatch(option: can), [fromCheckout])
              as QuantityIncreased;
      final grownTyped =
          scan(PackagingMatch(option: can), [typed]) as QuantityIncreased;
      expect(grownFromCheckout.item.priceOrigin, PriceOrigin.lastPurchase);
      expect(grownTyped.item.priceOrigin, PriceOrigin.typed);
    });

    test('a different packaging of the same registration is a new line', () {
      final line = purchaseItem(id: 'line', option: can);
      expect(scan(PackagingMatch(option: pack), [line]), isA<ItemAdded>());
    });

    test('with no price reference it needs a price', () {
      expect(
        scan(PackagingMatch(option: neverBought)),
        NeedsPrice(option: neverBought, quantity: 1),
      );
    });

    test('with no price reference but already in the cart it increases', () {
      final line = purchaseItem(id: 'line', option: neverBought, cents: 300);
      expect(
        scan(PackagingMatch(option: neverBought), [line]),
        isA<QuantityIncreased>(),
      );
    });
  });

  group('ScaleMatch', () {
    test('adds a line of the weighed grams', () {
      final step = scan(
        ScaleMatch(option: cheese, storeId: 's', quantity: 160),
      );
      final item = (step as ItemAdded).item;
      expect(item.quantity, 160);
      expect(item.paid, Money(480));
      expect(item.priceOrigin, PriceOrigin.lastPurchase);
    });

    test('the same label twice is two lines', () {
      final match = ScaleMatch(option: cheese, storeId: 's', quantity: 160);
      final first = (scan(match) as ItemAdded).item;
      final second = (scan(match, [first]) as ItemAdded).item;
      expect(second.id, isNot(first.id));
    });

    test('with no price reference it needs a price', () {
      expect(
        scan(ScaleMatch(option: unpriced, storeId: 's', quantity: 160)),
        NeedsPrice(option: unpriced, quantity: 160),
      );
    });

    test('with no weight it is an unknown label', () {
      expect(
        scan(ScaleMatch(option: cheese, storeId: 's', quantity: null)),
        const CheckoutUnknownLabel(),
      );
    });
  });

  group('the other resolutions', () {
    final code = Barcode.typed('7894900011517');

    test('NoMatch', () {
      expect(scan(NoMatch(code: code)), CheckoutNoMatch(code: code));
    });

    test('ScaleInManyStores', () {
      expect(
        scan(ScaleInManyStores(itemCode: '123', storeIds: ['a', 'b'].lock)),
        CheckoutScaleInManyStores(itemCode: '123', storeIds: ['a', 'b'].lock),
      );
    });

    test('ScaleUnlinked', () {
      expect(
        scan(const ScaleUnlinked(itemCode: '123', weightInGrams: 80)),
        const CheckoutScaleUnlinked(itemCode: '123', weightInGrams: 80),
      );
    });

    test('UnknownLabel', () {
      expect(scan(const UnknownLabel()), const CheckoutUnknownLabel());
    });

    test('InvalidScan', () {
      expect(scan(const InvalidScan()), const CheckoutInvalid());
    });
  });

  group('equality (rule 8)', () {
    final item = purchaseItem(id: 'a', option: can);
    final other = purchaseItem(id: 'b', option: can);
    final code = Barcode.typed('7894900011517');
    final otherCode = Barcode.typed('7891000100103');

    test('ItemAdded and QuantityIncreased', () {
      expect(ItemAdded(item: item), ItemAdded(item: item));
      expect(ItemAdded(item: item).hashCode, ItemAdded(item: item).hashCode);
      expect(ItemAdded(item: item), isNot(ItemAdded(item: other)));
      expect(QuantityIncreased(item: item), QuantityIncreased(item: item));
      expect(
        QuantityIncreased(item: item).hashCode,
        QuantityIncreased(item: item).hashCode,
      );
      expect(
        QuantityIncreased(item: item),
        isNot(QuantityIncreased(item: other)),
      );
      expect(ItemAdded(item: item), isNot(QuantityIncreased(item: item)));
    });

    test('NeedsPrice', () {
      final base = NeedsPrice(option: can, quantity: 1);
      expect(base, NeedsPrice(option: can, quantity: 1));
      expect(base.hashCode, NeedsPrice(option: can, quantity: 1).hashCode);
      expect(base, isNot(NeedsPrice(option: pack, quantity: 1)));
      expect(base, isNot(NeedsPrice(option: can, quantity: 2)));
    });

    test('CheckoutNoMatch', () {
      expect(CheckoutNoMatch(code: code), CheckoutNoMatch(code: code));
      expect(
        CheckoutNoMatch(code: code).hashCode,
        CheckoutNoMatch(code: code).hashCode,
      );
      expect(
        CheckoutNoMatch(code: code),
        isNot(CheckoutNoMatch(code: otherCode)),
      );
    });

    test('CheckoutScaleUnlinked', () {
      const base = CheckoutScaleUnlinked(itemCode: '1', weightInGrams: 5);
      expect(
        base,
        const CheckoutScaleUnlinked(itemCode: '1', weightInGrams: 5),
      );
      expect(
        base.hashCode,
        const CheckoutScaleUnlinked(itemCode: '1', weightInGrams: 5).hashCode,
      );
      expect(
        base,
        isNot(const CheckoutScaleUnlinked(itemCode: '2', weightInGrams: 5)),
      );
      expect(
        base,
        isNot(const CheckoutScaleUnlinked(itemCode: '1', weightInGrams: 6)),
      );
    });

    test('CheckoutScaleInManyStores', () {
      final base = CheckoutScaleInManyStores(
        itemCode: '1',
        storeIds: ['a'].lock,
      );
      expect(
        base,
        CheckoutScaleInManyStores(itemCode: '1', storeIds: ['a'].lock),
      );
      expect(
        base.hashCode,
        CheckoutScaleInManyStores(itemCode: '1', storeIds: ['a'].lock).hashCode,
      );
      expect(
        base,
        isNot(CheckoutScaleInManyStores(itemCode: '2', storeIds: ['a'].lock)),
      );
      expect(
        base,
        isNot(CheckoutScaleInManyStores(itemCode: '1', storeIds: ['b'].lock)),
      );
    });

    test('the const cases', () {
      expect(const CheckoutUnknownLabel(), const CheckoutUnknownLabel());
      expect(const CheckoutInvalid(), const CheckoutInvalid());
      expect(const CheckoutUnknownLabel(), isNot(const CheckoutInvalid()));
      expect(
        const CheckoutUnknownLabel().hashCode,
        const CheckoutUnknownLabel().hashCode,
      );
      expect(
        const CheckoutInvalid().hashCode,
        const CheckoutInvalid().hashCode,
      );
    });

    test('toString of every case', () {
      for (final step in <CheckoutStep>[
        ItemAdded(item: item),
        QuantityIncreased(item: item),
        NeedsPrice(option: can, quantity: 1),
        CheckoutNoMatch(code: code),
        const CheckoutScaleUnlinked(itemCode: '1', weightInGrams: 5),
        CheckoutScaleInManyStores(itemCode: '1', storeIds: ['a'].lock),
        const CheckoutUnknownLabel(),
        const CheckoutInvalid(),
      ]) {
        expect(step.toString(), isNotEmpty);
      }
    });
  });

  group('NeedsPrice.joining', () {
    test('the same leaf sold by piece sums', () {
      final joined = NeedsPrice(
        option: neverBought,
        quantity: 1,
      ).joining(NeedsPrice(option: neverBought, quantity: 1));
      expect(joined, NeedsPrice(option: neverBought, quantity: 2));
    });

    test('another leaf does not join', () {
      expect(
        NeedsPrice(
          option: neverBought,
          quantity: 1,
        ).joining(NeedsPrice(option: can, quantity: 1)),
        isNull,
      );
    });

    test('a label never joins', () {
      expect(
        NeedsPrice(
          option: unpriced,
          quantity: 160,
        ).joining(NeedsPrice(option: unpriced, quantity: 160)),
        isNull,
      );
    });
  });

  group('NeedsPrice.pricedAt', () {
    test('a packaging line pays the price of each one', () {
      final item = NeedsPrice(
        option: neverBought,
        quantity: 2,
      ).pricedAt(const Money(350))!;
      expect(item.quantity, 2);
      expect(item.paid, const Money(700));
      expect(item.priceOrigin, PriceOrigin.typed);
    });

    test('a label pays the price as typed', () {
      final item = NeedsPrice(
        option: unpriced,
        quantity: 160,
      ).pricedAt(const Money(512))!;
      expect(item.paid, const Money(512));
    });

    test('zero is refused', () {
      final need = NeedsPrice(option: neverBought, quantity: 1);
      expect(need.pricedAt(Money.zero), isNull);
      expect(need.pricedAt(const Money(1)), isNotNull);
    });
  });

  group('QuantityIncreased.addedPaid', () {
    test('gives what the last read added', () {
      final line = purchaseItem(id: 'line', option: pack, cents: 6200);
      final step = scan(PackagingMatch(option: pack), [line]);
      expect(
        (step as QuantityIncreased).addedPaid([line].lock),
        const Money(6200),
      );
    });

    test('without the line in before it is the whole line', () {
      final line = purchaseItem(id: 'line', option: pack, cents: 6200);
      final step = QuantityIncreased(item: line);
      expect(step.addedPaid(const IList<PurchaseItem>.empty()), line.paid);
    });
  });
}

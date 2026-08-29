import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/purchase.dart' show PurchasedAmount;
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/write_off_plan.dart';

import '../helpers/purchase.dart';

/// The write-off is the acceptance criterion of H7 that cannot be checked by
/// looking at a screen, so there is one test per criterion here — and the
/// date is fixed in every one of them, never `DateTime.now()`.
void main() {
  final purchaseDay = DateTime(2026, 8, 18);

  PurchasedAmount bought({
    String id = 'pi-1',
    String type = 'type-1',
    required int amount,
  }) => (
    purchaseItemId: id,
    productTypeId: type,
    quantityInBaseUnit: amount,
  );

  IList<ListWriteOff> plan({
    required List<PurchasedAmount> purchased,
    required List<ShoppingListItem> items,
    DateTime? on,
  }) => planWriteOffs(
    purchased: purchased.lock,
    listItems: items.lock,
    purchaseDate: on ?? purchaseDay,
  );

  test('an item with no quantity leaves on the first purchase of its type', () {
    final result = plan(
      purchased: [bought(amount: 2000)],
      items: [listItem(id: 'l1', quantity: null)],
    );

    expect(result.length, 1);
    expect(result.first.shoppingListItemId, 'l1');
    expect(result.first.quantityWrittenOff, 0);
    expect(result.first.fulfills, isTrue);
    expect(result.first.purchaseItemId, 'pi-1');
  });

  test('an item with no quantity does not steal from a quantified one', () {
    // The trap the first draft of the plan fell into. Giving the unquantified
    // line "all the amount available" would swallow the 2 L whole and leave
    // the 6 L line untouched — and in the reverse order it would get zero,
    // write no row and never leave the list.
    //
    // This test has to FAIL if anyone brings that behaviour back.
    final result = plan(
      purchased: [bought(amount: 2000)],
      items: [
        listItem(id: 'l1', quantity: null, enteredOn: DateTime(2026, 8, 1)),
        listItem(id: 'l2', quantity: 6000, enteredOn: DateTime(2026, 8, 2)),
      ],
    );

    final unquantified = result.firstWhere(
      (off) => off.shoppingListItemId == 'l1',
    );
    final quantified = result.firstWhere(
      (off) => off.shoppingListItemId == 'l2',
    );

    expect(unquantified.quantityWrittenOff, 0);
    expect(unquantified.fulfills, isTrue);
    // The whole 2 L went to the line that actually asked for litres.
    expect(quantified.quantityWrittenOff, 2000);
    expect(quantified.fulfills, isFalse, reason: '4 L still missing');
  });

  test('a partial purchase writes off and does not close the line', () {
    final result = plan(
      purchased: [bought(amount: 2000)],
      items: [listItem(id: 'l1', quantity: 6000)],
    );

    expect(result.length, 1);
    expect(result.first.quantityWrittenOff, 2000);
    expect(result.first.fulfills, isFalse);
  });

  test('the next partial purchase closes it', () {
    // The line already carries 2 L of trail; 4 L finish it.
    final result = plan(
      purchased: [bought(amount: 4000)],
      items: [listItem(id: 'l1', quantity: 6000, writtenOffQuantity: 2000)],
    );

    expect(result.length, 1);
    expect(result.first.quantityWrittenOff, 4000);
    expect(result.first.fulfills, isTrue);
  });

  test('a purchase dated earlier does not touch an item that entered after',
      () {
    // Decision 25. Without it a purchase registered late erases what the
    // other phone has just asked for.
    final result = plan(
      purchased: [bought(amount: 6000)],
      items: [listItem(id: 'l1', quantity: 6000, enteredOn: DateTime(2026, 8, 12))],
      on: DateTime(2026, 8, 10),
    );

    expect(result, isEmpty);
  });

  test('the limit: an item that entered on the purchase day IS written off',
      () {
    // "antes ou no mesmo dia" — the boundary, which is where decision 25
    // would break silently.
    final result = plan(
      purchased: [bought(amount: 6000)],
      items: [
        listItem(id: 'l1', quantity: 6000, enteredOn: DateTime(2026, 8, 18)),
      ],
    );

    expect(result.length, 1);
    expect(result.first.fulfills, isTrue);
  });

  test('"não encontrei" falls even on a partial purchase', () {
    final result = plan(
      purchased: [bought(amount: 2000)],
      items: [listItem(id: 'l1', quantity: 6000, notFound: true)],
    );

    expect(result.first.clearedNotFound, isTrue);
    expect(result.first.fulfills, isFalse, reason: 'partial, so it stays');
  });

  test('a picked item whose type nobody bought stays on the list', () {
    // Nothing is written about it — that IS how it stays. A row saying
    // "nothing happened" would be undone by H9 as if something had.
    final result = plan(
      purchased: [bought(amount: 2000, type: 'type-1')],
      items: [
        listItem(id: 'l1', type: beefType, quantity: 6000, picked: true),
      ],
    );

    expect(result, isEmpty);
  });

  test('brand and packaging do not filter — the type is what matters', () {
    // Asked for Italac, bought Piracanjuba: the line is written off all the
    // same. The preference is a reminder, not a condition.
    final result = plan(
      purchased: [bought(amount: 1000, type: 'type-2')],
      items: [listItem(id: 'l1', type: beefType, quantity: 1000)],
    );

    expect(result.length, 1);
    expect(result.first.fulfills, isTrue);
  });

  test('two lines of the same type: the oldest is served first', () {
    final result = plan(
      purchased: [bought(amount: 5000)],
      items: [
        listItem(id: 'l2', quantity: 4000, enteredOn: DateTime(2026, 8, 5)),
        listItem(id: 'l1', quantity: 4000, enteredOn: DateTime(2026, 8, 1)),
      ],
    );

    expect(result.length, 2);
    expect(result[0].shoppingListItemId, 'l1');
    expect(result[0].quantityWrittenOff, 4000);
    expect(result[0].fulfills, isTrue);

    expect(result[1].shoppingListItemId, 'l2');
    expect(result[1].quantityWrittenOff, 1000, reason: 'what was left');
    expect(result[1].fulfills, isFalse);
  });

  test('buying more than was asked for writes off no more than was asked', () {
    // No negative row, and no second row for the surplus.
    final result = plan(
      purchased: [bought(amount: 12000)],
      items: [listItem(id: 'l1', quantity: 6000)],
    );

    expect(result.length, 1);
    expect(result.first.quantityWrittenOff, 6000);
    expect(result.first.fulfills, isTrue);
  });

  test('a line already closed by a purchase is ignored', () {
    final result = plan(
      purchased: [bought(amount: 6000)],
      items: [
        listItem(id: 'l1', quantity: 6000, fulfilledOn: DateTime(2026, 8, 10)),
      ],
    );

    expect(result, isEmpty);
  });

  test('a line removed by hand is ignored too', () {
    // The other half of `isOpen`: removing by hand is a date now, and a
    // removed line must not come back through a write-off.
    final result = plan(
      purchased: [bought(amount: 6000)],
      items: [
        listItem(id: 'l1', quantity: 6000, removedOn: DateTime(2026, 8, 10)),
      ],
    );

    expect(result, isEmpty);
  });

  test('one type bought on two lines emits one row per pair that traded', () {
    // Italac AND Piracanjuba in the same purchase: H9 has to give back
    // exactly what EACH line took, so the rows are split by purchase item.
    final result = plan(
      purchased: [
        bought(id: 'pi-1', amount: 2000),
        bought(id: 'pi-2', amount: 3000),
      ],
      items: [listItem(id: 'l1', quantity: 6000)],
    );

    expect(result.length, 2);
    expect(result[0].purchaseItemId, 'pi-1');
    expect(result[0].quantityWrittenOff, 2000);
    expect(result[0].fulfills, isFalse);

    expect(result[1].purchaseItemId, 'pi-2');
    expect(result[1].quantityWrittenOff, 3000);
    expect(result[1].fulfills, isFalse, reason: '1 L still missing');
  });

  test('a purchase with nothing on the list plans nothing', () {
    expect(plan(purchased: [bought(amount: 2000)], items: []), isEmpty);
    expect(
      plan(purchased: [], items: [listItem(id: 'l1', quantity: 6000)]),
      isEmpty,
    );
  });

  group('ListWriteOff', () {
    test('travels with fulfills, which is a flag and not a column', () {
      const off = ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 2000,
        clearedNotFound: true,
        fulfills: true,
      );

      expect(off.toJson(), {
        'purchase_item_id': 'pi-1',
        'shopping_list_item_id': 'l1',
        'quantity_written_off': 2000,
        'cleared_not_found': true,
        // `create_purchase` reads this one and does NOT store it — the
        // migration's comment is the contract H9 will read.
        'fulfills': true,
      });
    });

    test('equality covers every field', () {
      const off = ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 2000,
      );

      expect(off, const ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 2000,
      ));
      expect(off.hashCode, const ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 2000,
      ).hashCode);
      expect(off, isNot(const ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 2000,
        fulfills: true,
      )));
      expect(off.toString(), contains('l1'));
    });
  });
}

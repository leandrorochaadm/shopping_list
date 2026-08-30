import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/purchase.dart' show PurchasedAmount;
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/write_off_plan.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';

import '../helpers/purchase.dart';

/// **The most important test of H9.** The twin of `write_off_plan_test.dart`,
/// which covers the way in with eleven cases: none of them is rewritten here.
/// What is written here is the way back, and the COMPOSITION of the two —
/// which is what a correction actually is.
///
/// Every date is fixed, never `DateTime.now()`.
void main() {
  final purchaseDay = DateTime(2026, 8, 18);

  ListWriteOff off({
    String purchaseItem = 'pi-1',
    required String item,
    required int amount,
    bool clearedNotFound = false,
  }) => ListWriteOff(
    purchaseItemId: purchaseItem,
    shoppingListItemId: item,
    quantityWrittenOff: amount,
    clearedNotFound: clearedNotFound,
  );

  UndoResult undo(List<ShoppingListItem> items, List<ListWriteOff> trail) =>
      undoWriteOffs(items.lock, trail.lock);

  // ── The undo itself ────────────────────────────────────────────────────

  test('reopens an item closed by a zero-amount write-off', () {
    // The item with NO quantity: the sum does not move when its row goes, so
    // only the COUNT can say it has to come back (D6).
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: null,
          writtenOffQuantity: 0,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 0)],
    );

    expect(result.items.single.fulfilledOn, isNull);
    expect(result.items.single.isOpen, isTrue);
    expect(result.restored, [
      const RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false),
    ]);
  });

  test('reopens an item whose balance turns positive again', () {
    // The item WITH a quantity: it closed when the sum reached what was
    // asked, and any deletion drops it below.
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 2,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 4000)],
    );

    expect(result.items.single.isOpen, isTrue);
    expect(result.items.single.remainingQuantity, 4000);
  });

  test("subtracts this purchase's trail from the written-off amount", () {
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 5000,
          writeOffCount: 3,
        ),
      ],
      [off(item: 'l1', amount: 2000), off(item: 'l1', amount: 1000)],
    );

    expect(result.items.single.writtenOffQuantity, 2000);
    expect(result.items.single.writeOffCount, 1);
    // It never closed, so nothing changed state and nothing goes to the SQL.
    expect(result.restored, isEmpty);
  });

  test('keeps an item closed by ANOTHER purchase closed', () {
    // Two trail rows, only one of them ours: the other purchase's row still
    // points at the item and its amount still covers what was asked.
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: 2000,
          writtenOffQuantity: 3000,
          writeOffCount: 2,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 1000)],
    );

    expect(result.items.single.fulfilledOn, purchaseDay);
    expect(result.restored, isEmpty);
  });

  test('puts the not-found mark back', () {
    // R14: the purchase knocked the `[!]` down, so undoing it puts it up.
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: null,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 0, clearedNotFound: true)],
    );

    expect(result.items.single.notFound, isTrue);
    expect(result.restored.single.notFound, isTrue);
    expect(result.restored.single.fulfilledOn, isNull);
  });

  test('does not restore an item removed by hand afterwards', () {
    // D1, and the whole reason the two columns are separate: the purchase can
    // only give back what IT took, and a human gesture in between wins.
    final removedOn = DateTime(2026, 8, 20);
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
          removedOn: removedOn,
        ),
      ],
      [off(item: 'l1', amount: 6000)],
    );

    expect(result.items.single.removedOn, removedOn);
    expect(result.items.single.isOpen, isFalse);
    // `fulfilled_on` still goes back to null — the trail that held it is
    // gone — but the line stays off the list because of `removed_on`.
    expect(result.items.single.fulfilledOn, isNull);
  });

  test('leaves untouched every item this purchase never wrote off', () {
    final untouched = listItem(id: 'l2', quantity: 4000, picked: true);
    final result = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
        untouched,
      ],
      [off(item: 'l1', amount: 6000)],
    );

    expect(result.items[1], untouched);
    expect(result.restored.map((r) => r.id), ['l1']);
  });

  test('returns nothing to restore when the purchase wrote off nothing', () {
    // Bought what nobody had asked for.
    final items = [listItem(id: 'l1', quantity: 6000)];
    final result = undo(items, const []);

    expect(result.restored, isEmpty);
    expect(result.items, items.lock);
  });

  // ── The composition with planWriteOffs — what a correction IS ──────────

  IList<ListWriteOff> reapply(
    UndoResult undone,
    List<PurchasedAmount> purchased, {
    DateTime? on,
  }) => planWriteOffs(
    purchased: purchased.lock,
    listItems: undone.items,
    purchaseDate: on ?? purchaseDay,
  );

  PurchasedAmount bought({
    String id = 'pi-2',
    String type = 'type-1',
    required int amount,
  }) => PurchasedAmount(
    purchaseItemId: id,
    productTypeId: type,
    quantityInBaseUnit: amount,
  );

  test('correcting 6 L to 2 L leaves the item on the list with 4 L remaining', () {
    // Requirement 12, and the case that FAILS if the discount of rule 2 is
    // removed: without it the balance would be computed over a write-off that
    // is about to stop existing, and the item would come back with zero left.
    final undone = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 6000)],
    );
    final plan = reapply(undone, [bought(amount: 2000)]);

    expect(undone.items.single.remainingQuantity, 6000);
    expect(plan.single.quantityWrittenOff, 2000);
    expect(plan.single.fulfills, isFalse);

    // 6000 asked − 2000 written off = 4000 left, and the line is still there.
    final after = undone.items.single.copyWith(
      writtenOffQuantity: plan.single.quantityWrittenOff,
    );
    expect(after.remainingQuantity, 4000);
    expect(after.isOpen, isTrue);
  });

  test('correcting the date puts back an item that entered after the new date', () {
    // Not a blind replay: the corrected date goes through decision 25 again,
    // and an item added on the 17th is out of reach of a purchase moved back
    // to the 10th.
    final undone = undo(
      [
        listItem(
          id: 'l1',
          quantity: 2000,
          enteredOn: DateTime(2026, 8, 17),
          writtenOffQuantity: 2000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 2000)],
    );
    final plan = reapply(
      undone,
      [bought(amount: 2000)],
      on: DateTime(2026, 8, 10),
    );

    expect(undone.items.single.isOpen, isTrue);
    expect(plan, isEmpty);
  });

  test('removing an item from the purchase returns it whole to the list', () {
    final undone = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 6000)],
    );
    // The corrected purchase has no line of this type at all.
    final plan = reapply(undone, const []);

    expect(plan, isEmpty);
    expect(undone.items.single.isOpen, isTrue);
    expect(undone.items.single.remainingQuantity, 6000);
    expect(undone.restored.single.fulfilledOn, isNull);
  });

  test('changing the product undoes the old type and applies the new one', () {
    final undone = undo(
      [
        listItem(
          id: 'l1',
          type: softDrinkType,
          quantity: 2000,
          writtenOffQuantity: 2000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
        listItem(id: 'l2', type: beefType, category: meat, quantity: 1000),
      ],
      [off(item: 'l1', amount: 2000)],
    );
    // The corrected line is beef now.
    final plan = reapply(undone, [bought(type: 'type-2', amount: 1000)]);

    expect(undone.items.first.isOpen, isTrue);
    expect(plan.single.shoppingListItemId, 'l2');
    expect(plan.single.fulfills, isTrue);
  });

  test('applying the same correction twice ends in the same state', () {
    // Idempotence (D2): step 1 always starts from the trail as it was
    // WRITTEN, never from what is on screen, so nothing accumulates.
    List<ShoppingListItem> stored() => [
      listItem(
        id: 'l1',
        quantity: 6000,
        writtenOffQuantity: 2000,
        writeOffCount: 1,
      ),
    ];
    final trail = [off(item: 'l1', amount: 2000)];

    final first = undo(stored(), trail);
    final firstPlan = reapply(first, [bought(amount: 2000)]);
    final second = undo(stored(), trail);
    final secondPlan = reapply(second, [bought(amount: 2000)]);

    expect(first, second);
    expect(firstPlan, secondPlan);
  });

  test('re-closing the same item ends with it closed, not reopened', () {
    // The order of blocks 2 and 6 of the SQL, asked of the domain: the undo
    // reopens the line and the re-apply closes it again, so the correction
    // ends with it closed.
    final undone = undo(
      [
        listItem(
          id: 'l1',
          quantity: 6000,
          writtenOffQuantity: 6000,
          writeOffCount: 1,
          fulfilledOn: purchaseDay,
        ),
      ],
      [off(item: 'l1', amount: 6000)],
    );
    final plan = reapply(undone, [bought(amount: 6000)]);

    expect(undone.restored.single.fulfilledOn, isNull);
    expect(plan.single.fulfills, isTrue);
    expect(plan.single.shoppingListItemId, 'l1');
  });

  // ── The classes the undo produces ──────────────────────────────────────

  test('RestoredListItem is equal by value, field by field', () {
    const base = RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false);

    expect(base, const RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false));
    expect(
      base.hashCode,
      const RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false).hashCode,
    );
    expect(
      base,
      isNot(const RestoredListItem(id: 'l2', fulfilledOn: null, notFound: false)),
    );
    expect(
      base,
      isNot(RestoredListItem(id: 'l1', fulfilledOn: purchaseDay, notFound: false)),
    );
    expect(
      base,
      isNot(const RestoredListItem(id: 'l1', fulfilledOn: null, notFound: true)),
    );
  });

  test('RestoredListItem sends fulfilled_on PRESENT and null', () {
    // An omitted key would leave the item closed, and in silence.
    const open = RestoredListItem(id: 'l1', fulfilledOn: null, notFound: true);
    expect(open.toJson().containsKey('fulfilled_on'), isTrue);
    expect(open.toJson()['fulfilled_on'], isNull);
    expect(open.toJson()['not_found'], isTrue);

    final closed = RestoredListItem(
      id: 'l1',
      fulfilledOn: purchaseDay,
      notFound: false,
    );
    expect(closed.toJson()['fulfilled_on'], '2026-08-18');
  });

  test('UndoResult is equal by value, field by field', () {
    final items = [listItem(id: 'l1', quantity: 1000)].lock;
    const restored = IListConst([
      RestoredListItem(id: 'l1', fulfilledOn: null, notFound: false),
    ]);

    final base = UndoResult(items: items, restored: restored);
    expect(base, UndoResult(items: items, restored: restored));
    expect(base.hashCode, UndoResult(items: items, restored: restored).hashCode);
    expect(
      base,
      isNot(UndoResult(items: const IListConst([]), restored: restored)),
    );
    expect(
      base,
      isNot(UndoResult(items: items, restored: const IListConst([]))),
    );
  });
}

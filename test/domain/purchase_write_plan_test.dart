import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/purchase_write_plan.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';

import '../helpers/purchase.dart';

Purchase purchaseOn(DateTime date, {String storeId = 'd5'}) => Purchase(
  id: 'f7',
  date: date,
  storeId: storeId,
  registeredBy: 'Leandro',
  items: [
    PurchaseItem(
      id: 'a1',
      option: optionByPiece(
        id: 'd4',
        pieceSize: 1000,
        unit: BaseUnit.milliliter,
      ),
      quantity: 2000,
      paid: Money(1000),
    ),
  ].lock,
);

ListWriteOff writeOff(
  String listItemId, {
  int quantity = 1000,
  bool clears = false,
  bool fulfills = false,
}) => ListWriteOff(
  purchaseItemId: 'a1',
  shoppingListItemId: listItemId,
  quantityWrittenOff: quantity,
  clearedNotFound: clears,
  fulfills: fulfills,
);

void main() {
  final day = DateTime(2026, 8, 18);
  final purchase = purchaseOn(day);
  final noAlerts = const IList<CapAlerts>.empty();

  PurchaseWritePlan create(List<ListWriteOff> writeOffs) =>
      PurchaseWritePlan.forCreate(
        purchase: purchase,
        writeOffs: writeOffs.lock,
        capAlerts: noAlerts,
      );

  PurchaseWritePlan correct(
    List<ListWriteOff> writeOffs,
    List<RestoredListItem> restored, {
    Purchase? corrected,
  }) => PurchaseWritePlan.forCorrection(
    purchase: corrected ?? purchase,
    writeOffs: writeOffs.lock,
    restored: restored.lock,
    capAlerts: noAlerts,
  );

  PurchaseWritePlan delete(List<RestoredListItem> restored) =>
      PurchaseWritePlan.forDeletion(
        purchaseId: 'f7',
        restored: restored.lock,
        capAlerts: noAlerts,
      );

  group('forCreate', () {
    test('closes on the purchase day and clears not found (case 31)', () {
      final plan = create([
        writeOff('b3', quantity: 2000),
        writeOff('b4', clears: true, fulfills: true),
      ]);
      expect(plan.listChanges, [
        ListItemChange(
          shoppingListItemId: 'b4',
          fulfillment: SetFulfilled(day),
          notFound: false,
        ),
      ]);
    });

    test('passes the purchase and both write-offs through (case 26c)', () {
      final offs = [
        writeOff('b3', fulfills: true),
        writeOff('b4', fulfills: true),
      ];
      final plan = create(offs);
      expect(plan.purchase, purchase);
      expect(plan.purchase!.items.length, 1);
      expect(plan.writeOffs, offs);
    });

    test('keeps fulfillment when the write-off only clears not found', () {
      final plan = create([writeOff('b3', clears: true)]);
      expect(plan.listChanges.single.fulfillment, const KeepFulfillment());
      expect(plan.listChanges.single.notFound, false);
    });

    test('merges write-offs of the same list item', () {
      final plan = create([
        writeOff('b3', fulfills: true),
        writeOff('b3', clears: true),
      ]);
      expect(plan.listChanges, [
        ListItemChange(
          shoppingListItemId: 'b3',
          fulfillment: SetFulfilled(day),
          notFound: false,
        ),
      ]);
    });

    test('never produces ReopenItem', () {
      final plan = create([
        writeOff('b3', fulfills: true),
        writeOff('b4', clears: true),
        writeOff('b5'),
      ]);
      expect(plan.listChanges.any((c) => c.fulfillment is ReopenItem), isFalse);
    });

    test('with no write-offs changes no list item', () {
      final plan = create([]);
      expect(plan.listChanges, isEmpty);
      expect(plan.writeOffs, isEmpty);
      expect(plan.capAlerts, isEmpty);
      expect(plan.steps, isNotEmpty);
    });

    test('orders parent before child', () {
      final plan = create([]);
      expect(plan.steps, [
        PurchaseWriteStep.createPurchase,
        PurchaseWriteStep.createItems,
        PurchaseWriteStep.createWriteOffs,
        PurchaseWriteStep.updateListItems,
        PurchaseWriteStep.writeCapAlerts,
      ]);
      expect(plan.deletedPurchaseId, isNull);
      expect(plan.purchaseId, purchase.id);
    });

    test('is deterministic for the same input (case 26)', () {
      final offs = [writeOff('b4', clears: true, fulfills: true)];
      expect(create(offs), create(offs));
    });
  });

  group('forCorrection', () {
    const e1 = RestoredListItem(id: 'e1', fulfilledOn: null, notFound: false);
    const e2 = RestoredListItem(id: 'e2', fulfilledOn: null, notFound: true);
    const e3 = RestoredListItem(id: 'e3', fulfilledOn: null, notFound: false);

    test('reopens the three items of case 2', () {
      final plan = correct([writeOff('e1', quantity: 2000)], [e1, e2, e3]);
      expect(plan.listChanges, [
        const ListItemChange(
          shoppingListItemId: 'e1',
          fulfillment: ReopenItem(),
          notFound: false,
        ),
        const ListItemChange(
          shoppingListItemId: 'e2',
          fulfillment: ReopenItem(),
          notFound: true,
        ),
        const ListItemChange(
          shoppingListItemId: 'e3',
          fulfillment: ReopenItem(),
          notFound: false,
        ),
      ]);
      expect(plan.writeOffs.single.fulfills, isFalse);
      expect(plan.writeOffs.single.quantityWrittenOff, 2000);
    });

    test('twice gives the same plan (case 3)', () {
      final offs = [writeOff('e1', quantity: 2000)];
      final first = correct(offs, [e1]);
      expect(first, correct(offs, [e1]));
      expect(first.listChanges.length, 1);
      expect(first.listChanges.single.shoppingListItemId, 'e1');
    });

    test('passes the corrected header and reopens e1 and e3 (case 7)', () {
      final corrected = purchaseOn(DateTime(2026, 8, 19), storeId: 'd6');
      final plan = correct([], [e1, e3], corrected: corrected);
      expect(plan.purchase!.date, DateTime(2026, 8, 19));
      expect(plan.purchase!.storeId, 'd6');
      expect(plan.purchase!.registeredBy, 'Leandro');
      expect(plan.listChanges.map((c) => c.shoppingListItemId), ['e1', 'e3']);
      expect(plan.listChanges.every((c) => c.fulfillment is ReopenItem), true);
    });

    test('ends closed when the new write-off fulfills a restored item', () {
      final plan = correct([writeOff('e1', fulfills: true)], [e1]);
      expect(plan.listChanges.single.fulfillment, SetFulfilled(day));
      expect(plan.listChanges.single.notFound, false);
    });

    test('lets the new write-off clear a restored not found', () {
      final plan = correct([writeOff('e2', clears: true)], [e2]);
      expect(plan.listChanges.single.notFound, false);
      expect(plan.listChanges.single.fulfillment, const ReopenItem());
    });

    test('closes with the corrected date across a month turn', () {
      final corrected = purchaseOn(DateTime(2026, 9, 1));
      final plan = correct(
        [writeOff('e1', fulfills: true)],
        [e1],
        corrected: corrected,
      );
      expect(
        plan.listChanges.single.fulfillment,
        SetFulfilled(DateTime(2026, 9, 1)),
      );
    });

    test('writes back a restored fulfilled day', () {
      final plan = correct([], [
        RestoredListItem(
          id: 'e1',
          fulfilledOn: DateTime(2026, 8, 10),
          notFound: true,
        ),
      ]);
      expect(
        plan.listChanges.single,
        ListItemChange(
          shoppingListItemId: 'e1',
          fulfillment: SetFulfilled(DateTime(2026, 8, 10)),
          notFound: true,
        ),
      );
    });

    test('appends new list items after the restored ones', () {
      final plan = correct([writeOff('f1', clears: true)], [e1]);
      expect(plan.listChanges.map((c) => c.shoppingListItemId), ['e1', 'f1']);
      expect(plan.listChanges.last.fulfillment, const KeepFulfillment());
      expect(plan.listChanges.last.notFound, false);
    });

    test('with nothing to restore changes no list item', () {
      final plan = correct([], []);
      expect(plan.listChanges, isEmpty);
      expect(plan.steps, isNotEmpty);
    });

    test('rejects a list item restored twice', () {
      expect(() => correct([], [e1, e1]), throwsArgumentError);
    });

    test('deletes the old trail before the old items', () {
      expect(correct([], []).steps, [
        PurchaseWriteStep.updatePurchase,
        PurchaseWriteStep.deleteWriteOffs,
        PurchaseWriteStep.deleteItems,
        PurchaseWriteStep.createItems,
        PurchaseWriteStep.createWriteOffs,
        PurchaseWriteStep.updateListItems,
        PurchaseWriteStep.writeCapAlerts,
      ]);
    });
  });

  group('forDeletion', () {
    test('gives the list back (case 4)', () {
      final plan = delete([
        const RestoredListItem(id: 'e2', fulfilledOn: null, notFound: true),
      ]);
      expect(plan.purchase, isNull);
      expect(plan.deletedPurchaseId, 'f7');
      expect(plan.purchaseId, 'f7');
      expect(plan.writeOffs, isEmpty);
      expect(plan.listChanges, [
        const ListItemChange(
          shoppingListItemId: 'e2',
          fulfillment: ReopenItem(),
          notFound: true,
        ),
      ]);
    });

    test('never produces KeepFulfillment', () {
      final plan = delete([
        RestoredListItem(
          id: 'e2',
          fulfilledOn: DateTime(2026, 8, 10),
          notFound: false,
        ),
        const RestoredListItem(id: 'e3', fulfilledOn: null, notFound: false),
      ]);
      expect(
        plan.listChanges.first.fulfillment,
        SetFulfilled(DateTime(2026, 8, 10)),
      );
      expect(
        plan.listChanges.any((c) => c.fulfillment is KeepFulfillment),
        isFalse,
      );
    });

    test('deletes child before parent (case 5)', () {
      expect(delete([]).steps, [
        PurchaseWriteStep.updateListItems,
        PurchaseWriteStep.deleteWriteOffs,
        PurchaseWriteStep.deleteItems,
        PurchaseWriteStep.deletePurchase,
        PurchaseWriteStep.writeCapAlerts,
      ]);
    });

    test('rejects a list item restored twice', () {
      const r = RestoredListItem(id: 'e1', fulfilledOn: null, notFound: false);
      expect(() => delete([r, r]), throwsArgumentError);
    });
  });

  test('passes cap alerts through unchanged', () {
    final alerts = [
      CapAlerts(month: DateTime(2026, 9, 1), warned100: true),
      CapAlerts(month: DateTime(2026, 8, 1), warned80: true),
    ].lock;
    expect(
      PurchaseWritePlan.forCreate(
        purchase: purchase,
        writeOffs: const IList.empty(),
        capAlerts: alerts,
      ).capAlerts,
      alerts,
    );
    expect(
      PurchaseWritePlan.forCorrection(
        purchase: purchase,
        writeOffs: const IList.empty(),
        restored: const IList.empty(),
        capAlerts: alerts,
      ).capAlerts,
      alerts,
    );
    expect(
      PurchaseWritePlan.forDeletion(
        purchaseId: 'f7',
        restored: const IList.empty(),
        capAlerts: alerts,
      ).capAlerts,
      alerts,
    );
    expect(create([]).capAlerts, isEmpty);
  });

  test('SetFulfilled rounds to the calendar day', () {
    expect(SetFulfilled(DateTime(2026, 8, 18, 15, 30)).on, day);
    expect(SetFulfilled(DateTime(2026, 8, 18, 15, 30)), SetFulfilled(day));
  });

  test('ListItemChange equality covers every field', () {
    ListItemChange make({
      String id = 'x',
      FulfillmentChange f = const KeepFulfillment(),
      bool? nf,
    }) => ListItemChange(shoppingListItemId: id, fulfillment: f, notFound: nf);

    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(make(id: 'y')));
    expect(make(), isNot(make(f: const ReopenItem())));
    expect(make(f: const ReopenItem()), isNot(make(f: SetFulfilled(day))));
    expect(
      make(f: SetFulfilled(day)),
      isNot(make(f: SetFulfilled(DateTime(2026, 8, 19)))),
    );
    expect(make(), isNot(make(nf: false)));
    expect(make(nf: false), isNot(make(nf: true)));
    expect(make(nf: true).hashCode, make(nf: true).hashCode);
  });

  test('PurchaseWritePlan equality covers every field', () {
    final offs = [writeOff('b4', clears: true, fulfills: true)];
    final base = create(offs);
    expect(base, create(offs));
    expect(base.hashCode, create(offs).hashCode);
    expect(
      base,
      isNot(
        PurchaseWritePlan.forCreate(
          purchase: purchaseOn(DateTime(2026, 8, 19)),
          writeOffs: offs.lock,
          capAlerts: noAlerts,
        ),
      ),
    );
    expect(base, isNot(create([writeOff('b4', clears: true)])));
    expect(
      base,
      isNot(
        PurchaseWritePlan.forCreate(
          purchase: purchase,
          writeOffs: offs.lock,
          capAlerts: [CapAlerts(month: day)].lock,
        ),
      ),
    );
    expect(
      correct([], []),
      isNot(
        correct([], [
          const RestoredListItem(id: 'e1', fulfilledOn: null, notFound: false),
        ]),
      ),
    );
    expect(
      delete([]),
      isNot(
        PurchaseWritePlan.forDeletion(
          purchaseId: 'other',
          restored: const IList.empty(),
          capAlerts: noAlerts,
        ),
      ),
    );
    expect(create([]), isNot(correct([], [])));
  });

  test('toString names the list item and the change', () {
    final change = ListItemChange(
      shoppingListItemId: 'e1',
      fulfillment: const ReopenItem(),
      notFound: true,
    );
    expect(change.toString(), contains('e1'));
    expect(change.toString(), contains('ReopenItem'));
    expect(SetFulfilled(day).toString(), 'SetFulfilled(2026-08-18)');
    expect(const KeepFulfillment().toString(), 'KeepFulfillment');
    expect(create([]).toString(), contains('f7'));
  });
}

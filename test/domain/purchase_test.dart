import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart'
    show InvalidQuantity;

import '../helpers/purchase.dart';

void main() {
  // Fixed instants everywhere: `DateTime.now()` in a test is a test that
  // fails once a year, at midnight.
  final today = DateTime(2026, 8, 28);
  final crate = optionByPiece(
    id: 'prod-4',
    brand: cokeBrand,
    pieceCount: 12,
  );
  final bottle = optionByPiece(id: 'prod-1', brand: cokeBrand);
  final beef = optionByWeight(id: 'prod-5');

  group('PurchaseItem', () {
    test('converts what was typed into the base unit, once and here', () {
      // The acceptance criterion: one crate of 12 × 350 ml and twelve bottles
      // of 350 ml close at the same 4200 ml — and at the same cost per litre.
      final one = purchaseItem(id: 'i1', option: crate, cents: 6200);
      final twelve = purchaseItem(
        id: 'i2',
        option: bottle,
        quantity: 12,
        cents: 6200,
      );

      expect(one.quantityInBaseUnit, 4200);
      expect(twelve.quantityInBaseUnit, 4200);
      expect(one.quantity, 1, reason: 'what was typed is kept as typed');
      expect(twelve.quantity, 12);
    });

    test('sold by weight passes the parsed amount straight through', () {
      // 1,5 kg was already turned into 1500 g by the screen.
      final item = purchaseItem(id: 'i1', option: beef, quantity: 1500);

      expect(item.quantityInBaseUnit, 1500);
      expect(item.baseUnit, BaseUnit.kilogram);
    });

    test('refuses a quantity of zero or less', () {
      expect(
        () => purchaseItem(id: 'i1', option: crate, quantity: 0),
        throwsA(isA<InvalidQuantity>()),
      );
      expect(
        () => purchaseItem(id: 'i1', option: crate, quantity: -1),
        throwsA(isA<InvalidQuantity>()),
      );
    });

    test('is born with a key of its own when none is given', () {
      final item = PurchaseItem(
        option: crate,
        quantity: 1,
        paid: const Money(6200),
      );

      expect(item.id, hasLength(36));
      expect(item.id, isNot(PurchaseItem(
        option: crate,
        quantity: 1,
        paid: const Money(6200),
      ).id));
    });

    test('reads what the row shows', () {
      expect(
        purchaseItem(id: 'i1', option: crate).label,
        'Coca-Cola 12 × 350 ml',
      );
      expect(purchaseItem(id: 'i1', option: crate).quantityLabel, '1');
      // A bare '1500' on the row would be read as fifteen hundred kilos.
      expect(
        purchaseItem(id: 'i1', option: beef, quantity: 1500).quantityLabel,
        '1,5 kg',
      );
    });

    test('writes only the table columns, with no purchase_id', () {
      // The purchase_id is the same for every line and comes from the
      // purchase itself, in `p_purchase`.
      final json = purchaseItem(
        id: 'i1',
        option: crate,
        cents: 6200,
      ).toJson();

      expect(json, {
        'id': 'i1',
        'product_id': 'prod-4',
        'quantity': 1,
        'quantity_in_base_unit': 4200,
        'total_paid': 6200,
      });
      expect(json.containsKey('purchase_id'), isFalse);
      expect(json.containsKey('product'), isFalse);
    });

    test('the draft shape carries the whole leaf, and comes back whole', () {
      // Without this a draft recovered in airplane mode could not draw its
      // own lines: the catalog it would need never loaded.
      final item = purchaseItem(id: 'i1', option: crate, cents: 6200);
      final back = PurchaseItem.fromJson(item.toDraftJson());

      expect(back, item);
      expect(back.label, 'Coca-Cola 12 × 350 ml');
      expect(back.quantityInBaseUnit, 4200);
    });

    test('an edit keeps the id — it corrects a line, it does not add one', () {
      // The write-off trail points at this id.
      final item = purchaseItem(id: 'i1', option: crate, cents: 6200);
      final corrected = item.copyWith(quantity: 2, paid: const Money(12000));

      expect(corrected.id, 'i1');
      expect(corrected.quantityInBaseUnit, 8400);
      expect(corrected.paid, const Money(12000));
    });

    test('equality covers every field', () {
      final item = purchaseItem(id: 'i1', option: crate, cents: 6200);

      expect(item, purchaseItem(id: 'i1', option: crate, cents: 6200));
      expect(
        item.hashCode,
        purchaseItem(id: 'i1', option: crate, cents: 6200).hashCode,
      );
      expect(item, isNot(purchaseItem(id: 'i1', option: crate, cents: 6201)));
      expect(item, isNot(item.copyWith(quantity: 2)));
      expect(item.toString(), contains('Coca-Cola'));
    });
  });

  group('Purchase.checkDate', () {
    test('accepts yesterday and today, refuses tomorrow', () {
      // The three cases, including the boundary: exactly today passes, and
      // one day past it does not.
      expect(
        () => Purchase.checkDate(DateTime(2026, 8, 27), today),
        returnsNormally,
      );
      expect(() => Purchase.checkDate(today, today), returnsNormally);
      expect(
        () => Purchase.checkDate(DateTime(2026, 8, 29), today),
        throwsA(isA<FutureDate>()),
      );
    });

    test('compares days, not instants', () {
      // Later today is still today: the date picker gives a midnight, but a
      // draft recovered from Hive could carry an hour.
      expect(
        () => Purchase.checkDate(
          DateTime(2026, 8, 28, 23, 59),
          DateTime(2026, 8, 28, 0, 1),
        ),
        returnsNormally,
      );
    });

    test('the sentences are the ones the screen shows', () {
      expect(const FutureDate().message, 'A compra não pode ter data futura.');
      expect(const MissingStore().message, 'Escolha o mercado desta compra.');
      expect(
        const EmptyPurchase().message,
        'Acrescente ao menos um item à compra.',
      );
      expect(const FutureDate().toString(), contains('data futura'));
      expect(const MissingStore().toString(), contains('mercado'));
      expect(const EmptyPurchase().toString(), contains('item'));
    });
  });

  group('Purchase', () {
    Purchase purchase({IList<PurchaseItem>? items}) => Purchase(
      id: 'a1',
      date: DateTime(2026, 8, 18),
      storeId: 'store-1',
      registeredBy: 'Leandro',
      items: items ?? const IList.empty(),
    );

    test('adds its lines up', () {
      expect(
        purchase(
          items: [
            purchaseItem(id: 'i1', option: crate, cents: 6200),
            purchaseItem(id: 'i2', option: bottle, cents: 330),
          ].lock,
        ).total,
        const Money(6530),
      );
      expect(purchase().total, Money.zero);
    });

    test('writes only the four columns — the items travel apart', () {
      final json = purchase(
        items: [purchaseItem(id: 'i1', option: crate)].lock,
      ).toJson();

      expect(json, {
        'id': 'a1',
        'purchase_date': '2026-08-18',
        'store_id': 'store-1',
        'registered_by': 'Leandro',
      });
      // `create_purchase` takes them as its second argument, so putting them
      // here would write them twice or not at all.
      expect(json.containsKey('items'), isFalse);
    });

    test('reduces its lines to what the write-off planner reads', () {
      final amounts = purchase(
        items: [
          purchaseItem(id: 'i1', option: crate),
          purchaseItem(id: 'i2', option: beef, quantity: 1500),
        ].lock,
      ).amounts;

      expect(amounts.length, 2);
      expect(amounts.first.purchaseItemId, 'i1');
      expect(amounts.first.productTypeId, 'type-1');
      expect(amounts.first.quantityInBaseUnit, 4200);
      expect(amounts.last.productTypeId, 'type-2');
      expect(amounts.last.quantityInBaseUnit, 1500);
    });

    test('rounds the date to the day and is born with a key', () {
      final withHour = Purchase(
        date: DateTime(2026, 8, 18, 15, 3),
        storeId: 'store-1',
        registeredBy: 'Leandro',
      );

      expect(withHour.date, DateTime(2026, 8, 18));
      expect(withHour.id, hasLength(36));
    });

    test('equality covers every field', () {
      expect(purchase(), purchase());
      expect(purchase().hashCode, purchase().hashCode);
      expect(
        purchase(),
        isNot(purchase(items: [purchaseItem(id: 'i1', option: crate)].lock)),
      );
      expect(purchase().toString(), contains('2026-08-18'));
    });
  });

  group('PurchaseDraft', () {
    PurchaseDraft draft() => PurchaseDraft(
      purchaseId: 'a1',
      date: DateTime(2026, 8, 18),
      registeredBy: 'Leandro',
      storeId: 'store-1',
    );

    test('is born empty, with today and this phone label', () {
      final fresh = PurchaseDraft.startedOn(
        DateTime(2026, 8, 28, 9, 30),
        'Leandro',
      );

      expect(fresh.date, DateTime(2026, 8, 28));
      expect(fresh.registeredBy, 'Leandro');
      expect(fresh.isEmpty, isTrue);
      expect(fresh.bannerDismissed, isFalse);
      expect(fresh.purchaseId, hasLength(36));
    });

    test('withItem adds, and REPLACES the line with the same id', () {
      // That is what `[ed]` does: it corrects a line already in the purchase,
      // it does not append a second one.
      final one = draft().withItem(
        purchaseItem(id: 'i1', option: crate, cents: 6200),
      );
      final two = one.withItem(purchaseItem(id: 'i2', option: bottle, cents: 330));
      final corrected = two.withItem(
        purchaseItem(id: 'i1', option: crate, cents: 5900),
      );

      expect(two.items.length, 2);
      expect(corrected.items.length, 2, reason: 'replaced, not appended');
      expect(corrected.items.first.paid, const Money(5900));
      expect(corrected.total, const Money(6230));
    });

    test('withoutItem takes the line out and redoes the total', () {
      final two = draft()
          .withItem(purchaseItem(id: 'i1', option: crate, cents: 6200))
          .withItem(purchaseItem(id: 'i2', option: bottle, cents: 330));

      expect(two.withoutItem('i1').items.length, 1);
      expect(two.withoutItem('i1').total, const Money(330));
      expect(two.withoutItem('nope').items.length, 2);
    });

    test('the key never changes, whatever is edited', () {
      // A resend that arrives twice has to find the same id — that is what
      // `on conflict (id) do nothing` conflicts on.
      final edited = draft()
          .withItem(purchaseItem(id: 'i1', option: crate))
          .copyWith(date: DateTime(2026, 8, 17), storeId: 'store-2')
          .markedPending();

      expect(edited.purchaseId, 'a1');
    });

    test('a round trip through the JSON keeps label, pending and lines', () {
      final saved = draft()
          .withItem(purchaseItem(id: 'i1', option: crate, cents: 6200))
          .markedPending();
      final back = PurchaseDraft.fromJson(saved.toJson());

      expect(back.purchaseId, 'a1');
      expect(back.date, DateTime(2026, 8, 18));
      expect(back.registeredBy, 'Leandro');
      expect(back.storeId, 'store-1');
      expect(back.pendingSubmission, isTrue);
      expect(back.items.single.label, 'Coca-Cola 12 × 350 ml');
      expect(back.total, const Money(6200));
    });

    test('the dismissal is PERSISTED, so the banner does not come back', () {
      // The ViewModel is recreated whenever the device label changes, and it
      // reads the draft from the box again — a dismissal living only in
      // memory would bring the banner back with it.
      //
      // Whether the banner shows AT ALL is not here: that is
      // `startedWithDraftProvider`, because "came from a previous run of the
      // app" is a question about the session, not about the purchase.
      final dismissed = PurchaseDraft.fromJson(draft().toJson())
          .dismissedBanner();

      expect(dismissed.bannerDismissed, isTrue);
      expect(PurchaseDraft.fromJson(dismissed.toJson()).bannerDismissed,
          isTrue);
      // And it does NOT throw the purchase away.
      expect(dismissed.storeId, 'store-1');
    });

    test('a draft from before the flag existed reads as not dismissed', () {
      // The key is versioned (`draft_v1`), but a row written moments before a
      // deploy still has to open instead of throwing.
      final old = draft().toJson()..remove('banner_dismissed');

      expect(PurchaseDraft.fromJson(old).bannerDismissed, isFalse);
    });

    test('a draft with a store but no item is not empty', () {
      // The store alone is worth recovering: it is the field that costs the
      // most taps in an aisle.
      expect(draft().isEmpty, isFalse);
      expect(draft().isNotEmpty, isTrue);
      expect(
        PurchaseDraft.startedOn(today, 'Leandro').isEmpty,
        isTrue,
      );
    });

    test('equality covers every field', () {
      expect(draft(), draft());
      expect(draft().hashCode, draft().hashCode);
      expect(draft(), isNot(draft().markedPending()));
      expect(draft(), isNot(draft().dismissedBanner()));
      expect(
        draft(),
        isNot(draft().withItem(purchaseItem(id: 'i1', option: crate))),
      );
      expect(draft().toString(), contains('2026-08-18'));
    });
  });

  group('correcting a purchase — H9', () {
    test('changes the date, the store and the lines, and nothing else', () {
      final original = Purchase(
        id: 'a1',
        date: DateTime(2026, 8, 18),
        storeId: 'store-1',
        registeredBy: 'Leandro',
        items: [purchaseItem(id: 'i1', option: crate)].lock,
      );

      final corrected = original.correctedTo(
        date: DateTime(2026, 8, 19),
        storeId: 'store-2',
      );

      expect(corrected.date, DateTime(2026, 8, 19));
      expect(corrected.storeId, 'store-2');
      // The id is what the trail points at, and who registered a purchase is
      // a historical FACT a correction never rewrites.
      expect(corrected.id, 'a1');
      expect(corrected.registeredBy, 'Leandro');
      expect(corrected.items, original.items);
    });

    test('correcting nothing gives an equal purchase back', () {
      final original = Purchase(
        id: 'a1',
        date: DateTime(2026, 8, 18),
        storeId: 'store-1',
        registeredBy: 'Leandro',
      );

      expect(original.correctedTo(), original);
    });

    test('the correction payload leaves registered_by OUT', () {
      final json = Purchase(
        id: 'a1',
        date: DateTime(2026, 8, 18),
        storeId: 'store-1',
        registeredBy: 'Leandro',
      ).toCorrectionJson();

      expect(json, {
        'id': 'a1',
        'purchase_date': '2026-08-18',
        'store_id': 'store-1',
      });
      expect(json.containsKey('registered_by'), isFalse);
    });
  });

  group('PurchasedAmount', () {
    PurchasedAmount amount({
      String item = 'pi-1',
      String type = 'type-1',
      int quantity = 2000,
    }) => PurchasedAmount(
      purchaseItemId: item,
      productTypeId: type,
      quantityInBaseUnit: quantity,
    );

    test('equality covers every field', () {
      expect(amount(), amount());
      expect(amount().hashCode, amount().hashCode);
      expect(amount(), isNot(amount(item: 'pi-2')));
      expect(amount(), isNot(amount(type: 'type-2')));
      expect(amount(), isNot(amount(quantity: 2001)));
    });
  });
}

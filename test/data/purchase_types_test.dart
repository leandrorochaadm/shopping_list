import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase.dart';

import '../helpers/purchase.dart';

/// The two types the purchase contract carries. They were records until
/// 29/08/2026; written by hand, a field left out of the `==` fails silently.
void main() {
  Purchase purchase({String id = 'a1', String store = 'store-1'}) => Purchase(
    id: id,
    date: DateTime(2026, 8, 18),
    storeId: store,
    registeredBy: 'Leandro',
    items: [
      purchaseItem(id: 'pi-1', option: optionByPiece(id: 'prod-1')),
    ].lock,
  );

  group('PurchaseSubmission', () {
    PurchaseSubmission submission({String id = 'a1', int quantity = 2000}) =>
        PurchaseSubmission(
          purchase: purchase(id: id),
          writeOffs: [
            ListWriteOff(
              purchaseItemId: 'pi-1',
              shoppingListItemId: 'l1',
              quantityWrittenOff: quantity,
            ),
          ].lock,
        );

    test('equality covers every field', () {
      expect(submission(), submission());
      expect(submission().hashCode, submission().hashCode);
      expect(submission(), isNot(submission(id: 'a2')));
      expect(submission(), isNot(submission(quantity: 1999)));
    });
  });

  group('PurchaseHistoryEntry', () {
    PurchaseHistoryEntry entry({
      String product = 'prod-4',
      int quantity = 4200,
      int cents = 6200,
      DateTime? on,
    }) => PurchaseHistoryEntry(
      productId: product,
      quantityInBaseUnit: quantity,
      paid: Money(cents),
      purchasedOn: on ?? DateTime(2026, 8, 18),
    );

    test('equality covers every field', () {
      expect(entry(), entry());
      expect(entry().hashCode, entry().hashCode);
      expect(entry(), isNot(entry(product: 'prod-5')));
      expect(entry(), isNot(entry(quantity: 4201)));
      expect(entry(), isNot(entry(cents: 6201)));
      expect(entry(), isNot(entry(on: DateTime(2026, 8, 19))));
    });
  });
}

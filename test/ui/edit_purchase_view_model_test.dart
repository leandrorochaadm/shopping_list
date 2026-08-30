import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/list_write_off.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase.dart';
import 'package:shopping_list/domain/models/purchase_item.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/domain/models/write_off_undo.dart';
import 'package:shopping_list/ui/purchase/view_model/edit_purchase_view_model.dart';

import '../helpers/purchase.dart';

/// The purchase fake, seeded with ONE purchase whose trail this test controls,
/// and with a switch that fails the next call.
class _SpyPurchases extends PurchaseRepositoryLocal {
  _SpyPurchases({required this.detail}) : super(latency: Duration.zero);

  final PurchaseDetail detail;

  Object? failNextCall;
  int correctCalls = 0;
  int deleteCalls = 0;
  IList<ListWriteOff>? sentWriteOffs;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<PurchaseDetail> fetchDetail(String purchaseId) async {
    final failure = _take();
    if (failure != null) throw failure;
    return detail;
  }

  @override
  Future<void> correct({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
  }) async {
    correctCalls++;
    sentWriteOffs = writeOffs;
    final failure = _take();
    if (failure != null) throw failure;
    return super.correct(
      purchase: purchase,
      writeOffs: writeOffs,
      restored: restored,
    );
  }

  @override
  Future<void> delete({
    required String purchaseId,
    required IList<RestoredListItem> restored,
  }) async {
    deleteCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.delete(purchaseId: purchaseId, restored: restored);
  }
}

/// The list fake that records which ids were asked for and which echoes were
/// announced — the two things the correction gets wrong in silence.
class _SpyList extends ShoppingListRepositoryLocal {
  _SpyList({super.initial}) : super(latency: Duration.zero);

  final List<List<String>> requestedIds = [];

  @override
  Future<IList<ShoppingListItem>> fetchItemsByIds(Iterable<String> ids) async {
    requestedIds.add(ids.toList());
    return super.fetchItemsByIds(ids);
  }
}

void main() {
  final purchaseDay = DateTime(2026, 8, 18);
  final crate = optionByPiece(id: 'prod-4', pieceCount: 12);

  PurchaseDetail detailWith({
    required List<PurchaseItem> items,
    required List<ListWriteOff> trail,
    DateTime? date,
  }) {
    final purchase = Purchase(
      id: 'a1',
      date: date ?? purchaseDay,
      storeId: 'store-1',
      registeredBy: 'Leandro',
      items: items.lock,
    );
    return PurchaseDetail(
      purchase: purchase,
      items: items.lock,
      trail: trail.lock,
    );
  }

  /// The purchase this test corrects: 6 L of soft drink, closing `l1`, and a
  /// zero-amount row closing `l2` while knocking its `[!]` down.
  PurchaseDetail seedDetail() => detailWith(
    items: [
      PurchaseItem(
        id: 'pi-1',
        option: crate,
        quantity: 1,
        paid: const Money(6200),
      ),
    ],
    trail: [
      const ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l1',
        quantityWrittenOff: 6000,
      ),
      const ListWriteOff(
        purchaseItemId: 'pi-1',
        shoppingListItemId: 'l2',
        quantityWrittenOff: 0,
        clearedNotFound: true,
      ),
    ],
  );

  List<ShoppingListItem> seedList() => [
    listItem(
      id: 'l1',
      quantity: 6000,
      writtenOffQuantity: 6000,
      writeOffCount: 1,
      fulfilledOn: purchaseDay,
    ),
    listItem(
      id: 'l2',
      quantity: null,
      writeOffCount: 1,
      fulfilledOn: purchaseDay,
    ),
  ];

  ProviderContainer containerWith(
    PurchaseRepository purchases,
    ShoppingListRepository lists,
  ) => ProviderContainer.test(
    overrides: <Override>[
      purchaseRepositoryProvider.overrideWith((ref) => purchases),
      shoppingListRepositoryProvider.overrideWith((ref) => lists),
    ],
  );

  test('opens with the purchase and ONLY the list items its trail cites', () async {
    final lists = _SpyList(initial: [...seedList(), listItem(id: 'l9')]);
    final container = containerWith(_SpyPurchases(detail: seedDetail()), lists);

    final state = await container.read(
      editPurchaseViewModelProvider('a1').future,
    );

    expect(state.detail.purchase.id, 'a1');
    expect(state.listItems.map((item) => item.id), ['l1', 'l2']);
    // Not the whole table: a closed item and a removed one are never deleted,
    // so that query would grow with the age of the app.
    expect(lists.requestedIds.single.toSet(), {'l1', 'l2'});
  });

  test('a purchase that wrote nothing off asks the list for nothing', () async {
    final lists = _SpyList(initial: seedList());
    final container = containerWith(
      _SpyPurchases(
        detail: detailWith(
          items: [
            PurchaseItem(
              id: 'pi-1',
              option: crate,
              quantity: 1,
              paid: const Money(6200),
            ),
          ],
          trail: const [],
        ),
      ),
      lists,
    );

    final state = await container.read(
      editPurchaseViewModelProvider('a1').future,
    );

    expect(state.listItems, isEmpty);
    expect(lists.requestedIds.single, isEmpty);
  });

  group('saving the correction', () {
    test('6 L corrected to 2 L leaves the item on the list with 4 L left', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final lists = _SpyList(initial: seedList());
      final container = containerWith(purchases, lists);
      await container.read(editPurchaseViewModelProvider('a1').future);

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                option: crate,
                quantity: 1,
                paid: const Money(2000),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      expect(error, isNull);
      expect(purchases.correctCalls, 1);
      // 4200 ml of one crate against the 6000 asked for: a partial write-off
      // that does NOT close the line.
      final forL1 = purchases.sentWriteOffs!.where(
        (off) => off.shoppingListItemId == 'l1',
      );
      expect(forL1.single.quantityWrittenOff, 4200);
      expect(forL1.single.fulfills, isFalse);
    });

    test('removing the last item is refused by the entity, before any I/O', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await container.read(editPurchaseViewModelProvider('a1').future);

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: const IList<PurchaseItem>.empty(),
            today: DateTime(2026, 8, 29),
          );

      // Whoever wants a purchase with no items wants to delete the purchase,
      // and the button for that is right below.
      expect(error, 'Acrescente ao menos um item à compra.');
      expect(purchases.correctCalls, 0);
    });

    test('a date in the future is refused by the entity, not by the screen', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await container.read(editPurchaseViewModelProvider('a1').future);

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: DateTime(2026, 8, 30),
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                option: crate,
                quantity: 1,
                paid: const Money(2000),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      expect(error, 'A compra não pode ter data futura.');
      expect(purchases.correctCalls, 0);
    });

    test('a failed correction becomes a sentence, never the raw exception', () async {
      final purchases = _SpyPurchases(detail: seedDetail())
        ..failNextCall = NetworkException('down');
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      // The failure has to hit `correct`, not `fetchDetail`.
      purchases.failNextCall = null;
      await container.read(editPurchaseViewModelProvider('a1').future);
      purchases.failNextCall = NetworkException('down');

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                option: crate,
                quantity: 1,
                paid: const Money(2000),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      expect(error, isNotNull);
      expect(error, isNot(contains('down')));
      // The screen stays: the correction failed, it did not disappear.
      expect(container.read(editPurchaseViewModelProvider('a1')).hasValue, isTrue);
    });

    test('a double tap on save fires ONE correction', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await container.read(editPurchaseViewModelProvider('a1').future);

      final notifier = container.read(
        editPurchaseViewModelProvider('a1').notifier,
      );
      final items = [
        PurchaseItem(
          id: 'pi-1',
          option: crate,
          quantity: 1,
          paid: const Money(2000),
        ),
      ].lock;

      final results = await Future.wait([
        notifier.save(
          purchaseDate: purchaseDay,
          storeId: 'store-1',
          items: items,
          today: DateTime(2026, 8, 29),
        ),
        notifier.save(
          purchaseDate: purchaseDay,
          storeId: 'store-1',
          items: items,
          today: DateTime(2026, 8, 29),
        ),
      ]);

      expect(purchases.correctCalls, 1);
      // The second `null` is the guard saying "I did nothing" — which is why
      // the screen needs a `_saving` of its own before it pops.
      expect(results, [null, null]);
    });
  });

  group('the echo of the channel', () {
    test('expectEcho is called BEFORE the RPC', () async {
      final lists = _SpyList(initial: seedList());
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, lists);
      await container.read(editPurchaseViewModelProvider('a1').future);

      // Recorded inside `correct`, which runs after the ViewModel's step 3.
      // Realtime broadcasts on commit and the HTTP response comes back after
      // that same commit, so an announcement made afterwards can lose.
      await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                option: crate,
                quantity: 1,
                paid: const Money(2000),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      expect(lists.expectedEchoes, isNotEmpty);
    });

    test('the ids cover restored AND the new write-offs', () async {
      // The correction that only changes the amount paid: nothing reopens, so
      // `restored` comes out EMPTY and the whole echo comes from the
      // write-offs. Sending only `restored` would let exactly this case paint
      // the banner on the phone that made the correction.
      final lists = _SpyList(
        initial: [
          // Still OPEN: 6000 asked, 4200 written off. The undo takes that
          // 4200 back without reopening anything — nothing changed state —
          // so `restored` comes out empty.
          listItem(
            id: 'l1',
            quantity: 6000,
            writtenOffQuantity: 4200,
            writeOffCount: 1,
          ),
        ],
      );
      final purchases = _SpyPurchases(
        detail: detailWith(
          items: [
            PurchaseItem(
              id: 'pi-1',
              option: crate,
              quantity: 1,
              paid: const Money(6200),
            ),
          ],
          trail: const [
            ListWriteOff(
              purchaseItemId: 'pi-1',
              shoppingListItemId: 'l1',
              quantityWrittenOff: 4200,
            ),
          ],
        ),
      );
      final container = containerWith(purchases, lists);
      await container.read(editPurchaseViewModelProvider('a1').future);

      await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                // Two crates, 8400 ml — enough to cover the 6000 asked for
                // and CLOSE the line.
                option: crate,
                quantity: 2,
                paid: const Money(11800),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      // `restored` is empty and the echo is not: it comes entirely from the
      // write-off that closes the line. Sending only `restored` would make
      // exactly this correction paint the banner on the phone that made it.
      expect(purchases.sentWriteOffs!.single.fulfills, isTrue);
      expect(lists.expectedEchoes, ['l1']);
    });

    test('an id in restored AND in the write-offs is expected TWICE', () async {
      // The undo reopens `l1` and the corrected purchase closes it again: two
      // UPDATEs in one transaction, so two echoes. A `Set` here would let the
      // second one through and paint the banner.
      final lists = _SpyList(initial: seedList());
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, lists);
      await container.read(editPurchaseViewModelProvider('a1').future);

      await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .save(
            purchaseDate: purchaseDay,
            storeId: 'store-1',
            items: [
              PurchaseItem(
                id: 'pi-1',
                // 2 × 12 × 350 ml = 8400 ml, which covers the 6000 asked for
                // and closes `l1` again.
                option: crate,
                quantity: 2,
                paid: const Money(12000),
              ),
            ].lock,
            today: DateTime(2026, 8, 29),
          );

      expect(
        lists.expectedEchoes.where((id) => id == 'l1').length,
        2,
        reason: 'reopened by the undo and closed again by the correction',
      );
    });
  });

  group('deleting', () {
    test('gives the item, the balance and the not-found mark back', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final lists = _SpyList(
        initial: [
          listItem(
            id: 'l1',
            quantity: 6000,
            writtenOffQuantity: 6000,
            writeOffCount: 1,
            fulfilledOn: purchaseDay,
          ),
          listItem(
            id: 'l2',
            quantity: null,
            writeOffCount: 1,
            fulfilledOn: purchaseDay,
          ),
        ],
      );
      final container = containerWith(purchases, lists);
      await container.read(editPurchaseViewModelProvider('a1').future);

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .delete();

      expect(error, isNull);
      expect(purchases.deleteCalls, 1);
      final restored = purchases.restoredByCorrection;
      expect(restored.map((entry) => entry.id).toSet(), {'l1', 'l2'});
      expect(restored.every((entry) => entry.fulfilledOn == null), isTrue);
      // R14: the purchase had knocked the `[!]` down, so undoing puts it back.
      expect(
        restored.firstWhere((entry) => entry.id == 'l2').notFound,
        isTrue,
      );
    });

    test('a failed deletion becomes a sentence and keeps the screen', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await container.read(editPurchaseViewModelProvider('a1').future);

      purchases.failNextCall = NetworkException('down');
      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .delete();

      expect(error, isNotNull);
      expect(error, isNot(contains('down')));
      expect(container.read(editPurchaseViewModelProvider('a1')).hasValue, isTrue);
    });

    test('a double tap on delete fires ONE deletion', () async {
      final purchases = _SpyPurchases(detail: seedDetail());
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await container.read(editPurchaseViewModelProvider('a1').future);

      final notifier = container.read(
        editPurchaseViewModelProvider('a1').notifier,
      );
      await Future.wait([notifier.delete(), notifier.delete()]);

      expect(purchases.deleteCalls, 1);
    });
  });

  group('the failed load', () {
    test('occupies the screen instead of spinning forever', () async {
      final purchases = _SpyPurchases(detail: seedDetail())
        ..failNextCall = NetworkException('down');
      final container = containerWith(purchases, _SpyList(initial: seedList()));

      await expectLater(
        container.read(editPurchaseViewModelProvider('a1').future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(editPurchaseViewModelProvider('a1')).hasError, isTrue);
    });

    test('a refresh that works puts the purchase back', () async {
      final purchases = _SpyPurchases(detail: seedDetail())
        ..failNextCall = NetworkException('down');
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await expectLater(
        container.read(editPurchaseViewModelProvider('a1').future),
        throwsA(isA<NetworkException>()),
      );

      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .refresh();

      expect(error, isNull);
      expect(container.read(editPurchaseViewModelProvider('a1')).hasValue, isTrue);
    });

    test('a refresh that fails again lands in AsyncError, not AsyncLoading', () async {
      final purchases = _SpyPurchases(detail: seedDetail())
        ..failNextCall = NetworkException('down');
      final container = containerWith(purchases, _SpyList(initial: seedList()));
      await expectLater(
        container.read(editPurchaseViewModelProvider('a1').future),
        throwsA(isA<NetworkException>()),
      );

      purchases.failNextCall = NetworkException('still down');
      final error = await container
          .read(editPurchaseViewModelProvider('a1').notifier)
          .refresh();

      expect(error, isNotNull);
      final state = container.read(editPurchaseViewModelProvider('a1'));
      expect(state.hasError, isTrue);
      expect(state.isLoading, isFalse);
    });
  });

  group('EditPurchaseState — the middle link of the equality chain', () {
    test('equal by value, and one field at a time breaks it', () {
      final detail = seedDetail();
      final items = seedList().lock;

      final base = EditPurchaseState(detail: detail, listItems: items);
      expect(base, EditPurchaseState(detail: detail, listItems: items));
      expect(
        base.hashCode,
        EditPurchaseState(detail: detail, listItems: items).hashCode,
      );
      expect(
        base,
        isNot(
          EditPurchaseState(
            detail: detail,
            listItems: const IList<ShoppingListItem>.empty(),
          ),
        ),
      );
      expect(
        base,
        isNot(
          EditPurchaseState(
            detail: detailWith(items: const [], trail: const []),
            listItems: items,
          ),
        ),
      );
    });
  });

  group('PurchaseDetail and PurchaseHistoryPage compare by value', () {
    test('one field at a time breaks each of them', () {
      final detail = seedDetail();
      expect(detail, seedDetail());
      expect(detail.hashCode, seedDetail().hashCode);
      expect(
        detail,
        isNot(detailWith(items: detail.items.unlock, trail: const [])),
      );
      expect(
        detail,
        isNot(
          detailWith(
            items: detail.items.unlock,
            trail: detail.trail.unlock,
            date: DateTime(2026, 8, 19),
          ),
        ),
      );

      const empty = PurchaseHistoryPage(
        purchases: IListConst([]),
        hasMore: false,
      );
      expect(empty, const PurchaseHistoryPage(
        purchases: IListConst([]),
        hasMore: false,
      ));
      expect(empty.hashCode, const PurchaseHistoryPage(
        purchases: IListConst([]),
        hasMore: false,
      ).hashCode);
      expect(empty, isNot(const PurchaseHistoryPage(
        purchases: IListConst([]),
        hasMore: true,
      )));
    });
  });
}

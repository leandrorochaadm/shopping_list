import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_hive.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';

import '../helpers/purchase.dart';

/// The only storage the draft ever has. On the phone this is IndexedDB; here
/// it is a temporary directory, and what is being checked is the same thing:
/// that eighteen items typed in an aisle come back after the app was closed,
/// and that the SYNCHRONOUS read screen 3 depends on actually sees them.
void main() {
  late Directory directory;
  late Box<String> box;
  late PurchaseDraftRepositoryHive repository;

  final crate = optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12);

  PurchaseDraft draft() => PurchaseDraft(
    purchaseId: 'a1',
    date: DateTime(2026, 8, 18),
    registeredBy: 'Leandro',
    storeId: 'store-1',
  ).withItem(purchaseItem(id: 'i1', option: crate, cents: 6200));

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('purchase_draft_test');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(PurchaseDraftRepositoryHive.boxName);
    repository = PurchaseDraftRepositoryHive(box);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(PurchaseDraftRepositoryHive.boxName);
    await Hive.close();
    directory.deleteSync(recursive: true);
  });

  test('reads nothing when no purchase was ever started', () {
    expect(repository.readNow(), isNull);
  });

  test('gives back the whole purchase, lines included', () async {
    await repository.save(draft());

    final back = repository.readNow()!;
    expect(back.purchaseId, 'a1');
    expect(back.storeId, 'store-1');
    expect(back.total, const Money(6200));
    // The leaf travels whole, which is what lets the line be drawn with no
    // network — the whole point of H8.
    expect(back.items.single.label, 'Coca-Cola 12 × 350 ml');
    expect(back.items.single.quantityInBaseUnit, 4200);
  });

  test('the dismissal survives, so the banner does not come back', () async {
    // The ViewModel is recreated whenever the device label changes, and it
    // reads the draft again from here — a dismissal that lived only in memory
    // would bring the banner back with it.
    await repository.save(draft());
    expect(repository.readNow()!.bannerDismissed, isFalse);

    await repository.save(repository.readNow()!.dismissedBanner());

    final again = repository.readNow()!;
    expect(again.bannerDismissed, isTrue);
    // And the purchase is still all there.
    expect(again.items.single.label, 'Coca-Cola 12 × 350 ml');
  });

  test('the pending mark survives, or the resend would never happen', () async {
    await repository.save(draft().markedPending());

    expect(repository.readNow()!.pendingSubmission, isTrue);
  });

  test('saving twice replaces the row instead of piling up', () async {
    await repository.save(draft());
    await repository.save(draft().copyWith(storeId: 'store-2'));

    expect(repository.readNow()!.storeId, 'store-2');
    expect(box.length, 1);
  });

  test('clearing takes the draft away for good', () async {
    await repository.save(draft());
    await repository.clear();

    expect(repository.readNow(), isNull);
    // It is what runs right after a successful save, and it is the only
    // guard against registering the same purchase twice.
    expect(box.isEmpty, isTrue);
  });

  test('a draft written by an older shape is ignored, not thrown', () async {
    // A half-written row from a browser that closed mid-save, or a draft from
    // a version whose JSON looked different. Losing one draft is bad;
    // refusing to open screen 3 forever because of it is worse — and an
    // installed PWA has no console to explain the exception.
    await box.put('draft_v1', '{"purchase_id": "a1"}');

    expect(repository.readNow(), isNull);
  });
}

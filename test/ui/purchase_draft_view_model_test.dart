import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/ui/purchase/view_model/purchase_draft_view_model.dart';

import '../helpers/device_user.dart';
import '../helpers/purchase.dart';

/// The fake with a switch that makes the next write fail — a browser that
/// denies IndexedDB is the case this ViewModel exists to survive.
class _SpyRepository extends PurchaseDraftRepositoryLocal {
  _SpyRepository({super.initial});

  Object? failNextCall;
  int saveCalls = 0;
  int clearCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<void> save(PurchaseDraft draft) async {
    saveCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.save(draft);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.clear();
  }
}

void main() {
  final crate = optionByPiece(id: 'prod-4', brand: cokeBrand, pieceCount: 12);

  ProviderContainer containerWith(PurchaseDraftRepository repository) =>
      ProviderContainer.test(
        overrides: [
          deviceUserOverride(),
          purchaseDraftRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  PurchaseDraft stored() => PurchaseDraft(
    purchaseId: 'a1',
    date: DateTime(2026, 8, 18),
    registeredBy: 'Leandro',
    storeId: 'store-1',
  ).withItem(purchaseItem(id: 'i1', option: crate, cents: 6200));

  group('build', () {
    test('starts a fresh purchase with this phone label', () {
      final container = containerWith(_SpyRepository());

      final draft = container.read(purchaseDraftViewModelProvider);
      expect(draft.registeredBy, 'Leandro');
      expect(draft.isEmpty, isTrue);
      expect(container.read(recoveryBannerProvider), isFalse);
      expect(draft.purchaseId, hasLength(36));
    });

    test('recovers what was in the box, synchronously', () {
      // Synchronously and not through a Future: screen 3 has to know there is
      // a draft BEFORE any network answer — that is the airplane-mode
      // criterion, and a frame of "no draft" in front of eighteen items would
      // be the story failing in the one moment it exists for.
      final container = containerWith(_SpyRepository(initial: stored()));

      final draft = container.read(purchaseDraftViewModelProvider);
      expect(draft.purchaseId, 'a1');
      expect(draft.items.single.label, 'Refrigerante Coca-Cola 12 × 350 ml');
      expect(container.read(recoveryBannerProvider), isTrue);
    });

    test('a phone with no label still starts a purchase', () {
      // It cannot happen through the router — the redirect sends an unmarked
      // phone to the welcome screen — but a null here must not be an
      // exception thrown from a getter.
      final container = ProviderContainer.test(
        overrides: [
          deviceUserOverride(name: null),
          purchaseDraftRepositoryProvider.overrideWith(
            (ref) => _SpyRepository(),
          ),
        ],
      );

      expect(container.read(purchaseDraftViewModelProvider).registeredBy, '');
    });
  });

  group('mutations', () {
    test('persist BEFORE the state changes', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      expect(await notifier.setStore('store-1'), isNull);

      expect(repository.saveCalls, 1);
      expect(repository.readNow()!.storeId, 'store-1');
      expect(container.read(purchaseDraftViewModelProvider).storeId, 'store-1');
    });

    test('a refused write keeps the purchase on screen and says so', () async {
      // A private window denies IndexedDB. Losing eighteen typed items
      // because of it would be the worst possible outcome — worse than not
      // having persisted them.
      final repository = _SpyRepository()
        ..failNextCall = NetworkException('storage denied');
      final container = containerWith(repository);
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      final error = await notifier.putItem(
        purchaseItem(id: 'i1', option: crate, cents: 6200),
      );

      expect(error, isNotNull);
      // The sentence, never the raw exception.
      expect(error, isNot(contains('NetworkException')));
      expect(error, isNot(contains('storage denied')));
      // And the item is still there.
      expect(
        container.read(purchaseDraftViewModelProvider).items.single.paid,
        const Money(6200),
      );
    });

    test('putItem replaces the line with the same id', () async {
      // That is what `[ed]` does: it corrects a line, it does not append one.
      final container = containerWith(_SpyRepository());
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      await notifier.putItem(
        purchaseItem(id: 'i1', option: crate, cents: 6200),
      );
      await notifier.putItem(
        purchaseItem(id: 'i1', option: crate, cents: 5900),
      );

      final draft = container.read(purchaseDraftViewModelProvider);
      expect(draft.items, hasLength(1));
      expect(draft.total, const Money(5900));
    });

    test('removeItem takes the line out', () async {
      final container = containerWith(_SpyRepository());
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      await notifier.putItem(
        purchaseItem(id: 'i1', option: crate, cents: 6200),
      );
      await notifier.removeItem('i1');

      expect(container.read(purchaseDraftViewModelProvider).items, isEmpty);
    });

    test('setDate keeps the purchase key', () async {
      // The key is what `on conflict (id) do nothing` conflicts on: a resend
      // that found a different one would be a second purchase.
      final container = containerWith(_SpyRepository(initial: stored()));
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      await notifier.setDate(DateTime(2026, 8, 17));

      final draft = container.read(purchaseDraftViewModelProvider);
      expect(draft.purchaseId, 'a1');
      expect(draft.date, DateTime(2026, 8, 17));
    });

    test('markPending is what the resend later looks for', () async {
      final repository = _SpyRepository(initial: stored());
      final container = containerWith(repository);

      await container
          .read(purchaseDraftViewModelProvider.notifier)
          .markPending();

      expect(repository.readNow()!.pendingSubmission, isTrue);
    });

    test('a double tap writes once', () async {
      // The guard of rule 14. This test has to FAIL if it is removed.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      final notifier = container.read(
        purchaseDraftViewModelProvider.notifier,
      );

      final first = notifier.setStore('store-1');
      final second = notifier.setStore('store-2');

      expect(await first, isNull);
      expect(await second, isNull, reason: 'the guard answers null');
      expect(repository.saveCalls, 1);
      expect(container.read(purchaseDraftViewModelProvider).storeId, 'store-1');
    });
  });

  group('the banner', () {
    test('dismissing it survives a rebuild of the notifier', () async {
      // Changing the device label in Configurações invalidates
      // `storedDeviceUserProvider`, and Riverpod recreates this notifier. A
      // dismissal that lived in memory would bring the banner back with it.
      final repository = _SpyRepository(initial: stored());
      final container = containerWith(repository);

      expect(container.read(recoveryBannerProvider), isTrue);
      await container
          .read(purchaseDraftViewModelProvider.notifier)
          .dismissBanner();

      container.invalidate(storedDeviceUserProvider);

      expect(container.read(recoveryBannerProvider), isFalse);
      // And the purchase itself is untouched.
      expect(container.read(purchaseDraftViewModelProvider).items, hasLength(1));
    });

    test('a purchase typed in THIS run never shows the banner', () async {
      // The hole an entity flag could not close: a draft saved a moment ago
      // and read back after a rebuild would call itself "recuperado" while
      // the person is still typing it.
      final container = containerWith(_SpyRepository());
      await container
          .read(purchaseDraftViewModelProvider.notifier)
          .setStore('store-1');

      container.invalidate(storedDeviceUserProvider);

      expect(container.read(recoveryBannerProvider), isFalse);
      expect(
        container.read(purchaseDraftViewModelProvider).storeId,
        'store-1',
        reason: 'and the purchase survived the rebuild',
      );
    });

    test('discarding throws the recovered purchase away', () async {
      final repository = _SpyRepository(initial: stored());
      final container = containerWith(repository);

      expect(
        await container
            .read(purchaseDraftViewModelProvider.notifier)
            .discard(),
        isNull,
      );

      expect(repository.readNow(), isNull);
      // And the banner is gone: what is on screen now was born here.
      expect(container.read(recoveryBannerProvider), isFalse);
      final draft = container.read(purchaseDraftViewModelProvider);
      expect(draft.isEmpty, isTrue);
      expect(draft.purchaseId, isNot('a1'), reason: 'a new purchase begins');
      expect(draft.registeredBy, 'Leandro', reason: 'the label is kept');
    });
  });

  group('clear', () {
    test('starts a new purchase after a successful save', () async {
      final repository = _SpyRepository(initial: stored());
      final container = containerWith(repository);

      await container.read(purchaseDraftViewModelProvider.notifier).clear();

      expect(repository.clearCalls, 1);
      expect(container.read(purchaseDraftViewModelProvider).isEmpty, isTrue);
      // Without this the banner would come back over the next purchase.
      expect(container.read(recoveryBannerProvider), isFalse);
    });

    test('a failed erase still starts a new purchase, and says so', () async {
      // The purchase IS registered. Leaving it on screen would invite a
      // second save of something that already exists.
      final repository = _SpyRepository(initial: stored())
        ..failNextCall = NetworkException('storage denied');
      final container = containerWith(repository);

      final error = await container
          .read(purchaseDraftViewModelProvider.notifier)
          .clear();

      expect(error, isNotNull);
      expect(error, isNot(contains('NetworkException')));
      expect(container.read(purchaseDraftViewModelProvider).isEmpty, isTrue);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository.dart';
import 'package:shopping_list/data/repositories/purchase/purchase_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/purchase/view_model/purchase_history_view_model.dart';

/// The `_local` fake with a switch that makes the next page fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends PurchaseRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int pageCalls = 0;
  final List<int> offsets = [];

  @override
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  }) async {
    pageCalls++;
    offsets.add(offset);
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchPage(offset: offset, limit: limit);
  }
}

void main() {
  ProviderContainer containerWith(PurchaseRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          purchaseRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  test('opens with the first page, newest first', () async {
    final container = containerWith(_SpyRepository());

    final state = await container.read(purchaseHistoryViewModelProvider.future);

    // The fake holds 25 purchases and the page is 20 — the only place
    // "carregar mais" is exercised without a database.
    expect(state.purchases, hasLength(PurchaseHistoryViewModel.pageSize));
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
    expect(state.purchases.first.purchaseDate, DateTime(2026, 8, 28));
    expect(state.purchases.first.storeName, 'Carrefour');
  });

  test('loadMore appends and turns hasMore off on the last page', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);

    final error = await container
        .read(purchaseHistoryViewModelProvider.notifier)
        .loadMore();

    expect(error, isNull);
    final state = container.read(purchaseHistoryViewModelProvider).value!;
    expect(state.purchases, hasLength(25));
    expect(state.hasMore, isFalse);
    expect(state.loadingMore, isFalse);
    // The offset is the length of what is already on screen, not a page
    // number — a purchase inserted in between would shift a page number.
    expect(repository.offsets, [0, 20]);
  });

  test('loadMore on the last page does nothing at all', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);
    await container.read(purchaseHistoryViewModelProvider.notifier).loadMore();

    expect(
      await container
          .read(purchaseHistoryViewModelProvider.notifier)
          .loadMore(),
      isNull,
    );
    expect(repository.pageCalls, 2);
  });

  test('a double tap on loadMore fires ONE request', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);

    final notifier = container.read(
      purchaseHistoryViewModelProvider.notifier,
    );
    // Not awaited in sequence ON PURPOSE: this is the double tap, and without
    // the reentrancy guard both calls would go through and the second page
    // would be appended twice.
    await Future.wait([notifier.loadMore(), notifier.loadMore()]);

    expect(repository.pageCalls, 2);
    expect(
      container.read(purchaseHistoryViewModelProvider).value!.purchases,
      hasLength(25),
    );
  });

  test('a failed loadMore keeps the page on screen and returns a sentence', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);

    repository.failNextCall = NetworkException('down');
    final error = await container
        .read(purchaseHistoryViewModelProvider.notifier)
        .loadMore();

    expect(error, isNotNull);
    // The raw exception NEVER reaches the sentence (rule 10).
    expect(error, isNot(contains('down')));
    final state = container.read(purchaseHistoryViewModelProvider).value!;
    expect(state.purchases, hasLength(20));
    expect(state.loadingMore, isFalse);
    expect(state.hasMore, isTrue);
  });

  test('refresh that works goes back to one page', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);
    await container.read(purchaseHistoryViewModelProvider.notifier).loadMore();

    final error = await container
        .read(purchaseHistoryViewModelProvider.notifier)
        .refresh();

    expect(error, isNull);
    expect(
      container.read(purchaseHistoryViewModelProvider).value!.purchases,
      hasLength(20),
    );
  });

  test('a failed refresh WITH data keeps the list and returns a sentence', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(purchaseHistoryViewModelProvider.future);

    repository.failNextCall = NetworkException('down');
    final error = await container
        .read(purchaseHistoryViewModelProvider.notifier)
        .refresh();

    expect(error, isNotNull);
    final state = container.read(purchaseHistoryViewModelProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.purchases, hasLength(20));
  });

  test('a failed load WITHOUT data occupies the screen', () async {
    // Leaving it in AsyncLoading is a spinner that never resolves.
    final repository = _SpyRepository()..failNextCall = NetworkException('down');
    final container = containerWith(repository);

    await expectLater(
      container.read(purchaseHistoryViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );
    expect(container.read(purchaseHistoryViewModelProvider).hasError, isTrue);
  });

  test('a failed refresh WITHOUT data lands in AsyncError, not AsyncLoading', () async {
    final repository = _SpyRepository()..failNextCall = NetworkException('down');
    final container = containerWith(repository);
    await expectLater(
      container.read(purchaseHistoryViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );

    repository.failNextCall = NetworkException('still down');
    final error = await container
        .read(purchaseHistoryViewModelProvider.notifier)
        .refresh();

    expect(error, isNotNull);
    final state = container.read(purchaseHistoryViewModelProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
  });

  group('PurchaseHistoryState — the middle link of the equality chain', () {
    test('two states with the same fields are equal', () async {
      final container = containerWith(_SpyRepository());
      final first = await container.read(
        purchaseHistoryViewModelProvider.future,
      );

      final same = PurchaseHistoryState(
        purchases: first.purchases,
        hasMore: first.hasMore,
        loadingMore: first.loadingMore,
      );
      expect(first, same);
      expect(first.hashCode, same.hashCode);
    });

    test('one field at a time breaks it', () async {
      final container = containerWith(_SpyRepository());
      final first = await container.read(
        purchaseHistoryViewModelProvider.future,
      );

      // Without these three, `AsyncData` compares by reference: the history
      // repaints on every loadMore and the scroll jumps back to the top.
      expect(first, isNot(first.copyWith(hasMore: !first.hasMore)));
      expect(first, isNot(first.copyWith(loadingMore: true)));
      expect(
        first,
        isNot(first.copyWith(purchases: first.purchases.removeAt(0))),
      );
    });
  });
}

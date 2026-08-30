import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/purchase/purchase_repository.dart';
import '../../../domain/models/purchase_summary.dart';
import '../../core/error_translation.dart';

/// The paginated history. The state is the accumulated page plus "há mais?"
/// and "estou buscando a próxima" — three things the screen reads together
/// and that change together.
///
/// A `final class` with `==`/`hashCode` over the three fields, and not a
/// record (rule 16). Here the `==` is not hygiene: this is the `T` of an
/// AsyncNotifier, and without it `AsyncData` compares by reference — the
/// history would repaint whole on every `loadMore`, with the scroll jumping
/// back to the top, and no error anywhere.
final class PurchaseHistoryState {
  const PurchaseHistoryState({
    required this.purchases,
    required this.hasMore,
    required this.loadingMore,
  });

  final IList<PurchaseSummary> purchases;

  /// Whether the repository still has a page behind this one. It is answered
  /// by the extra row the query asks for, never by a second count.
  final bool hasMore;

  /// The footer's spinner. The list stays on screen the whole time: a
  /// `loadMore` that swapped the state for `AsyncLoading` would blank the
  /// page someone is reading.
  final bool loadingMore;

  PurchaseHistoryState copyWith({
    IList<PurchaseSummary>? purchases,
    bool? hasMore,
    bool? loadingMore,
  }) => PurchaseHistoryState(
    purchases: purchases ?? this.purchases,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseHistoryState &&
          other.purchases == purchases &&
          other.hasMore == hasMore &&
          other.loadingMore == loadingMore);

  @override
  int get hashCode => Object.hash(purchases, hasMore, loadingMore);
}

/// Screen `/purchases` — the app's only paginated screen.
final class PurchaseHistoryViewModel
    extends AsyncNotifier<PurchaseHistoryState> {
  /// Twenty per page: `tecnico §1.9` sizes the month at ~170 items over ~8
  /// trips, so one page is more than a month of purchases — and it is what
  /// fits in one scroll on a phone without a second round trip on the first
  /// touch.
  static const pageSize = 20;

  /// Guards the reload. `loadMore` has one of ITS OWN below: sharing a flag
  /// would let a pull-to-refresh block the footer button, and the other way
  /// round.
  bool _running = false;
  bool _loadingMore = false;

  @override
  Future<PurchaseHistoryState> build() async {
    final page = await ref
        .watch(purchaseRepositoryProvider)
        .fetchPage(offset: 0, limit: pageSize);

    return PurchaseHistoryState(
      purchases: page.purchases,
      hasMore: page.hasMore,
      loadingMore: false,
    );
  }

  /// `[ Carregar mais ]`. Returns null on success, or the pt-BR sentence for
  /// the SnackBar — the page already on screen stays there either way.
  Future<String?> loadMore() async {
    if (_loadingMore) return null;
    final current = state.value;
    if (current == null || !current.hasMore) return null;

    _loadingMore = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(purchaseRepositoryProvider)
          .fetchPage(offset: current.purchases.length, limit: pageSize);
      if (!ref.mounted) return null;

      // Never AsyncLoading: the list has to stay on screen while the next
      // page comes, and the footer is what says something is happening.
      state = AsyncData(
        current.copyWith(
          purchases: current.purchases.addAll(page.purchases),
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      state = AsyncData(current.copyWith(loadingMore: false));
      return translateError(e, st, 'carregar mais compras');
    } finally {
      _loadingMore = false;
    }
  }

  /// Reloads from the first page — the pull-to-refresh, and what the
  /// correction screen leaves behind it.
  Future<String?> refresh() async {
    if (_running) return null;
    _running = true;
    try {
      // Pure AsyncLoading: Riverpod 3 keeps the previous value on its own, and
      // copyWithPrevious is @internal since 3.0.
      state = const AsyncLoading<PurchaseHistoryState>();

      final page = await ref
          .read(purchaseRepositoryProvider)
          .fetchPage(offset: 0, limit: pageSize);
      if (!ref.mounted) return null;

      state = AsyncData(
        PurchaseHistoryState(
          purchases: page.purchases,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
      return null;
    } on Object catch (e, st) {
      if (!ref.mounted) return null;

      final message = translateError(e, st, 'atualizar o histórico');
      // With nothing to fall back on the failure has to OCCUPY the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      state = state.hasValue
          ? AsyncData(state.value!)
          : AsyncError<PurchaseHistoryState>(e, st);
      return message;
    } finally {
      _running = false;
    }
  }
}

/// `retry: null` on purpose: Riverpod 3 retries a failing provider ten times
/// with a growing backoff, and on a screen the error has to be visible now.
final purchaseHistoryViewModelProvider =
    AsyncNotifierProvider<PurchaseHistoryViewModel, PurchaseHistoryState>(
      PurchaseHistoryViewModel.new,
      retry: (retryCount, error) => null,
    );

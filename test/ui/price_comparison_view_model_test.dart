import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/report/report_repository.dart';
import 'package:shopping_list/data/repositories/report/report_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/ui/report/view_model/price_comparison_view_model.dart';

/// The `_local` fake with a switch that makes the next query fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends ReportRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int calls = 0;
  final List<DateTime> asked = [];

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    calls++;
    asked.add(since);
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchPriceQuotes(since);
  }
}

void main() {
  /// Every case pins the instant: the window is rolling, so without it the
  /// cases pass in August and fail in September, on a CI nobody touched.
  final today = DateTime(2026, 8, 15);

  ProviderContainer containerWith(ReportRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          reportRepositoryProvider.overrideWith((ref) => repository),
          priceComparisonViewModelProvider.overrideWith(
            () => PriceComparisonViewModel(today: today),
          ),
        ],
      );

  group('the load', () {
    test('asks for the rolling window of three months', () async {
      // Three CALENDAR months back from the pinned day, and the month in
      // progress is INSIDE it — that is the whole difference from the closed
      // window of H17.
      final repository = _SpyRepository();
      final container = containerWith(repository);

      await container.read(priceComparisonViewModelProvider.future);

      expect(repository.asked.single, DateTime(2026, 5, 15));
    });

    test('the clock is read ONCE, and rounded to the day', () async {
      // An instant with an hour inside would give a different `since` on
      // every load, and the `==` of the quotes would stop filtering anything.
      final container = ProviderContainer.test(
        overrides: <Override>[
          reportRepositoryProvider.overrideWith(
            (ref) => ReportRepositoryLocal(latency: Duration.zero),
          ),
          priceComparisonViewModelProvider.overrideWith(
            () => PriceComparisonViewModel(
              today: DateTime(2026, 8, 15, 21, 47, 3),
            ),
          ),
        ],
      );

      expect(
        container.read(priceComparisonViewModelProvider.notifier).today,
        DateTime(2026, 8, 15),
      );
    });

    test('brings the quotes flat, with nothing reduced', () async {
      final container = containerWith(_SpyRepository());

      final quotes = await container.read(
        priceComparisonViewModelProvider.future,
      );

      // Six purchases, three of them the SAME leaf in three stores: the
      // repository reduces nothing (rule 3).
      expect(quotes, hasLength(6));
      expect(
        quotes.where((quote) => quote.productId == 'prod-4'),
        hasLength(3),
      );
    });

    test('a failed load occupies the tab, not a spinner forever', () async {
      final container = containerWith(
        _SpyRepository()..failNextCall = NetworkException('offline'),
      );

      await expectLater(
        container.read(priceComparisonViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(
        container.read(priceComparisonViewModelProvider).hasError,
        isTrue,
      );
    });
  });

  group('refresh', () {
    test('a refresh that works puts the quotes back', () async {
      final repository = _SpyRepository()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(repository);
      await expectLater(
        container.read(priceComparisonViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );

      final error = await container
          .read(priceComparisonViewModelProvider.notifier)
          .refresh();

      expect(error, isNull);
      expect(
        container.read(priceComparisonViewModelProvider).value,
        isNotEmpty,
      );
    });

    test('a failed refresh WITH data on screen keeps the data', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(priceComparisonViewModelProvider.future);

      repository.failNextCall = ApiException(500, 'boom');
      final error = await container
          .read(priceComparisonViewModelProvider.notifier)
          .refresh();

      expect(error, 'O servidor está indisponível. Tente de novo em instantes.');
      // The comparison stays on screen: a failed reload changes nothing
      // visible, and the sentence is what says why.
      expect(
        container.read(priceComparisonViewModelProvider).value,
        isNotEmpty,
      );
      expect(
        container.read(priceComparisonViewModelProvider).hasError,
        isFalse,
      );
    });

    test('a failed refresh with NOTHING on screen becomes an error', () async {
      final repository = _SpyRepository()
        ..failNextCall = NetworkException('offline');
      final container = containerWith(repository);
      await expectLater(
        container.read(priceComparisonViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );

      repository.failNextCall = NetworkException('offline');
      final error = await container
          .read(priceComparisonViewModelProvider.notifier)
          .refresh();

      expect(error, 'Sem conexão. Verifique a internet e tente de novo.');
      expect(
        container.read(priceComparisonViewModelProvider).hasError,
        isTrue,
      );
    });

    test('a double tap on ↻ reloads once', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(priceComparisonViewModelProvider.future);
      expect(repository.calls, 1);

      final notifier = container.read(
        priceComparisonViewModelProvider.notifier,
      );
      final results = await Future.wait([notifier.refresh(), notifier.refresh()]);

      expect(repository.calls, 2);
      // The second one did nothing, and says so with a null — not a third
      // outcome.
      expect(results, [null, null]);
    });

    test('unwraps a ProviderException however deep it is nested', () async {
      // Riverpod wraps one layer PER HOP of the provider chain, so the unwrap
      // is a loop. If it becomes a single `if`, this reads the generic
      // sentence.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(priceComparisonViewModelProvider.future);

      // `ProviderException` is @internal, and building one by hand is the only
      // way to exercise the loop that unwraps it.
      // ignore: invalid_use_of_internal_member
      repository.failNextCall = ProviderException(
        // ignore: invalid_use_of_internal_member
        ProviderException(NetworkException('offline'), StackTrace.empty),
        StackTrace.empty,
      );

      expect(
        await container
            .read(priceComparisonViewModelProvider.notifier)
            .refresh(),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
    });
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/type_consumption.dart';
import 'package:shopping_list/ui/consumption/view_model/monthly_average_view_model.dart';

/// The `_local` fake with a switch that makes the next query fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends ConsumptionRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int calls = 0;
  final List<ReportPeriod> windowsAsked = [];
  final List<ReportPeriod> monthsAsked = [];

  @override
  Future<IList<TypeConsumption>> fetchTypeConsumption({
    required ReportPeriod window,
    required ReportPeriod month,
  }) async {
    calls++;
    windowsAsked.add(window);
    monthsAsked.add(month);
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchTypeConsumption(window: window, month: month);
  }
}

void main() {
  /// Every case pins the instant: both intervals come off the clock, so
  /// without it the cases pass in August and fail in September, on a CI nobody
  /// touched.
  final today = DateTime(2026, 8, 15);

  ProviderContainer containerWith(ConsumptionRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          consumptionRepositoryProvider.overrideWith((ref) => repository),
          monthlyAverageViewModelProvider.overrideWith(
            () => MonthlyAverageViewModel(today: today),
          ),
        ],
      );

  group('the clock enters here, and only here', () {
    test('asks for the CLOSED window and the month in progress', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);

      await container.read(monthlyAverageViewModelProvider.future);

      // The three closed months before August — the month in progress is
      // deliberately OUT of it, which is the whole difference from the rolling
      // window of H15/H16.
      expect(
        repository.windowsAsked.single,
        ReportPeriod(from: DateTime(2026, 5, 1), to: DateTime(2026, 7, 31)),
      );
      expect(
        repository.monthsAsked.single,
        ReportPeriod(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)),
      );
    });

    test('the clock is read ONCE, and rounded to the day', () async {
      // An instant with an hour inside would give a different window on every
      // read and break the `==` Riverpod filters updates with.
      final container = ProviderContainer.test(
        overrides: <Override>[
          consumptionRepositoryProvider.overrideWith((ref) => _SpyRepository()),
          monthlyAverageViewModelProvider.overrideWith(
            () => MonthlyAverageViewModel(today: DateTime(2026, 8, 15, 23, 59)),
          ),
        ],
      );
      await container.read(monthlyAverageViewModelProvider.future);

      expect(
        container.read(monthlyAverageViewModelProvider.notifier).today,
        DateTime(2026, 8, 15),
      );
    });

    test('without an instant it reads the phone, rounded to the day', () {
      // The screens pass nothing: this is the seam, and the default is the
      // real clock.
      final notifier = MonthlyAverageViewModel();
      expect(notifier.today.hour, 0);
      expect(notifier.today.minute, 0);
    });
  });

  group('the load', () {
    test('divides, rounds and tells the written story of the fake', () async {
      // The five lines of `ConsumptionRepositoryLocal`, and every one of them
      // is a rule of requirement 8 made visible.
      final container = containerWith(_SpyRepository());
      final lines = await container.read(
        monthlyAverageViewModelProvider.future,
      );

      final byName = {for (final line in lines) line.type.name: line};

      // Bought before the window: divides by three. 24 kg ÷ 3 = 8 kg.
      expect(byName['Acém moído']!.average, 8000);
      expect(byName['Acém moído']!.remainingForMonth, 2000);

      // First bought in June: divides by TWO. 16 kg ÷ 2 = 8 kg.
      expect(byName['Sabão em pó']!.average, 8000);
      expect(byName['Sabão em pó']!.remainingForMonth, 1200);

      // One purchase inside the window, but bought since March: divides by
      // three all the same, and 666,66… g rounds to 0,7 kg.
      expect(byName['Café']!.average, 700);

      // Bought in all three months: 12,6 L ÷ 3 = 4,2 L, exactly what August
      // already bought. Nothing missing.
      expect(byName['Refrigerante']!.average, 4200);
      expect(byName['Refrigerante']!.hasShortage, isFalse);

      // First bought THIS month: no closed month, so the average is the
      // month's own purchase and nothing is ever missing of it.
      expect(byName['Papel higiênico']!.average, 12);
      expect(byName['Papel higiênico']!.hasShortage, isFalse);
    });

    test('one call answers both screens', () async {
      // The reason the two stories are neighbours: whoever goes from the
      // suggestion to "falta comprar" reads what is already in memory.
      final repository = _SpyRepository();
      final container = containerWith(repository);

      await container.read(monthlyAverageViewModelProvider.future);
      await container.read(monthlyAverageViewModelProvider.future);

      expect(repository.calls, 1);
    });

    test('a failing load occupies the screen', () async {
      // With nothing to fall back on the failure has to BE the screen:
      // leaving it in AsyncLoading is a spinner that never resolves.
      final repository = _SpyRepository()
        ..failNextCall = ApiException(500, 'boom');
      final container = containerWith(repository);

      await expectLater(
        container.read(monthlyAverageViewModelProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(monthlyAverageViewModelProvider).hasError, isTrue);
    });
  });

  group('refresh', () {
    test('that works puts the lines back', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(monthlyAverageViewModelProvider.future);

      expect(
        await container
            .read(monthlyAverageViewModelProvider.notifier)
            .refresh(),
        isNull,
      );
      expect(repository.calls, 2);
      expect(container.read(monthlyAverageViewModelProvider).value, isNotEmpty);
    });

    test('that fails WITH data keeps what is on screen and returns the '
        'sentence', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      final before = await container.read(
        monthlyAverageViewModelProvider.future,
      );

      repository.failNextCall = ApiException(500, 'boom');
      final message = await container
          .read(monthlyAverageViewModelProvider.notifier)
          .refresh();

      expect(message, isNotNull);
      // The raw exception NEVER reaches the user.
      expect(message, isNot(contains('boom')));
      expect(container.read(monthlyAverageViewModelProvider).value, before);
      expect(container.read(monthlyAverageViewModelProvider).hasError, isFalse);
    });

    test('that fails with NO data turns the state into AsyncError', () async {
      // The other half of the same rule, and the one a `hasValue` check gets
      // wrong: a refresh over a screen that never loaded has nothing to keep.
      final repository = _SpyRepository()
        ..failNextCall = ApiException(500, 'boom');
      final container = containerWith(repository);

      await expectLater(
        container.read(monthlyAverageViewModelProvider.future),
        throwsA(isA<ApiException>()),
      );

      repository.failNextCall = ApiException(503, 'still down');
      final message = await container
          .read(monthlyAverageViewModelProvider.notifier)
          .refresh();

      expect(message, isNotNull);
      expect(container.read(monthlyAverageViewModelProvider).hasError, isTrue);
    });

    test('guards against the double tap', () async {
      // Without the guard this fires two queries. The case has to FAIL if the
      // `if (_running) return null;` is removed.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(monthlyAverageViewModelProvider.future);

      final notifier = container.read(monthlyAverageViewModelProvider.notifier);
      final results = await Future.wait([
        notifier.refresh(),
        notifier.refresh(),
      ]);

      expect(repository.calls, 2, reason: 'the build plus ONE refresh');
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
      await container.read(monthlyAverageViewModelProvider.future);

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
            .read(monthlyAverageViewModelProvider.notifier)
            .refresh(),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
    });
  });
}

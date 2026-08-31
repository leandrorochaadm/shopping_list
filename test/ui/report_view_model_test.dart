import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/report/report_repository.dart';
import 'package:shopping_list/data/repositories/report/report_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/period_report.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/ui/report/view_model/report_period_notifier.dart';
import 'package:shopping_list/ui/report/view_model/report_view_model.dart';

/// The `_local` fake with a switch that makes the next query fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends ReportRepositoryLocal {
  _SpyRepository() : super(latency: Duration.zero);

  Object? failNextCall;
  int calls = 0;
  final List<ReportPeriod> asked = [];

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    calls++;
    asked.add(period);
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.fetchPeriodReport(period);
  }
}

void main() {
  /// Every case pins the instant: without it the cases that read August pass
  /// in August and fail in September, on a CI nobody touched.
  final today = DateTime(2026, 8, 15);

  ProviderContainer containerWith(ReportRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          reportRepositoryProvider.overrideWith((ref) => repository),
          reportPeriodProvider.overrideWith(
            () => ReportPeriodNotifier(today: today),
          ),
        ],
      );

  group('the load', () {
    test('opens on the month in progress', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);

      await container.read(reportViewModelProvider.future);

      expect(repository.asked.single.from, DateTime(2026, 8, 1));
      expect(repository.asked.single.to, DateTime(2026, 8, 31));
    });

    test('brings the written numbers of requirement 4', () async {
      final container = containerWith(_SpyRepository());

      final report = await container.read(reportViewModelProvider.future);

      final beef = report.types.firstWhere((t) => t.productTypeId == 'type-2');
      expect(beef.quantityInBaseUnit, 6000);
      expect(beef.spent, const Money(19200));
      expect(beef.costPerBaseUnit, 3200);

      final powder = report.types.firstWhere(
        (t) => t.productTypeId == 'type-4',
      );
      expect(powder.quantityInBaseUnit, 6800);
      expect(powder.spent, const Money(13600));
      expect(powder.costPerBaseUnit, 2000);
    });

    test('a failing load occupies the screen', () async {
      final repository = _SpyRepository()
        ..failNextCall = ApiException(500, 'boom');
      final container = containerWith(repository);

      await expectLater(
        container.read(reportViewModelProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(reportViewModelProvider).hasError, isTrue);
    });
  });

  group('refresh', () {
    test('a refresh that works puts the report back', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(reportViewModelProvider.future);

      expect(
        await container.read(reportViewModelProvider.notifier).refresh(),
        isNull,
      );
      expect(container.read(reportViewModelProvider).value!.isEmpty, isFalse);
      expect(repository.calls, 2);
    });

    test(
      'a failing refresh keeps the report and returns the sentence',
      () async {
        final repository = _SpyRepository();
        final container = containerWith(repository);
        final loaded = await container.read(reportViewModelProvider.future);

        repository.failNextCall = NetworkException('offline');
        final message = await container
            .read(reportViewModelProvider.notifier)
            .refresh();

        expect(message, 'Sem conexão. Verifique a internet e tente de novo.');
        // The report stays on the screen: only the SnackBar says something went
        // wrong.
        expect(container.read(reportViewModelProvider).value, loaded);
        expect(container.read(reportViewModelProvider).hasError, isFalse);
      },
    );

    test('a failure with NO previous report becomes AsyncError', () async {
      // Leaving it in AsyncLoading is a spinner that never resolves.
      final repository = _SpyRepository()
        ..failNextCall = ApiException(500, 'boom');
      final container = containerWith(repository);

      await expectLater(
        container.read(reportViewModelProvider.future),
        throwsA(isA<ApiException>()),
      );

      repository.failNextCall = ApiException(500, 'boom');
      final message = await container
          .read(reportViewModelProvider.notifier)
          .refresh();

      expect(
        message,
        'O servidor está indisponível. Tente de novo em instantes.',
      );
      expect(container.read(reportViewModelProvider).hasError, isTrue);
    });

    test('a double tap fires ONE query, not two', () async {
      // The reentrancy guard of rule 14. Remove `_running` and this reads 3.
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(reportViewModelProvider.future);
      final notifier = container.read(reportViewModelProvider.notifier);

      final results = await Future.wait([
        notifier.refresh(),
        notifier.refresh(),
      ]);

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
      await container.read(reportViewModelProvider.future);

      // `ProviderException` is @internal, and building one by hand is the only
      // way to exercise the loop that unwraps it.
      // ignore: invalid_use_of_internal_member
      repository.failNextCall = ProviderException(
        // ignore: invalid_use_of_internal_member
        ProviderException(NetworkException('offline'), StackTrace.empty),
        StackTrace.empty,
      );

      expect(
        await container.read(reportViewModelProvider.notifier).refresh(),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
    });
  });

  group('the period drives the load', () {
    test(
      'shifting a month asks the repository again, for that month',
      () async {
        final repository = _SpyRepository();
        final container = containerWith(repository);
        await container.read(reportViewModelProvider.future);

        container.read(reportPeriodProvider.notifier).shiftMonth(-1);
        await container.read(reportViewModelProvider.future);

        expect(repository.asked, hasLength(2));
        expect(repository.asked.last.from, DateTime(2026, 7, 1));
        expect(repository.asked.last.to, DateTime(2026, 7, 31));
      },
    );

    test('the month before holds what August does not', () async {
      final container = containerWith(_SpyRepository());
      await container.read(reportViewModelProvider.future);

      container.read(reportPeriodProvider.notifier).shiftMonth(-1);
      final july = await container.read(reportViewModelProvider.future);

      // The July seed: one crate of soft drink, 2 kg of beef and — since H17,
      // when the two fakes started telling the same story (decision E-l) —
      // 8 kg of washing powder for R$ 160,00.
      expect(july.total, const Money(27990));
    });

    test('a period with no purchase is empty, and not an error', () async {
      final container = containerWith(_SpyRepository());
      await container.read(reportViewModelProvider.future);

      container.read(reportPeriodProvider.notifier)
        ..setFrom(DateTime(2019, 1, 1))
        ..setTo(DateTime(2019, 1, 31));
      final report = await container.read(reportViewModelProvider.future);

      expect(report.isEmpty, isTrue);
      expect(container.read(reportViewModelProvider).hasError, isFalse);
    });

    test('an inverted interval is refused and changes nothing', () async {
      final repository = _SpyRepository();
      final container = containerWith(repository);
      await container.read(reportViewModelProvider.future);
      final before = container.read(reportPeriodProvider);

      final message = container
          .read(reportPeriodProvider.notifier)
          .setFrom(DateTime(2026, 9, 10));

      expect(message, 'A data inicial não pode ser depois da final.');
      expect(container.read(reportPeriodProvider), before);
      // And no second query went out for a period that was never accepted.
      expect(repository.calls, 1);
    });

    test('setTo before from is refused the same way', () async {
      final container = containerWith(_SpyRepository());
      await container.read(reportViewModelProvider.future);
      final before = container.read(reportPeriodProvider);

      expect(
        container
            .read(reportPeriodProvider.notifier)
            .setTo(DateTime(2026, 7, 1)),
        'A data inicial não pode ser depois da final.',
      );
      expect(container.read(reportPeriodProvider), before);
    });

    test('a valid pair of dates goes through and returns null', () async {
      final container = containerWith(_SpyRepository());
      final notifier = container.read(reportPeriodProvider.notifier);

      expect(notifier.setFrom(DateTime(2026, 8, 10)), isNull);
      expect(notifier.setTo(DateTime(2026, 8, 20)), isNull);
      expect(
        container.read(reportPeriodProvider),
        ReportPeriod(from: DateTime(2026, 8, 10), to: DateTime(2026, 8, 20)),
      );
    });
  });

  group('the clock enters here, and only here', () {
    test('without an instant it reads the phone, rounded to the day', () {
      // The one place `DateTime.now()` is allowed in this feature (rule 9).
      final container = ProviderContainer.test(
        overrides: <Override>[
          reportRepositoryProvider.overrideWith((ref) => _SpyRepository()),
        ],
      );

      final period = container.read(reportPeriodProvider);
      final notifier = container.read(reportPeriodProvider.notifier);

      expect(notifier.today.hour, 0);
      expect(period, ReportPeriod.monthOf(notifier.today));
    });
  });
}

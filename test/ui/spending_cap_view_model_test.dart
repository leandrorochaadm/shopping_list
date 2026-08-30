import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/ui/settings/view_model/spending_cap_view_model.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends SpendingCapRepositoryLocal {
  _SpyRepository({
    super.cap,
    super.spending,
    super.alerts,
    required super.today,
  }) : super(latency: Duration.zero);

  Object? failNextCall;
  int reads = 0;
  int writes = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(IList<ReportPeriod> months) async {
    reads++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchStatuses(months);
  }

  @override
  Future<void> save({
    required SpendingCap cap,
    required CapAlerts alerts,
  }) async {
    writes++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.save(cap: cap, alerts: alerts);
  }
}

void main() {
  /// Every case pins the instant: without it the cases that read August pass
  /// in August and fail in September, on a CI nobody touched.
  final today = DateTime(2026, 8, 15);
  final august = ReportPeriod.monthOf(today);
  final cap1500 = SpendingCap(
    amount: const Money(150000),
    effectiveFrom: DateTime(2026, 8, 1),
  );

  _SpyRepository spyWith({
    SpendingCap? cap,
    Map<DateTime, Money>? spending,
    Map<DateTime, CapAlerts>? alerts,
  }) => _SpyRepository(
    cap: cap,
    spending: spending,
    alerts: alerts,
    today: today,
  );

  ProviderContainer containerWith(SpendingCapRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          spendingCapRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  group('the load', () {
    test('brings the cap, the spending and the marks of the month', () async {
      final container = containerWith(
        spyWith(cap: cap1500, spending: {DateTime(2026, 8, 1): const Money(130000)}),
      );

      final status = await container.read(
        spendingCapViewModelProvider(august).future,
      );

      expect(status.month, DateTime(2026, 8, 1));
      expect(status.cap, cap1500);
      expect(status.spent, const Money(130000));
      expect(status.alerts.warned80, isFalse);
    });

    test('a month with no cap is a state, not an error', () async {
      final container = containerWith(
        spyWith(spending: {DateTime(2026, 8, 1): const Money(130000)}),
      );
      // `cap: null` with `hasCap` off is what "nunca configuraram um teto"
      // looks like: the fake below simply has none in force for July.
      final july = ReportPeriod.monthOf(DateTime(2026, 7, 15));

      final container2 = containerWith(
        spyWith(
          cap: SpendingCap(
            amount: const Money(150000),
            effectiveFrom: DateTime(2026, 8, 1),
          ),
        ),
      );

      expect(
        (await container.read(spendingCapViewModelProvider(august).future))
            .hasCap,
        isTrue,
      );
      expect(
        (await container2.read(spendingCapViewModelProvider(july).future))
            .hasCap,
        isFalse,
      );
    });

    test('a failure with nothing to fall back on occupies the screen', () async {
      final repository = spyWith()..failNextCall = NetworkException('offline');
      final container = containerWith(repository);

      await expectLater(
        container.read(spendingCapViewModelProvider(august).future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(spendingCapViewModelProvider(august)).hasError, isTrue);
    });
  });

  group('refresh', () {
    test('re-reads and succeeds', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      expect(
        await container.read(spendingCapViewModelProvider(august).notifier).refresh(),
        isNull,
      );
      expect(repository.reads, 2);
      expect(container.read(spendingCapViewModelProvider(august)).hasValue, isTrue);
    });

    test('failing WITH a value on screen keeps it there', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      final before = await container.read(
        spendingCapViewModelProvider(august).future,
      );

      repository.failNextCall = NetworkException('offline');
      final message = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .refresh();

      expect(message, 'Sem conexão. Verifique a internet e tente de novo.');
      // The cap stays on screen: a failed reload changes nothing visible.
      expect(container.read(spendingCapViewModelProvider(august)).value, before);
    });

    test('failing WITHOUT a value turns the state into an error', () async {
      final repository = spyWith()..failNextCall = NetworkException('offline');
      final container = containerWith(repository);
      // The build failed, so there is nothing to fall back on.
      await expectLater(
        container.read(spendingCapViewModelProvider(august).future),
        throwsA(isA<NetworkException>()),
      );

      repository.failNextCall = NetworkException('still offline');
      final message = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .refresh();

      expect(message, 'Sem conexão. Verifique a internet e tente de novo.');
      expect(container.read(spendingCapViewModelProvider(august)).hasError, isTrue);
    });

    test('guards against a double tap', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final notifier = container.read(
        spendingCapViewModelProvider(august).notifier,
      );
      final first = notifier.refresh();
      final second = notifier.refresh();

      expect(await second, isNull);
      await first;
      // TWO reads in total — the build's and the first refresh's. Without the
      // guard there would be three.
      expect(repository.reads, 2);
    });

    test('unwraps a ProviderException however deep it is nested', () async {
      // Riverpod wraps one layer PER HOP of the provider chain, so the unwrap
      // is a loop. If it becomes a single `if`, this reads the generic
      // sentence.
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      // `ProviderException` is @internal, and building one by hand is the only
      // way to exercise the loop that unwraps it.
      // ignore: invalid_use_of_internal_member
      repository.failNextCall = ProviderException(
        // ignore: invalid_use_of_internal_member
        ProviderException(NetworkException('offline'), StackTrace.empty),
        StackTrace.empty,
      );

      expect(
        await container.read(spendingCapViewModelProvider(august).notifier).refresh(),
        'Sem conexão. Verifique a internet e tente de novo.',
      );
    });
  });

  group('save', () {
    test('writes the cap of THIS month and reports nothing crossed', () async {
      // R$ 1.100 of R$ 1.500 is under both cuts.
      final repository = spyWith(
        spending: {DateTime(2026, 8, 1): const Money(110000)},
      );
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(150000));

      expect(outcome, isA<CapSaved>());
      expect((outcome! as CapSaved).triggered, isNull);
      expect(repository.saved.single.amount, const Money(150000));
      // Day 1 of the month being read, never a clock of its own.
      expect(repository.saved.single.effectiveFrom, DateTime(2026, 8, 1));
    });

    test('a cap the month is already over warns ON THE SPOT', () async {
      // R$ 1.300 of R$ 1.500 is 87% — the case requirement 9 is written with.
      final repository = spyWith(
        spending: {DateTime(2026, 8, 1): const Money(130000)},
      );
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(150000));

      expect((outcome! as CapSaved).triggered, CapThreshold.approaching);
      // …and that warning COUNTS as the 80% one: the mark goes up with it, so
      // the next purchase of the month does not repeat it.
      expect(repository.alertsWritten.single.warned80, isTrue);
      expect(repository.alertsWritten.single.warned100, isFalse);

      // The state carries what the screen composes the 87% from.
      final status = container.read(spendingCapViewModelProvider(august)).value!;
      expect(status.cap!.usagePercent(status.spent), 87);
    });

    test('a cap born above 100% writes BOTH marks and says the graver', () async {
      final repository = spyWith(
        spending: {DateTime(2026, 8, 1): const Money(180000)},
      );
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(150000));

      // Only the graver sentence speaks (D-h)…
      expect((outcome! as CapSaved).triggered, CapThreshold.exceeded);
      // …and both marks are written, which is what stops the next purchase
      // from firing the 100% on its own.
      expect(repository.alertsWritten.single.warned80, isTrue);
      expect(repository.alertsWritten.single.warned100, isTrue);
    });

    test('raising the cap clears the marks and fires nothing', () async {
      // R$ 1.300 spent, the 80% already given, the cap going to R$ 1.800.
      final repository = spyWith(
        spending: {DateTime(2026, 8, 1): const Money(130000)},
        alerts: {
          DateTime(2026, 8, 1): CapAlerts(
            month: DateTime(2026, 8, 1),
            warned80: true,
          ),
        },
      );
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(180000));

      expect((outcome! as CapSaved).triggered, isNull);
      // The rearm: `false` is not "unknown", it is "this cut is not crossed".
      expect(repository.alertsWritten.single.warned80, isFalse);
    });

    test('refuses a cap of zero with the domain sentence', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(Money.zero);

      expect(
        (outcome! as CapSaveFailed).message,
        'Informe um teto maior que zero.',
      );
      // Nothing was written.
      expect(repository.writes, 0);
    });

    test('translates a technical failure without leaking it', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);
      repository.failNextCall = ApiException(500, 'boom');

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(150000));

      final failed = outcome! as CapSaveFailed;
      // The raw exception NEVER reaches a screen (rule 10).
      expect(failed.message, isNot(contains('boom')));
      expect(failed.message, isNot(contains('500')));
      expect(
        failed.message,
        'O servidor está indisponível. Tente de novo em instantes.',
      );
    });

    test('refuses to guess when the month has not loaded', () async {
      final repository = spyWith()..failNextCall = NetworkException('offline');
      final container = containerWith(repository);
      await expectLater(
        container.read(spendingCapViewModelProvider(august).future),
        throwsA(isA<NetworkException>()),
      );

      final outcome = await container
          .read(spendingCapViewModelProvider(august).notifier)
          .save(const Money(150000));

      // Guessing zero would write both marks as "not crossed" over a month
      // that may well be over the cap.
      expect(
        (outcome! as CapSaveFailed).message,
        'Aguarde o teto do mês carregar.',
      );
      expect(repository.writes, 0);
    });

    test('guards against a double tap', () async {
      final repository = spyWith();
      final container = containerWith(repository);
      await container.read(spendingCapViewModelProvider(august).future);

      final notifier = container.read(
        spendingCapViewModelProvider(august).notifier,
      );
      final first = notifier.save(const Money(150000));
      final second = notifier.save(const Money(180000));

      // Null is the guard saying "não fiz nada" — not a third branch.
      expect(await second, isNull);
      await first;
      expect(repository.writes, 1);
    });
  });
}

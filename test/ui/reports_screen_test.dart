import 'package:flutter/material.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/report/report_repository.dart';
import 'package:shopping_list/data/repositories/report/report_repository_local.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/period_report.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';
import 'package:shopping_list/routing/router.dart';
import 'package:shopping_list/routing/routes.dart';
import 'package:shopping_list/ui/report/view_model/report_period_notifier.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/ui/report/widgets/period_bar.dart';
import 'package:shopping_list/ui/report/widgets/price_comparison_tab.dart';
import 'package:shopping_list/ui/report/widgets/report_summary_tab.dart';
import 'package:shopping_list/ui/report/widgets/reports_screen.dart';

import '../helpers/catalog.dart';
import '../helpers/device_user.dart';
import '../helpers/locale.dart';
import '../helpers/purchase.dart';
import '../helpers/report.dart';
import '../helpers/shopping_list.dart';

/// The fake with a switch that makes the next query fail, and an answer that
/// can be pinned to the reference report.
class _SpyRepository extends ReportRepositoryLocal {
  _SpyRepository({this.fixed}) : super(latency: Duration.zero);

  /// When given, every period answers this — which is how the screen's cases
  /// count the numbers of requirement 4 without depending on the seed's dates.
  final PeriodReport? fixed;

  Object? failNextCall;
  int calls = 0;

  /// The switch of the NEW tab, kept apart from `failNextCall`: a case that
  /// brings the comparison down must not bring the summary down with it, or
  /// it stops proving that the two tabs load on their own.
  Object? failNextQuoteCall;
  int quoteCalls = 0;

  @override
  Future<PeriodReport> fetchPeriodReport(ReportPeriod period) async {
    calls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    if (fixed != null) return fixed!;
    return super.fetchPeriodReport(period);
  }

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    quoteCalls++;
    final failure = failNextQuoteCall;
    failNextQuoteCall = null;
    if (failure != null) throw failure;
    return super.fetchPriceQuotes(since);
  }
}

void main() {
  // The screen draws dates, amounts and month names, and `main()` does not run
  // in a test.
  setUpAll(initializePtBr);

  /// The instant is PINNED in every case: without it `Agosto/2026` is a read
  /// of the calendar of whatever machine runs the CI.
  final today = DateTime(2026, 8, 15);

  Future<ProviderContainer> pumpReports(
    WidgetTester tester, {
    ReportRepository? repository,
    SpendingCapRepository? caps,
  }) async {
    // A tall viewport: the summary, the divider, the total and the button do
    // not fit the default 800×600, and a widget outside the render tree
    // cannot be tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: <Override>[
        deviceUserOverride(),
        catalogOverride(),
        shoppingListOverride(),
        ...purchaseOverrides(caps: caps),
        reportOverride(
          repository: repository ?? _SpyRepository(fixed: referenceReport),
        ),
        reportPeriodProvider.overrideWith(
          () => ReportPeriodNotifier(today: today),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go(Routes.reports);
    await tester.pumpAndSettle();
    return container;
  }

  group('the five states', () {
    testWidgets('the summary answers where the money went, with H12', (
      tester,
    ) async {
      await pumpReports(tester);

      expect(find.text('Carnes'), findsOneWidget);
      expect(find.text(r'R$ 192,00   (58,5%)'), findsOneWidget);
      expect(find.text('Limpeza'), findsOneWidget);
      expect(find.text(r'R$ 136,00   (41,5%)'), findsOneWidget);
      expect(find.text('Total do período'), findsOneWidget);
      expect(find.text(r'R$ 328,00'), findsOneWidget);
    });

    testWidgets('a period with no purchase draws the empty state', (
      tester,
    ) async {
      await pumpReports(tester, repository: _SpyRepository(fixed: PeriodReport.empty));

      expect(
        find.text('Nenhuma compra lançada nesse período.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load occupies the screen, without the exception', (
      tester,
    ) async {
      final repository = _SpyRepository(fixed: referenceReport)
        ..failNextCall = ApiException(500, 'boom');
      await pumpReports(tester, repository: repository);

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
      // The raw exception never reaches the screen.
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('a network failure says the connection is missing', (
      tester,
    ) async {
      final repository = _SpyRepository(fixed: referenceReport)
        ..failNextCall = NetworkException('offline');
      await pumpReports(tester, repository: repository);

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
    });

    testWidgets('[ Tentar de novo ] asks the repository again', (tester) async {
      final repository = _SpyRepository(fixed: referenceReport)
        ..failNextCall = ApiException(500, 'boom');
      await pumpReports(tester, repository: repository);

      await tester.tap(find.byKey(const ValueKey('retry-report')));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('Total do período'), findsOneWidget);
    });
  });

  group('the breakdown', () {
    testWidgets('[ Ver por tipo de produto ] swaps the view', (tester) async {
      await pumpReports(tester);

      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();

      // The written acceptance criterion of requirement 4, both examples.
      expect(find.text('Acém moído'), findsOneWidget);
      expect(
        find.text(r'6 kg   R$ 32,00/kg   R$ 192,00   (100,0%)'),
        findsOneWidget,
      );
      expect(find.text('Sabão em pó'), findsOneWidget);
      expect(
        find.text(r'6,8 kg   R$ 20,00/kg   R$ 136,00   (100,0%)'),
        findsOneWidget,
      );
      // And the way back.
      expect(find.byKey(const ValueKey('show-summary')), findsOneWidget);
    });

    testWidgets('the way back returns to the categories', (tester) async {
      await pumpReports(tester);

      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-summary')));
      await tester.pumpAndSettle();

      expect(find.text('Total do período'), findsOneWidget);
      expect(find.text('Acém moído'), findsNothing);
    });

    testWidgets('a type with two brands opens into both of them', (
      tester,
    ) async {
      await pumpReports(tester);
      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();

      expect(find.text('Omo'), findsNothing);

      await tester.tap(find.text('Sabão em pó'));
      await tester.pumpAndSettle();

      expect(find.text('Omo'), findsOneWidget);
      expect(find.text(r'4,3 kg   R$ 86,00   (63,2%)'), findsOneWidget);
      expect(find.text('Tixan'), findsOneWidget);
      expect(find.text(r'2,5 kg   R$ 50,00   (36,8%)'), findsOneWidget);
    });

    testWidgets('D-a — a type with no brand has no arrow to open', (
      tester,
    ) async {
      // The ground beef: C2 leaves the unbranded group out of the breakdown,
      // so there would not be a single line to show.
      await pumpReports(tester);
      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('type-type-2')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('Acém moído'),
        ),
        findsNothing,
      );
    });

    testWidgets('G-a — the type line carries the share of its CATEGORY', (
      tester,
    ) async {
      // Carnes is 58,5% of the period and the ground beef under it shows
      // 100,0%: the number on the line is the one of the level right above.
      await pumpReports(tester);
      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();

      // `type-2` has no brand breakdown, so its key is a ValueKey on a
      // ListTile — the one with brands is a PageStorageKey on an
      // ExpansionTile, which find.byKey(ValueKey(...)) would not reach.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('type-type-2')),
          matching: find.text(r'6 kg   R$ 32,00/kg   R$ 192,00   (100,0%)'),
        ),
        findsOneWidget,
      );
      expect(find.text(r'R$ 192,00   (58,5%)'), findsNothing);
    });

    testWidgets('G-b — the shown brands may add up to less than 100%', (
      tester,
    ) async {
      // R$ 100,00 of Sadia inside R$ 300,00 of chicken: the rest was bought
      // with no brand, C2 keeps it out of the breakdown, and the line reads
      // 33,3% instead of a made-up 100%.
      final report = PeriodReport(
        categories: [
          const CategorySpending(
            categoryId: 'cat-2',
            name: 'Carnes',
            spent: Money(30000),
          ),
        ].lock,
        types: [
          TypeSpending(
            productTypeId: 'type-5',
            categoryId: 'cat-2',
            name: 'Frango',
            baseUnit: BaseUnit.gram,
            quantityInBaseUnit: 9000,
            spent: const Money(30000),
          ),
        ].lock,
        brands: [
          const BrandSpending(
            productTypeId: 'type-5',
            brandId: 'brand-5',
            name: 'Sadia',
            quantityInBaseUnit: 3000,
            spent: Money(10000),
          ),
          const BrandSpending(
            productTypeId: 'type-5',
            brandId: null,
            name: null,
            quantityInBaseUnit: 6000,
            spent: Money(20000),
          ),
        ].lock,
      );
      await pumpReports(tester, repository: _SpyRepository(fixed: report));

      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frango'));
      await tester.pumpAndSettle();

      expect(find.text('Sadia'), findsOneWidget);
      expect(find.text(r'3 kg   R$ 100,00   (33,3%)'), findsOneWidget);
      // The type itself lost nothing: only the shown brands add up to less.
      expect(
        find.text(r'9 kg   R$ 33,33/kg   R$ 300,00   (100,0%)'),
        findsOneWidget,
      );
    });

    testWidgets('the description of a registration never appears', (
      tester,
    ) async {
      // `wireframes §Tela 5`: a report groups by type and by brand, never by
      // description.
      await pumpReports(tester);
      await tester.tap(find.byKey(const ValueKey('show-detail')));
      await tester.pumpAndSettle();

      expect(find.textContaining('original'), findsNothing);
    });
  });

  group('the period', () {
    testWidgets('a month shortcut reloads the report', (tester) async {
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);
      expect(repository.calls, 1);

      await tester.tap(find.text('Julho'));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('Julho/2026'), findsOneWidget);
    });

    testWidgets('the report on screen is not erased while the next arrives', (
      tester,
    ) async {
      // The `when !state.hasValue` guards: the reload is a pure AsyncLoading
      // and Riverpod 3 keeps the previous value, so a period change must not
      // blank the report being read.
      await pumpReports(tester);

      await tester.tap(find.text('Julho'));
      await tester.pump();

      expect(find.text('Total do período'), findsOneWidget);
      expect(find.text('Somando as compras do período...'), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('the screen itself', () {
    testWidgets('carries the bottom bar, marking its own destination', (
      tester,
    ) async {
      await pumpReports(tester);

      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Falta'), findsOneWidget);
      // Twice: the app bar title AND the bar's own label. The TabBar does NOT
      // add a third — its tabs are 'Resumo' and 'Comparação de preço'.
      expect(find.text('Relatórios'), findsNWidgets(2));
    });

    testWidgets('opens on the Resumo tab, with the comparison beside it', (
      tester,
    ) async {
      await pumpReports(tester);

      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Resumo')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Comparação de preço'),
        ),
        findsOneWidget,
      );
      // The summary is what is on screen, not an empty tab waiting.
      expect(find.byType(ReportSummaryTab), findsOneWidget);
    });

    testWidgets('the period bar belongs to Resumo, not to the screen', (
      tester,
    ) async {
      // The comparison window is rolling and nobody chooses it — showing the
      // two date fields above it would promise a control that does nothing.
      await pumpReports(tester);
      expect(find.byType(PeriodBar), findsOneWidget);

      await tester.tap(find.text('Comparação de preço'));
      await tester.pumpAndSettle();

      expect(find.byType(PeriodBar), findsNothing);
      expect(find.byType(PriceComparisonTab), findsOneWidget);
    });

    testWidgets('the reload button reloads the tab in front', (tester) async {
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);
      expect(repository.calls, 1);

      await tester.tap(find.text('Comparação de preço'));
      await tester.pumpAndSettle();
      expect(repository.quoteCalls, 1);

      await tester.tap(find.byTooltip('Recarregar'));
      await tester.pumpAndSettle();

      // The period report was NOT asked again: the tab in front is the other
      // one.
      expect(repository.calls, 1);
      expect(repository.quoteCalls, 2);
    });

    testWidgets('a failing reload of the comparison keeps the summary', (
      tester,
    ) async {
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);

      await tester.tap(find.text('Comparação de preço'));
      await tester.pumpAndSettle();
      repository.failNextQuoteCall = ApiException(500, 'boom');
      await tester.tap(find.byTooltip('Recarregar'));
      await tester.pumpAndSettle();

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Resumo'));
      await tester.pumpAndSettle();

      expect(find.text('Carnes'), findsOneWidget);
    });

    testWidgets('has no Back button — it IS one of the three destinations', (
      tester,
    ) async {
      // The wireframe's own note: switching between the three permanent
      // destinations is not going back.
      await pumpReports(tester);

      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Menu'), findsOneWidget);
    });

    testWidgets('the three icon targets of the app bar carry labels', (
      tester,
    ) async {
      await pumpReports(tester);

      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.byTooltip('Quem está usando'), findsOneWidget);
      expect(find.byTooltip('Recarregar'), findsOneWidget);
    });

    testWidgets('the `≡` opens the same four doors screen 1 opens', (
      tester,
    ) async {
      await pumpReports(tester);

      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();

      // The door that made this menu worth opening from screen 5: registering
      // a purchase no longer forces a stop at the list (decision I-a).
      expect(find.text('Lançar compra'), findsOneWidget);
      expect(find.text('Histórico de compras'), findsOneWidget);
      expect(find.text('Manutenção do cadastro'), findsOneWidget);
      expect(find.text('Configurações'), findsOneWidget);
    });

    testWidgets('the `👤` asks who is using the phone', (tester) async {
      await pumpReports(tester);

      await tester.tap(find.byTooltip('Quem está usando'));
      await tester.pumpAndSettle();

      expect(find.text('Quem está usando?'), findsOneWidget);
    });

    testWidgets('`↻` asks the repository again', (tester) async {
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);

      await tester.tap(find.byTooltip('Recarregar'));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
    });

    testWidgets('the pull-to-refresh reloads, and says when it fails', (
      tester,
    ) async {
      // The RefreshIndicator, which is a different path from the `↻`: it takes
      // its messenger from the Builder BELOW the Scaffold.
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);

      // 1500 and not 300: RefreshIndicator's trigger is a PERCENTAGE of the
      // viewport (25%), and the viewport this file pumps is 4000 tall.
      await tester.fling(find.byType(ListView), const Offset(0, 1500), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);

      repository.failNextCall = NetworkException('offline');
      await tester.fling(find.byType(ListView), const Offset(0, 1500), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Total do período'), findsOneWidget);
    });

    testWidgets('a failing refresh keeps the report and shows a SnackBar', (
      tester,
    ) async {
      final repository = _SpyRepository(fixed: referenceReport);
      await pumpReports(tester, repository: repository);

      repository.failNextCall = NetworkException('offline');
      await tester.tap(find.byTooltip('Recarregar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      // The report stays on the screen.
      expect(find.text('Total do período'), findsOneWidget);
    });
  });

  group('the spending cap line (H13)', () {
    /// A cap of R$ 1.500 in force since August 2026.
    SpendingCapRepositoryLocal capsInForce() => SpendingCapRepositoryLocal(
      latency: Duration.zero,
      today: today,
      cap: SpendingCap(
        amount: const Money(150000),
        effectiveFrom: DateTime(2026, 8, 1),
      ),
      spending: {DateTime(2026, 8, 1): const Money(32800)},
    );

    testWidgets('the whole month with a cap shows "Gastou X de Y"', (
      tester,
    ) async {
      await pumpReports(tester, caps: capsInForce());

      // The "Gastou R$ X" is the total ALREADY on screen — the R$ 328,00 of
      // the reference report — and not a second sum of the month (D-k).
      expect(find.text(r'Gastou R$ 328,00 de R$ 1.500,00'), findsOneWidget);
    });

    testWidgets('a free interval shows no cap line at all', (tester) async {
      final container = await pumpReports(tester, caps: capsInForce());

      // Ten days of August: comparing a slice with a monthly cap is a number
      // with no meaning.
      container
          .read(reportPeriodProvider.notifier)
          .setFrom(DateTime(2026, 8, 10));
      container.read(reportPeriodProvider.notifier).setTo(DateTime(2026, 8, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cap-line')), findsNothing);
      // …and the report itself is untouched.
      expect(find.text('Total do período'), findsOneWidget);
    });

    testWidgets('a whole month with NO cap shows no line either', (
      tester,
    ) async {
      await pumpReports(
        tester,
        caps: SpendingCapRepositoryLocal(
          latency: Duration.zero,
          today: today,
          // In force only from September: August never had one.
          cap: SpendingCap(
            amount: const Money(150000),
            effectiveFrom: DateTime(2026, 9, 1),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('cap-line')), findsNothing);
      expect(find.text('Total do período'), findsOneWidget);
    });

    testWidgets('a cap that fails to load leaves the report standing', (
      tester,
    ) async {
      // It is watched in PARALLEL with the report, never summed into it.
      await pumpReports(tester, caps: _FailingCaps());

      expect(find.byKey(const ValueKey('cap-line')), findsNothing);
      expect(find.text('Total do período'), findsOneWidget);
      expect(find.text('Carnes'), findsOneWidget);
    });
  });
}

/// A cap repository that always says no — the report has to survive it.
class _FailingCaps extends SpendingCapRepositoryLocal {
  _FailingCaps() : super(latency: Duration.zero);

  @override
  Future<IList<MonthCapStatus>> fetchStatuses(IList<ReportPeriod> months) async =>
      throw NetworkException('offline');
}

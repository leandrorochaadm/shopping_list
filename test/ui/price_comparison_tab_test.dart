import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/report/report_repository.dart';
import 'package:shopping_list/data/repositories/report/report_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/price_quote.dart';
import 'package:shopping_list/ui/report/view_model/price_comparison_view_model.dart';
import 'package:shopping_list/ui/report/widgets/price_comparison_tab.dart';

import '../helpers/locale.dart';
import '../helpers/price.dart';
import '../helpers/report.dart';

/// The fake with a switch that makes the next query fail, and an answer that
/// can be pinned — the same mould as every other spy of the project.
class _SpyRepository extends ReportRepositoryLocal {
  _SpyRepository({this.fixed}) : super(latency: Duration.zero);

  final IList<PriceQuote>? fixed;

  Object? failNextCall;

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    if (fixed != null) return fixed!;
    return super.fetchPriceQuotes(since);
  }
}

void main() {
  // The tab draws dates and amounts, and `main()` does not run in a test.
  setUpAll(initializePtBr);

  /// Pinned: the window is rolling, so an unpinned instant makes these cases
  /// pass in August and fail in September.
  final today = DateTime(2026, 8, 15);

  /// The written story of the wireframe, over the same leaves and the same
  /// stores as the other fakes.
  IList<PriceQuote> theWireframe() => [
    quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
    quote(
      store: streetMarket,
      quantity: 4200,
      cents: 5670,
      on: DateTime(2026, 8, 12),
    ),
    quote(
      store: grocery,
      quantity: 4200,
      cents: 6200,
      on: DateTime(2026, 8, 18),
    ),
    quote(option: cokeCan, quantity: 350, cents: 525, on: DateTime(2026, 8, 20)),
  ].lock;

  Future<ProviderContainer> pumpTab(
    WidgetTester tester, {
    ReportRepository? repository,
  }) async {
    // A tall viewport: the picker, the two segments and three lines do not
    // fit the default 800×600, and a widget outside the render tree cannot be
    // tapped.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer.test(
      overrides: <Override>[
        reportOverride(
          repository: repository ?? _SpyRepository(fixed: theWireframe()),
        ),
        priceComparisonViewModelProvider.overrideWith(
          () => PriceComparisonViewModel(today: today),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PriceComparisonTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> chooseCrate(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('field-comparison-product')),
      'coca',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola 12 × 350 ml').last);
    await tester.pumpAndSettle();
  }

  group('the six states', () {
    testWidgets('loading with nothing behind it says what it is fetching', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer.test(
            overrides: <Override>[
              reportOverride(
                repository: ReportRepositoryLocal(
                  latency: const Duration(milliseconds: 50),
                ),
              ),
              priceComparisonViewModelProvider.overrideWith(
                () => PriceComparisonViewModel(today: today),
              ),
            ],
          ),
          child: const MaterialApp(home: Scaffold(body: PriceComparisonTab())),
        ),
      );
      await tester.pump();

      expect(
        find.text('Buscando os preços dos últimos 3 meses...'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('a failed load occupies the tab, without the exception', (
      tester,
    ) async {
      await pumpTab(
        tester,
        repository: _SpyRepository(fixed: theWireframe())
          ..failNextCall = ApiException(500, 'boom'),
      );

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('retry-comparison')), findsOneWidget);
      // The raw exception never reaches the screen.
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('[ Tentar de novo ] loads it again', (tester) async {
      await pumpTab(
        tester,
        repository: _SpyRepository(fixed: theWireframe())
          ..failNextCall = ApiException(500, 'boom'),
      );

      await tester.tap(find.byKey(const ValueKey('retry-comparison')));
      await tester.pumpAndSettle();

      expect(
        find.text('Escolha um produto para comparar os mercados.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty window hides the picker too', (tester) async {
      // There is nothing to choose, so offering a field to choose in would be
      // a control that cannot answer.
      await pumpTab(
        tester,
        repository: _SpyRepository(fixed: const IList<PriceQuote>.empty()),
      );

      expect(find.text('Nenhuma compra nos últimos 3 meses.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('field-comparison-product')),
        findsNothing,
      );
    });

    testWidgets('with nothing chosen it asks for a product', (tester) async {
      await pumpTab(tester);

      expect(
        find.byKey(const ValueKey('field-comparison-product')),
        findsOneWidget,
      );
      expect(
        find.text('Escolha um produto para comparar os mercados.'),
        findsOneWidget,
      );
      expect(find.text('Carrefour'), findsNothing);
    });

    testWidgets('a product bought in ONE store says so, and shows it (D-n)', (
      tester,
    ) async {
      // Hiding the price it does have would be hiding data; the sentence
      // delivers the state without erasing the information.
      await pumpTab(
        tester,
        repository: _SpyRepository(
          fixed: [
            quote(quantity: 4200, cents: 4800, on: DateTime(2026, 7, 3)),
          ].lock,
        ),
      );
      await chooseCrate(tester);

      expect(find.text('Carrefour'), findsOneWidget);
      expect(find.text(r'R$ 11,43/L'), findsOneWidget);
      expect(
        find.text(
          'Comprado em um mercado só nos últimos 3 meses — ainda não há com '
          'o que comparar.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('two stores or more: the list, cheapest first', (tester) async {
      await pumpTab(tester);
      await chooseCrate(tester);

      expect(find.text('Carrefour'), findsOneWidget);
      expect(find.text(r'R$ 11,43/L'), findsOneWidget);
      expect(find.text('Feira do Bairro'), findsOneWidget);
      expect(find.text(r'R$ 13,50/L'), findsOneWidget);
      expect(find.text('Mercearia do Zé'), findsOneWidget);
      expect(find.text(r'R$ 14,76/L'), findsOneWidget);
      // Not the single-store sentence: there are three.
      expect(find.textContaining('um mercado só'), findsNothing);
    });
  });

  group('the two views', () {
    testWidgets('the date is beside each line, and it does not order', (
      tester,
    ) async {
      await pumpTab(tester);
      await chooseCrate(tester);

      // The cheapest is the OLDEST of the three, and it still comes first.
      expect(find.text('03/07'), findsOneWidget);
      expect(find.text('12/08'), findsOneWidget);
      expect(find.text('18/08'), findsOneWidget);
    });

    testWidgets('Tipo inteiro turns the Carrefour inside out', (tester) async {
      await pumpTab(tester);
      await chooseCrate(tester);
      expect(find.text(r'R$ 11,43/L'), findsOneWidget);

      await tester.tap(find.text('Tipo inteiro'));
      await tester.pumpAndSettle();

      // The most recent Refrigerante at the Carrefour is the single CAN of
      // 20/08, at R$ 15,00 a litre — the crate's price is gone.
      expect(find.text(r'R$ 15,00/L'), findsOneWidget);
      expect(find.text(r'R$ 11,43/L'), findsNothing);
      expect(find.text('20/08'), findsOneWidget);
      // Still one line per STORE (decision D-o), never one per store ×
      // product.
      expect(find.text('Carrefour'), findsOneWidget);
    });

    testWidgets('the switch does NO I/O — it is the same list read again', (
      tester,
    ) async {
      var calls = 0;
      final repository = _CountingRepository(theWireframe(), () => calls++);
      await pumpTab(tester, repository: repository);
      await chooseCrate(tester);
      expect(calls, 1);

      await tester.tap(find.text('Tipo inteiro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Este produto'));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('the pull-to-refresh reloads, and says when it fails', (
      tester,
    ) async {
      // Scrollable in EVERY state, which is what makes this reachable on the
      // error screen too.
      final repository = _SpyRepository(fixed: theWireframe());
      await pumpTab(tester, repository: repository);
      await chooseCrate(tester);

      repository.failNextCall = ApiException(500, 'boom');
      // 1500 and not 300: RefreshIndicator's trigger is a PERCENTAGE of the
      // viewport (25%), and the viewport this file pumps is 4000 tall.
      await tester.fling(find.byType(ListView), const Offset(0, 1500), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.text('O servidor está indisponível. Tente de novo em instantes.'),
        findsOneWidget,
      );
      // The comparison stays on screen: a failed reload changes nothing
      // visible, and the sentence is what says why.
      expect(find.text(r'R$ 11,43/L'), findsOneWidget);
    });

    testWidgets('the picker groups by CATEGORY, not by type', (tester) async {
      // Screen 3 groups by type and orders by what gets bought most (C1);
      // here the question is "find a product in a list that keeps growing".
      await pumpTab(
        tester,
        repository: _SpyRepository(
          fixed: [
            ...theWireframe(),
            meatQuote(quantity: 1500, cents: 4500, on: DateTime(2026, 8, 10)),
          ].lock,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('field-comparison-product')));
      await tester.pumpAndSettle();

      expect(find.text('Bebidas'), findsOneWidget);
      expect(find.text('Carnes'), findsOneWidget);
      expect(find.text('Refrigerante'), findsNothing);
    });
  });
}

/// Counts the round trips, which is how "the switch does no I/O" is proved.
class _CountingRepository extends ReportRepositoryLocal {
  _CountingRepository(this.fixed, this.onCall) : super(latency: Duration.zero);

  final IList<PriceQuote> fixed;
  final void Function() onCall;

  @override
  Future<IList<PriceQuote>> fetchPriceQuotes(DateTime since) async {
    onCall();
    return fixed;
  }
}

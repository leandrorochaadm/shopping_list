import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/report_period.dart';
import 'package:shopping_list/ui/core/app_locale.dart';
import 'package:shopping_list/ui/report/view_model/report_period_notifier.dart';
import 'package:shopping_list/ui/report/widgets/period_bar.dart';

import '../helpers/locale.dart';

void main() {
  // The bar draws two dates and three month names, and `main()` does not run
  // in a test.
  setUpAll(initializePtBr);

  /// The instant is PINNED. Without it `‹ Julho` and `Agosto/2026` are a read
  /// of the calendar of whatever machine runs the CI.
  final today = DateTime(2026, 8, 15);

  Future<ProviderContainer> pumpBar(WidgetTester tester) async {
    final container = ProviderContainer.test(
      overrides: <Override>[
        reportPeriodProvider.overrideWith(
          () => ReportPeriodNotifier(today: today),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // The pt-BR delegates: without them showDatePicker comes out in
          // English inside a pt-BR screen.
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          locale: ptBrLocale,
          home: const Scaffold(body: PeriodBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('opens on the month in progress, with both shortcuts named', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.text('Agosto/2026'), findsOneWidget);
    expect(find.text('Julho'), findsOneWidget);
    expect(find.text('Setembro'), findsOneWidget);
    expect(find.text('01/08/2026'), findsOneWidget);
    expect(find.text('31/08/2026'), findsOneWidget);
  });

  testWidgets('D-d — the forward shortcut is disabled in the current month', (
    tester,
  ) async {
    // There is no report of tomorrow. And it is not cosmetic: with the period
    // on September, the date field would open with initialDate 01/09 against
    // lastDate 15/08 — the assert of showDatePicker.
    await pumpBar(tester);

    final next = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('next-month')),
        matching: find.byType(TextButton),
      ),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('the back shortcut walks a whole month and re-enables `›`', (
    tester,
  ) async {
    final container = await pumpBar(tester);

    await tester.tap(find.text('Julho'));
    await tester.pumpAndSettle();

    expect(find.text('Julho/2026'), findsOneWidget);
    expect(find.text('01/07/2026'), findsOneWidget);
    expect(find.text('31/07/2026'), findsOneWidget);
    expect(
      container.read(reportPeriodProvider),
      ReportPeriod.monthOf(DateTime(2026, 7, 1)),
    );

    final next = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('next-month')),
        matching: find.byType(TextButton),
      ),
    );
    expect(next.onPressed, isNotNull);
  });

  testWidgets('`‹ ‹ ›` walks back to July, and opening a date does not assert', (
    tester,
  ) async {
    // The case that would crash if D-d were removed: after two steps back and
    // one forward the period is July, `from` is behind `today`, and
    // showDatePicker's `!initialDate.isAfter(lastDate)` holds.
    final container = await pumpBar(tester);

    await tester.tap(find.text('Julho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Junho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Julho'));
    await tester.pumpAndSettle();

    expect(
      container.read(reportPeriodProvider),
      ReportPeriod.monthOf(DateTime(2026, 7, 1)),
    );

    await tester.tap(find.byKey(const ValueKey('period-from')));
    await tester.pumpAndSettle();

    // The picker opened instead of asserting.
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('a shortcut starting from a free interval gives a WHOLE month', (
    tester,
  ) async {
    final container = await pumpBar(tester);
    container.read(reportPeriodProvider.notifier)
      ..setFrom(DateTime(2026, 8, 10))
      ..setTo(DateTime(2026, 8, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Julho'));
    await tester.pumpAndSettle();

    expect(find.text('01/07/2026'), findsOneWidget);
    expect(find.text('31/07/2026'), findsOneWidget);
  });

  testWidgets('an inverted interval is refused, and says so', (tester) async {
    final container = await pumpBar(tester);
    final before = container.read(reportPeriodProvider);

    // Reaching the picker's grid for a specific day is a whole calendar
    // interaction; the sentence the widget shows is what this case is about,
    // so the refusal is triggered through the notifier the field calls.
    final message = container
        .read(reportPeriodProvider.notifier)
        .setTo(DateTime(2026, 7, 1));
    await tester.pumpAndSettle();

    expect(message, 'A data inicial não pode ser depois da final.');
    expect(container.read(reportPeriodProvider), before);
  });

  testWidgets('picking a day through the field moves that end only', (
    tester,
  ) async {
    final container = await pumpBar(tester);

    await tester.tap(find.byKey(const ValueKey('period-from')));
    await tester.pumpAndSettle();
    // The picker opens on 01/08; tapping day 5 of the grid moves only `from`.
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(reportPeriodProvider).from, DateTime(2026, 8, 5));
    expect(container.read(reportPeriodProvider).to, DateTime(2026, 8, 31));
  });

  testWidgets('picking a day on the second field moves only that end', (
    tester,
  ) async {
    final container = await pumpBar(tester);

    await tester.tap(find.byKey(const ValueKey('period-to')));
    await tester.pumpAndSettle();
    // The picker opens on 31/08; tapping day 20 of the grid moves only `to`.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(reportPeriodProvider).from, DateTime(2026, 8, 1));
    expect(container.read(reportPeriodProvider).to, DateTime(2026, 8, 20));
  });

  testWidgets('an inverted pick is refused ON THE SCREEN, with a SnackBar', (
    tester,
  ) async {
    // The whole path: the field asks the notifier, the notifier refuses, and
    // the bar SAYS so — the period stays where it was, which is why this is a
    // SnackBar and not a state.
    final container = await pumpBar(tester);
    container.read(reportPeriodProvider.notifier).setFrom(DateTime(2026, 8, 20));
    await tester.pumpAndSettle();
    final before = container.read(reportPeriodProvider);

    await tester.tap(find.byKey(const ValueKey('period-to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('A data inicial não pode ser depois da final.'),
      findsOneWidget,
    );
    expect(container.read(reportPeriodProvider), before);
  });

  testWidgets('every icon-only target carries a label a reader can announce', (
    tester,
  ) async {
    // `handoff §11` asks for a semantic label on every icon target. Four of
    // the seven of screen 5 are here.
    await pumpBar(tester);

    expect(find.byTooltip('Mês anterior: Julho'), findsOneWidget);
    expect(find.byTooltip('Mês seguinte: Setembro'), findsOneWidget);
    expect(find.byTooltip('Data inicial do período'), findsOneWidget);
    expect(find.byTooltip('Data final do período'), findsOneWidget);
  });
}

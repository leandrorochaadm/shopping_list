import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/proportional_cost.dart';
import 'package:shopping_list/ui/purchase/widgets/cost_comparison_panel.dart';

import '../helpers/purchase.dart';
import '../helpers/viewport.dart';

/// The panel is a plain `StatefulWidget`: these tests pump it inside a
/// `MaterialApp` with **no container and no router**, the way
/// `product_field_test.dart` does.
///
/// **No `initializeDateFormatting('pt_BR')` needed**, and it is worth knowing
/// why: the panel formats money only through `formatMoneyPlain`, which is
/// integer arithmetic and concatenation and never goes through `intl`. What
/// demands the `setUpAll` is `formatMoney` and `formatDate` — and if one day
/// the cost column goes back to `formatMoney`, the `setUpAll` comes back too.
void main() {
  const canKey = ValueKey('cost-check-prod-1');
  const tinyKey = ValueKey('cost-check-prod-2');
  const bottleKey = ValueKey('cost-check-prod-3');
  const crateKey = ValueKey('cost-check-prod-4');

  const canLabel = 'Coca-Cola original 350 ml';
  const tinyLabel = 'Coca-Cola original 269 ml';
  const bottleLabel = 'Coca-Cola original 2 L';
  const crateLabel = 'Coca-Cola original 12 × 350 ml';

  /// The three packagings bought inside the rolling window, and the 269 ml
  /// one never bought — which is what `[ Ver todas do tipo ]` reveals.
  IList<ProductOption> seeded() => optionsOfSoftDrinkType(
    can: reference(cents: 400, quantityInBaseUnit: 350),
    bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
    crate: reference(cents: 4200, quantityInBaseUnit: 4200),
  );

  /// Seven leaves of the same type, all bought inside the window — the
  /// "sete opções e a lista rolando" of the written criterion. The sizes grow
  /// so no two labels are the same.
  IList<ProductOption> sevenLeaves() => [
    for (var i = 1; i <= 7; i++)
      optionByPiece(
        id: 'prod-$i',
        brand: cokeBrand,
        description: 'original',
        pieceSize: i * 250,
        purchaseCount: 1,
        priceReference: reference(cents: i * 300, quantityInBaseUnit: i * 250),
      ),
  ].lock;

  /// What came back from the panel, and whether it came back at all.
  ProductOption? picked;
  var closed = false;

  setUp(() {
    picked = null;
    closed = false;
  });

  Future<void> openPanel(
    WidgetTester tester, {
    IList<ProductOption>? options,
    String launchingId = 'prod-4',
    Size viewport = const Size(1200, 2400),
    bool keyboard = false,
  }) async {
    // A tall viewport by default: the sheet is a list plus a fixed footer,
    // and the default 800×600 leaves the button outside the render tree. The
    // tests that need the list to actually scroll pass `iPhone12Size`, which
    // is the only device this app targets.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    // The ratio is 1 here, so points and physical pixels are the same number.
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(
        bottom: iPhone12KeyboardInset,
      );
    }
    addTearDown(tester.view.reset);

    final all = options ?? seeded();
    final launching = all.firstWhere((option) => option.id == launchingId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await CostComparisonPanel.show(
                  context,
                  candidates: costCandidatesOf(
                    options: all,
                    typeId: launching.type.id,
                    launching: launching,
                  ),
                  launching: launching,
                );
                closed = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  String priceIn(WidgetTester tester, String id) => tester
      .widget<TextField>(find.byKey(ValueKey('cost-price-$id')))
      .controller!
      .text;

  bool tickedIn(WidgetTester tester, Key key) =>
      tester.widget<Checkbox>(find.byKey(key)).value!;

  String headlineIn(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('cost-headline'))).data!;

  testWidgets('only the line being registered opens ticked', (tester) async {
    await openPanel(tester);

    expect(tickedIn(tester, crateKey), isTrue);
    expect(tickedIn(tester, bottleKey), isFalse);
    expect(tickedIn(tester, canKey), isFalse);
  });

  testWidgets('each line opens with what ONE package last cost', (
    tester,
  ) async {
    await openPanel(tester);

    expect(priceIn(tester, 'prod-4'), '42,00');
    expect(priceIn(tester, 'prod-3'), '10,00');
    expect(priceIn(tester, 'prod-1'), '4,00');
    // And each line is named by the leaf's own label, never re-assembled.
    expect(find.text(crateLabel), findsOneWidget);
    expect(find.text(bottleLabel), findsOneWidget);
    expect(find.text(canLabel), findsOneWidget);
  });

  testWidgets('it opens with the short cut and offers the rest', (
    tester,
  ) async {
    await openPanel(tester);

    expect(find.text(tinyLabel), findsNothing);
    expect(find.byKey(const ValueKey('cost-show-all')), findsOneWidget);
  });

  testWidgets('[ Ver todas do tipo ] reveals the rest, with no price', (
    tester,
  ) async {
    await openPanel(tester);

    await tester.tap(find.byKey(const ValueKey('cost-show-all')));
    await tester.pumpAndSettle();

    expect(find.text(tinyLabel), findsOneWidget);
    expect(priceIn(tester, 'prod-2'), isEmpty);
    expect(tickedIn(tester, tinyKey), isFalse);
    // Nothing left to reveal.
    expect(find.byKey(const ValueKey('cost-show-all')), findsNothing);
  });

  testWidgets('with fewer than two bought it opens WHOLE and offers nothing', (
    tester,
  ) async {
    await openPanel(
      tester,
      options: optionsOfSoftDrinkType(
        crate: reference(cents: 4200, quantityInBaseUnit: 4200),
      ),
    );

    expect(find.text(tinyLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('cost-show-all')), findsNothing);
  });

  testWidgets('the footer asks for the second price, and [ Usar ] is locked', (
    tester,
  ) async {
    await openPanel(tester);

    expect(headlineIn(tester), 'Preencha o preço de duas opções.');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('cost-use')))
          .onPressed,
      isNull,
    );
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('ticking the second line does the whole computation at once', (
    tester,
  ) async {
    await openPanel(tester);

    await tester.tap(find.byKey(bottleKey));
    await tester.pumpAndSettle();

    // R$ 10,00 for 2 L against R$ 42,00 for 4,2 L.
    expect(find.text('5,00/L'), findsOneWidget);
    expect(find.text('10,00/L'), findsOneWidget);
    expect(find.text('−50%'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(headlineIn(tester), '$bottleLabel — 50% mais barato o litro');
  });

  testWidgets('typing a new price redoes everything, with no button', (
    tester,
  ) async {
    await openPanel(tester);
    await tester.tap(find.byKey(bottleKey));
    await tester.pumpAndSettle();

    // The crate on sale: R$ 8,00 for 4,2 L is R$ 1,90 a litre.
    await tester.enterText(
      find.byKey(const ValueKey('cost-price-prod-4')),
      '8,00',
    );
    await tester.pumpAndSettle();

    expect(find.text('1,90/L'), findsOneWidget);
    expect(headlineIn(tester), '$crateLabel — 62% mais barato o litro');
    // The star moved: it is now on the crate's row.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cost-row-prod-4')),
        matching: find.byIcon(Icons.star),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a ticked line with no price does not unlock the button', (
    tester,
  ) async {
    await openPanel(tester);
    await tester.tap(find.byKey(const ValueKey('cost-show-all')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(tinyKey));
    await tester.pumpAndSettle();

    expect(tickedIn(tester, tinyKey), isTrue);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('cost-use')))
          .onPressed,
      isNull,
    );
    expect(headlineIn(tester), 'Preencha o preço de duas opções.');
  });

  testWidgets('an unticked line shows neither cost nor difference', (
    tester,
  ) async {
    await openPanel(tester);

    // The bottle carries R$ 10,00 in its field and is not ticked.
    expect(priceIn(tester, 'prod-3'), '10,00');
    expect(find.text('5,00/L'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('below 1% nobody is crowned and [ Usar ] survives it', (
    tester,
  ) async {
    // R$ 10,00 for 2 L against R$ 21,10 for 4,2 L: 500 and 502,4 cents a
    // litre, half a per cent apart.
    await openPanel(
      tester,
      options: optionsOfSoftDrinkType(
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
        crate: reference(cents: 2110, quantityInBaseUnit: 4200),
      ),
      launchingId: 'prod-3',
    );
    await tester.tap(find.byKey(crateKey));
    await tester.pumpAndSettle();

    expect(headlineIn(tester), 'Custo praticamente igual.');
    expect(find.byIcon(Icons.star), findsNothing);
    // The button STAYS, pointing at the cheaper one (F-h).
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('cost-use')))
          .onPressed,
      isNotNull,
    );
    expect(find.text('Usar $bottleLabel'), findsOneWidget);
  });

  testWidgets('[ Usar X ] closes handing back X', (tester) async {
    await openPanel(tester);
    await tester.tap(find.byKey(bottleKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cost-use')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(picked?.id, 'prod-3');
  });

  testWidgets('[ X ] closes handing back nothing', (tester) async {
    await openPanel(tester);

    await tester.tap(find.byKey(const ValueKey('cost-close')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('F-j: the leaf being registered opens visible AND ticked', (
    tester,
  ) async {
    // The "big one I never take": two others bought inside the window, and
    // this one never.
    await openPanel(
      tester,
      options: optionsOfSoftDrinkType(
        can: reference(cents: 400, quantityInBaseUnit: 350),
        bottle: reference(cents: 1000, quantityInBaseUnit: 2000),
      ),
      launchingId: 'prod-4',
    );

    expect(find.text(crateLabel), findsOneWidget);
    expect(tickedIn(tester, crateKey), isTrue);
    expect(priceIn(tester, 'prod-4'), isEmpty);
  });

  testWidgets('F-k: the name is NOT on the same height as the fields', (
    tester,
  ) async {
    await openPanel(tester);

    // The row that holds the box holds no product name: the four fields sit
    // in the same place on every line, whatever the name.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byKey(crateKey),
          matching: find.byType(Row),
        ),
        matching: find.text(crateLabel),
      ),
      findsNothing,
    );
    expect(find.text(crateLabel), findsOneWidget);
  });

  testWidgets('the icon-only button and the star carry their labels', (
    tester,
  ) async {
    await openPanel(tester);
    await tester.tap(find.byKey(bottleKey));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('cost-close')))
          .tooltip,
      'Fechar',
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.star)).semanticLabel,
      'Melhor custo',
    );
  });

  testWidgets('with seven options the answer never scrolls out of sight', (
    tester,
  ) async {
    // The written criterion: "com sete opções e a lista rolando, a resposta
    // continua visível no rodapé". It is what the three bands are FOR — a
    // header, a list that scrolls, a fixed footer — and swapping them for a
    // single `ListView` would pass every other test in this file while
    // taking the verdict off the screen exactly when there is most to
    // compare.
    await openPanel(
      tester,
      options: sevenLeaves(),
      launchingId: 'prod-1',
      // An iPhone 12 in portrait, which is the only device this app targets.
      viewport: iPhone12Size,
    );

    final headline = tester.getRect(
      find.byKey(const ValueKey('cost-headline')),
    );
    final button = tester.getRect(find.byKey(const ValueKey('cost-use')));
    final firstRowBefore = tester.getRect(
      find.byKey(const ValueKey('cost-row-prod-1')),
    );

    // Both are on screen before anything is scrolled.
    expect(headline.bottom, lessThanOrEqualTo(844));
    expect(button.bottom, lessThanOrEqualTo(844));

    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    // The list DID move — without this the assertion below would be true of a
    // panel that simply does not scroll, and would prove nothing.
    expect(
      tester.getRect(find.byKey(const ValueKey('cost-row-prod-1'))).top,
      lessThan(firstRowBefore.top),
    );
    // And the footer did not move a pixel with it.
    expect(
      tester.getRect(find.byKey(const ValueKey('cost-headline'))),
      headline,
    );
    expect(tester.getRect(find.byKey(const ValueKey('cost-use'))), button);
  });

  testWidgets('the header names the unit the computation is in', (
    tester,
  ) async {
    await openPanel(tester);

    expect(find.text('Comparar custo'), findsOneWidget);
    expect(
      find.text('refrigerante · ${costHeaderFor(BaseUnit.liter)}'),
      findsOneWidget,
    );
  });

  testWidgets('with the keyboard up no line falls under it', (tester) async {
    // The field of a repeatable row has no "top" to be moved to, and this is
    // what answers for it: the panel lifts itself by `viewInsets`, so the
    // band that scrolls ends where the keyboard begins. Remove that padding
    // and the lines below run under the keyboard.
    await openPanel(
      tester,
      options: sevenLeaves(),
      launchingId: 'prod-1',
      viewport: iPhone12Size,
      keyboard: true,
    );

    final built = [
      for (var i = 1; i <= 7; i++) find.byKey(ValueKey('cost-price-prod-$i')),
    ].where((finder) => finder.evaluate().isNotEmpty).toList();
    // Without this the loop below would be empty and would prove nothing.
    expect(built, isNotEmpty);

    for (final finder in built) {
      expect(
        tester.getRect(finder).bottom,
        lessThanOrEqualTo(iPhone12KeyboardFold),
        reason: 'a price field is under the keyboard',
      );
    }
    // And the footer, which is the answer, is above it too.
    expect(
      tester.getRect(find.byKey(const ValueKey('cost-use'))).bottom,
      lessThanOrEqualTo(iPhone12KeyboardFold),
    );
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/ui/purchase/widgets/product_field.dart';

import '../helpers/purchase.dart';

/// The picker's own test — it moved here with the widget, out of screen 3.
/// Two product searches over the same base would drift apart on the first
/// change, and neither would be covered by the other's test.
void main() {
  final crate = optionByPiece(
    id: 'p1',
    brand: cokeBrand,
    description: 'original',
    pieceCount: 12,
    pieceSize: 350,
    purchaseCount: 9,
  );
  final can = optionByPiece(
    id: 'p2',
    brand: cokeBrand,
    description: 'original',
    pieceSize: 269,
  );
  final beef = optionByWeight(id: 'p3', type: beefType);

  final options = IList([crate, can, beef]);

  Future<void> pumpField(
    WidgetTester tester, {
    IList<ProductOption>? given,
    ProductOption? initial,
    bool enabled = true,
    String? hintText,
    void Function(ProductOption)? onSelected,
    IList<ProductGroup> Function(IList<ProductOption>)? groupBy,
    Key? fieldKey,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductField(
          options: given ?? options,
          initial: initial,
          enabled: enabled,
          hintText: hintText,
          groupBy: groupBy,
          fieldKey: fieldKey,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('searching finds by stretch, case and accent alike', (
    tester,
  ) async {
    await pumpField(tester);

    for (final query in ['coca', 'COCA', 'cocá']) {
      await tester.enterText(
        find.byKey(const ValueKey('field-product')),
        query,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Coca-Cola original 12 × 350 ml'),
        findsOneWidget,
        reason: query,
      );
      // Grouped by type, with the type's name as the header.
      expect(find.text('Refrigerante'), findsWidgets, reason: query);
    }
  });

  testWidgets('and by the packaging, which is how a shelf is searched', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(find.byKey(const ValueKey('field-product')), '269');
    await tester.pumpAndSettle();

    expect(find.text('Coca-Cola original 269 ml'), findsOneWidget);
    expect(find.text('Coca-Cola original 12 × 350 ml'), findsNothing);
  });

  testWidgets('an empty field shows everything, grouped', (tester) async {
    // The header comes from `ProductGroup.header`, which is TEXT since
    // 30/08/2026 (decision D-u) — and by default it is the name of the type.
    await pumpField(tester);

    await tester.tap(find.byKey(const ValueKey('field-product')));
    await tester.pumpAndSettle();

    expect(find.text('Refrigerante'), findsWidgets);
    expect(find.text('Acém moído'), findsWidgets);
  });

  testWidgets('a caller may group the list its own way', (tester) async {
    // The comparison tab of screen 5 groups by CATEGORY; screen 3 groups by
    // type. One field, two questions — and one parameter instead of two
    // widgets that would diverge on the first change.
    await pumpField(
      tester,
      groupBy: (filtered) =>
          [ProductGroup(header: 'Bebidas', options: filtered)].lock,
    );

    await tester.tap(find.byKey(const ValueKey('field-product')));
    await tester.pumpAndSettle();

    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Refrigerante'), findsNothing);
    expect(find.text('Coca-Cola original 12 × 350 ml'), findsOneWidget);
  });

  testWidgets('a caller may key the field, so two of them can coexist', (
    tester,
  ) async {
    // The two tabs of screen 5 live in the same tree of the `TabBarView`, and
    // a `find.byKey('field-product')` would find two.
    await pumpField(tester, fieldKey: const ValueKey('field-comparison'));

    expect(find.byKey(const ValueKey('field-comparison')), findsOneWidget);
    expect(find.byKey(const ValueKey('field-product')), findsNothing);
  });

  testWidgets('choosing one hands it back and writes it in the field', (
    tester,
  ) async {
    ProductOption? chosen;
    await pumpField(tester, onSelected: (option) => chosen = option);

    await tester.enterText(find.byKey(const ValueKey('field-product')), '269');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coca-Cola original 269 ml'));
    await tester.pumpAndSettle();

    expect(chosen, can);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('field-product')))
          .controller!
          .text,
      // The type comes in front: the field shows no group header.
      'Refrigerante Coca-Cola original 269 ml',
    );
  });

  testWidgets('it opens written with what it was given', (tester) async {
    await pumpField(tester, initial: beef);

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('field-product')))
          .controller!
          .text,
      // Loose, with no brand and no description: the type appears ONCE.
      'Acém moído (peso)',
    );
  });

  testWidgets('disabled, it takes nothing', (tester) async {
    await pumpField(tester, enabled: false, hintText: 'Carregando...');

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('field-product')),
    );
    expect(field.enabled, isFalse);
    expect(field.decoration!.hintText, 'Carregando...');
  });

  testWidgets('a search that finds nothing shows no list at all', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(
      find.byKey(const ValueKey('field-product')),
      'iogurte',
    );
    await tester.pumpAndSettle();

    expect(find.text('Refrigerante'), findsNothing);
    expect(find.text('Acém moído'), findsNothing);
  });

  testWidgets('the label is always Produto', (tester) async {
    await pumpField(tester, given: const IList<ProductOption>.empty());

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('field-product')))
          .decoration!
          .labelText,
      'Produto',
    );
  });

  test('the helper leaves the base units apart, which is what groups them', () {
    expect(crate.type.baseUnit, BaseUnit.milliliter);
    expect(beef.type.baseUnit, BaseUnit.gram);
  });
}

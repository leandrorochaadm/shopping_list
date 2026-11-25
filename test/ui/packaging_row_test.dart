import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/barcode.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/ui/catalog/widgets/packaging_row.dart';

import '../helpers/viewport.dart';

const _cola = '7894900011517';

PackagingDraft _draft({
  int id = 1,
  String pieceCount = '1',
  String pieceSize = '500',
  BaseUnit? unit = BaseUnit.gram,
  IList<Barcode> barcodes = const IList.empty(),
  bool loose = false,
}) =>
    PackagingDraft(id: id, pieceCount: pieceCount, pieceSize: pieceSize, unit: unit, barcodes: barcodes, loose: loose);

void main() {
  group('PackagingDraft', () {
    test('loose changes equality', () {
      final a = _draft();
      expect(a, _draft());
      expect(a.hashCode, _draft().hashCode);
      expect(a, isNot(_draft(loose: true)));
    });

    test('equality covers every field', () {
      final a = _draft();
      expect(a, isNot(_draft(id: 2)));
      expect(a, isNot(_draft(pieceCount: '2')));
      expect(a, isNot(_draft(pieceSize: '1000')));
      expect(a, isNot(_draft(unit: BaseUnit.milliliter)));
      expect(a, isNot(_draft(barcodes: [Barcode.typed(_cola)].lock)));
      expect(_draft(barcodes: [Barcode.typed(_cola)].lock), _draft(barcodes: [Barcode.typed(_cola)].lock));
    });

    test('withLoose(true) clears the count and the measure', () {
      final coded = _draft(pieceCount: '3', barcodes: [Barcode.typed(_cola)].lock);
      final loose = coded.withLoose(true);
      expect(loose.loose, isTrue);
      expect(loose.pieceCount, '1');
      expect(loose.pieceSize, '');
      expect(loose.id, coded.id);
      expect(loose.unit, coded.unit);
      expect(loose.barcodes, coded.barcodes);
    });

    test('the loose draft has no packaging and is complete', () {
      final loose = _draft(loose: true);
      expect(loose.packaging, isNull);
      expect(loose.isComplete, isTrue);
    });

    test('isComplete follows the packaging on a packaging card', () {
      expect(_draft(pieceSize: '').isComplete, isFalse);
      expect(_draft().isComplete, isTrue);
    });

    test('copyWith and withUnit keep loose', () {
      final loose = _draft(loose: true);
      expect(loose.copyWith(pieceSize: '9').loose, isTrue);
      expect(loose.withUnit(BaseUnit.milliliter).loose, isTrue);
    });
  });

  group('PackagingRow', () {
    PackagingDraft? last;

    Future<void> pumpRow(
      WidgetTester tester, {
      required PackagingDraft draft,
      BaseUnit baseUnit = BaseUnit.gram,
      bool looseAllowed = false,
      bool packagingAllowed = true,
      Widget? looseExtra,
      bool enabled = true,
    }) async {
      last = null;
      useIPhone12(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PackagingRow(
                draft: draft,
                baseUnit: baseUnit,
                looseAllowed: looseAllowed,
                packagingAllowed: packagingAllowed,
                looseExtra: looseExtra,
                enabled: enabled,
                onChanged: (value) => last = value,
                onRemoved: () {},
              ),
            ),
          ),
        ),
      );
    }

    SegmentedButton<bool> kind(WidgetTester tester) =>
        tester.widget<SegmentedButton<bool>>(find.byKey(const ValueKey('kind-1')));

    bool segmentEnabled(WidgetTester tester, bool value) =>
        kind(tester).segments.firstWhere((s) => s.value == value).enabled;

    testWidgets('the defaults keep the loose option off', (tester) async {
      await pumpRow(tester, draft: _draft());
      expect(kind(tester).selected, {false});
      expect(segmentEnabled(tester, true), isFalse);
      expect(segmentEnabled(tester, false), isTrue);
      expect(find.text('Quanto tem cada?'), findsOneWidget);
      expect(find.text('Código de barras (opcional)'), findsOneWidget);
    });

    testWidgets('keeps the barcode card out of the loose option', (tester) async {
      await pumpRow(tester, draft: _draft(barcodes: [Barcode.typed(_cola)].lock), looseAllowed: true);
      expect(segmentEnabled(tester, true), isFalse);
      expect(find.text('Código de barras (opcional)'), findsOneWidget);
    });

    testWidgets('tapping A granel turns the card loose', (tester) async {
      await pumpRow(tester, draft: _draft(), looseAllowed: true);
      await tester.tap(find.text('A granel'));
      await tester.pump();
      expect(last, _draft().withLoose(true));
    });

    testWidgets('the loose card shows the price unit and the extra', (tester) async {
      await pumpRow(tester, draft: _draft(loose: true), looseAllowed: true, looseExtra: const Text('etiquetas'));
      expect(find.text('Vendido por kg'), findsOneWidget);
      expect(find.text('etiquetas'), findsOneWidget);
      expect(find.text('Quantas peças?'), findsNothing);
      expect(find.text('Quanto tem cada?'), findsNothing);
      expect(find.text('Código de barras (opcional)'), findsNothing);
    });

    testWidgets('the loose card of a unit type reads per un', (tester) async {
      await pumpRow(
        tester,
        draft: _draft(loose: true, unit: BaseUnit.unit),
        baseUnit: BaseUnit.unit,
      );
      expect(find.text('Vendido por un'), findsOneWidget);
      expect(find.text('Quantas unidades?'), findsNothing);
    });

    testWidgets('looseExtra stays out of a packaging card', (tester) async {
      await pumpRow(tester, draft: _draft(), looseAllowed: true, looseExtra: const Text('etiquetas'));
      expect(find.text('etiquetas'), findsNothing);
    });

    testWidgets('keeps the pending scale code on the loose card', (tester) async {
      await pumpRow(tester, draft: _draft(loose: true), looseAllowed: true, packagingAllowed: false);
      expect(segmentEnabled(tester, false), isFalse);
      await tester.tap(find.text('Embalagem'), warnIfMissed: false);
      await tester.pump();
      expect(last, isNull);
    });

    testWidgets('tapping Embalagem turns the card back', (tester) async {
      await pumpRow(tester, draft: _draft(loose: true), looseAllowed: true);
      await tester.tap(find.text('Embalagem'));
      await tester.pump();
      expect(last?.loose, isFalse);
      expect(last?.pieceCount, '1');
    });

    testWidgets('a disabled card locks the choice', (tester) async {
      await pumpRow(tester, draft: _draft(), looseAllowed: true, enabled: false);
      expect(kind(tester).onSelectionChanged, isNull);
    });
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/product_option.dart';
import 'package:shopping_list/domain/models/scan_resolution.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/purchase/widgets/scale_link_dialog.dart';

import '../helpers/purchase.dart';

void main() {
  final stores = [
    Store(id: 'store-1', name: 'Carrefour'),
    Store(id: 'store-2', name: 'Feira do Bairro'),
  ].lock;
  const label = ScaleUnlinked(itemCode: '2822521', weightInGrams: 160);
  final date = optionByWeight(id: 'date-1', type: beefType);
  final ground = optionByWeight(id: 'beef-1');

  const dateKey = ValueKey('scale-link-date-1');

  ScaleLink? picked;

  Future<void> openDialog(
    WidgetTester tester, {
    String? storeId = 'store-1',
    IList<Store>? storeList,
    IList<ProductOption>? candidates,
  }) async {
    picked = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await ScaleLinkDialog.show(
                  context,
                  label: label,
                  candidates: candidates ?? [date, ground].lock,
                  stores: storeList ?? stores,
                  storeId: storeId,
                );
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

  testWidgets('shows the label and its weight', (tester) async {
    await openDialog(tester);

    expect(find.text('Qual produto é este?'), findsOneWidget);
    expect(find.text('Etiqueta 2822521 · 0,160 kg'), findsOneWidget);
  });

  testWidgets('with the store of screen 3 one tap links and closes', (
    tester,
  ) async {
    await openDialog(tester);

    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('scale-link-store')),
    );
    expect(field.onChanged, isNull);
    expect(find.text('Carrefour'), findsOneWidget);

    await tester.tap(find.byKey(dateKey));
    await tester.pumpAndSettle();

    expect(picked, ScaleLink(option: date, storeId: 'store-1'));
    expect(find.text('Qual produto é este?'), findsNothing);
  });

  testWidgets('without a store the products wait for one', (tester) async {
    await openDialog(tester, storeId: null);

    final tile = tester.widget<ListTile>(find.byKey(dateKey));
    expect(tile.enabled, isFalse);
    await tester.tap(find.byKey(dateKey));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Qual produto é este?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scale-link-store')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feira do Bairro').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(dateKey));
    await tester.pumpAndSettle();
    expect(picked, ScaleLink(option: date, storeId: 'store-2'));
  });

  testWidgets('X closes with nothing', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('scale-link-close')));
    await tester.pumpAndSettle();

    expect(picked, isNull);
    expect(find.text('Qual produto é este?'), findsNothing);
  });

  testWidgets('no product sold by weight says so', (tester) async {
    await openDialog(tester, candidates: const IList.empty());

    expect(find.text('Nenhum produto vendido a peso ainda.'), findsOneWidget);
  });

  testWidgets('a double tap closes once', (tester) async {
    await openDialog(tester);

    final tile = tester.widget<ListTile>(find.byKey(dateKey));
    tile.onTap!();
    tile.onTap!();
    await tester.pumpAndSettle();

    expect(picked, ScaleLink(option: date, storeId: 'store-1'));
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('a store missing from the list does not break the field', (
    tester,
  ) async {
    await openDialog(tester, storeList: const IList.empty());

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(dateKey));
    await tester.pumpAndSettle();
    expect(picked, ScaleLink(option: date, storeId: 'store-1'));
  });

  test('ScaleLink equality covers every field', () {
    final base = ScaleLink(option: date, storeId: 'store-1');
    final same = ScaleLink(option: date, storeId: 'store-1');
    expect(base, same);
    expect(base.hashCode, same.hashCode);
    expect(base, isNot(ScaleLink(option: ground, storeId: 'store-1')));
    expect(base, isNot(ScaleLink(option: date, storeId: 'store-2')));
  });
}

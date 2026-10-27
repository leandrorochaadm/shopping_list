import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/purchase/widgets/scale_store_dialog.dart';

void main() {
  final stores = [
    Store(id: 'store-1', name: 'Carrefour'),
    Store(id: 'store-2', name: 'Feira do Bairro'),
  ].lock;

  String? picked;
  var answered = false;

  Future<void> openDialog(
    WidgetTester tester, {
    required List<String> storeIds,
  }) async {
    picked = null;
    answered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await ScaleStoreDialog.show(
                  context,
                  storeIds: storeIds.lock,
                  stores: stores,
                );
                answered = true;
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

  testWidgets('lists the stores in the order given', (tester) async {
    await openDialog(tester, storeIds: ['store-2', 'store-1']);

    expect(
      tester.getTopLeft(find.text('Feira do Bairro')).dy,
      lessThan(tester.getTopLeft(find.text('Carrefour')).dy),
    );
    expect(
      find.text('Esta etiqueta existe em mais de um mercado. Qual?'),
      findsOneWidget,
    );
  });

  testWidgets('a tap answers the store', (tester) async {
    await openDialog(tester, storeIds: ['store-1', 'store-2']);

    await tester.tap(find.byKey(const ValueKey('scale-store-store-2')));
    await tester.pumpAndSettle();

    expect(picked, 'store-2');
  });

  testWidgets('an id with no store loaded is skipped', (tester) async {
    await openDialog(tester, storeIds: ['store-1', 'store-9']);

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('X closes with nothing', (tester) async {
    await openDialog(tester, storeIds: ['store-1', 'store-2']);

    await tester.tap(find.byKey(const ValueKey('scale-store-close')));
    await tester.pumpAndSettle();

    expect(answered, isTrue);
    expect(picked, isNull);
  });
}

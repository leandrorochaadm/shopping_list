import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/store/widgets/new_store_dialog.dart';

import '../helpers/catalog.dart';

/// H3 has no screen of its own — the dialog belongs to screen 3, which is
/// H7's — so this host stands in for it. Until that screen exists, this test
/// and the ViewModel's are what prove the story works.
class _Host extends ConsumerWidget {
  const _Host({required this.onPicked});

  final ValueChanged<Store?> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              onPicked(await NewStoreDialog.show(context, ref)),
          child: const Text('Novo mercado'),
        ),
      ),
    ),
  );
}

void main() {
  Future<Store?> picked = Future.value();

  Future<void> pumpHost(WidgetTester tester) async {
    Store? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeOverride()],
        child: MaterialApp(home: _Host(onPicked: (store) => result = store)),
      ),
    );
    await tester.pumpAndSettle();
    picked = Future.value(result);
  }

  Future<Store?> openAndSubmit(
    WidgetTester tester,
    String name, {
    bool cancel = false,
  }) async {
    Store? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeOverride()],
        child: MaterialApp(home: _Host(onPicked: (store) => result = store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo mercado'));
    await tester.pumpAndSettle();

    if (cancel) {
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      return result;
    }

    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('registers the store where it was missed', (tester) async {
    // Leaving the purchase to go find a catalog screen is what the two-minute
    // budget of requirement 3 cannot pay for.
    final created = await openAndSubmit(tester, 'Assaí');

    expect(find.byType(AlertDialog), findsNothing);
    expect(created?.name, 'Assaí');
    // With its id, so whoever opened it can select it without a round trip.
    expect(created?.id, isNotNull);
  });

  testWidgets('keeps the answer next to the field it is about', (
    tester,
  ) async {
    final created = await openAndSubmit(tester, ' carrefour ');

    // The dialog stays open with the sentence under the field: a SnackBar
    // behind a dialog explains nothing.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Já existe o mercado Carrefour.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('offers to reactivate instead of creating a second one', (
    tester,
  ) async {
    await openAndSubmit(tester, 'MERCEARIA DO ZE');

    expect(
      find.text(
        'O mercado Mercearia do Zé existe, mas está desativado. '
        'Reative-o na manutenção do cadastro.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('refuses a name made of blanks', (tester) async {
    await openAndSubmit(tester, '   ');

    expect(find.text('Informe um nome.'), findsOneWidget);
  });

  testWidgets('gives back nothing when it is dismissed', (tester) async {
    expect(await openAndSubmit(tester, '', cancel: true), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('mounts without opening anything', (tester) async {
    await pumpHost(tester);

    expect(await picked, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

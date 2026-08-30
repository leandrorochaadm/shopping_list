import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/domain/models/catalog_entry.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/ui/core/widgets/single_field_dialog.dart';

/// The shared one-field dialog, tested on its own for the first time — until
/// this delivery it was exercised sideways, by the three dialogs of H2.
///
/// What is new here is the `[ Reativar ]` of the deactivated conflict, and it
/// has four ways to go wrong: appearing too early, appearing when there is
/// nothing to offer, not appearing when there is, and closing with the wrong
/// thing.
void main() {
  Future<String?> pumpDialog(
    WidgetTester tester, {
    required Future<String?> Function(String value) onSubmit,
    String? footnote,
    List<Widget> leadingActions = const [],
    CatalogEntry? Function(String value)? findReactivable,
    Future<String?> Function(CatalogEntry entry)? onReactivate,
    String reactivateLabel = 'Reativar',
  }) async {
    String? popped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await showDialog<String>(
                  context: context,
                  builder: (context) => SingleFieldDialog(
                    title: 'Nova categoria',
                    fieldLabel: 'Nome da categoria',
                    onSubmit: onSubmit,
                    footnote: footnote,
                    leadingActions: leadingActions,
                    findReactivable: findReactivable,
                    onReactivate: onReactivate,
                    reactivateLabel: reactivateLabel,
                  ),
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
    return popped;
  }

  testWidgets('pops the accepted text', (tester) async {
    await pumpDialog(tester, onSubmit: (_) async => null);

    await tester.enterText(find.byType(TextField), 'Padaria');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a refusal stays under the field, and the dialog stays open', (
    tester,
  ) async {
    await pumpDialog(tester, onSubmit: (_) async => 'Já existe a categoria X.');

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Já existe a categoria X.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the footnote shows when given, and not when it is not', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      onSubmit: (_) async => null,
      footnote: 'Cadastro não se apaga.',
    );
    expect(find.text('Cadastro não se apaga.'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await pumpDialog(tester, onSubmit: (_) async => null);
    expect(find.text('Cadastro não se apaga.'), findsNothing);
  });

  testWidgets('extra actions sit beside the two that always exist', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      onSubmit: (_) async => null,
      leadingActions: [
        TextButton(onPressed: () {}, child: const Text('Desativar')),
      ],
    );

    expect(find.text('Desativar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  group('[ Reativar ]', () {
    final deactivated = Category(id: 'c1', name: 'Limpeza', active: false);
    final active = Category(id: 'c2', name: 'Bebidas');

    testWidgets('does not show before the submit is refused', (tester) async {
      await pumpDialog(
        tester,
        onSubmit: (_) async => null,
        findReactivable: (_) => deactivated,
        onReactivate: (_) async => null,
      );

      expect(find.byKey(const ValueKey('reactivate')), findsNothing);
    });

    testWidgets('does not show when the conflict was with an ACTIVE row', (
      tester,
    ) async {
      // There is no way out to offer: a second "Bebidas" is simply refused.
      await pumpDialog(
        tester,
        onSubmit: (_) async => 'Já existe a categoria Bebidas.',
        findReactivable: (_) => active.active ? null : active,
        onReactivate: (_) async => null,
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Já existe a categoria Bebidas.'), findsOneWidget);
      expect(find.byKey(const ValueKey('reactivate')), findsNothing);
    });

    testWidgets('shows when the conflict is a DEACTIVATED row', (tester) async {
      await pumpDialog(
        tester,
        onSubmit: (_) async =>
            'O cadastro Limpeza existe, mas está desativado.',
        findReactivable: (_) => deactivated,
        onReactivate: (_) async => null,
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);
      // The sentence carries no destination: the button is right there.
      expect(find.textContaining('manutenção do cadastro'), findsNothing);
    });

    testWidgets('tapping it closes the dialog handing back the NAME', (
      tester,
    ) async {
      CatalogEntry? reactivated;

      await pumpDialog(
        tester,
        onSubmit: (_) async =>
            'O cadastro Limpeza existe, mas está desativado.',
        findReactivable: (_) => deactivated,
        onReactivate: (entry) async {
          reactivated = entry;
          return null;
        },
      );

      await tester.enterText(find.byType(TextField), 'limpeza');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reactivate')));
      await tester.pumpAndSettle();

      expect(reactivated, deactivated);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a failed reactivation keeps the dialog open and says why', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        onSubmit: (_) async =>
            'O cadastro Limpeza existe, mas está desativado.',
        findReactivable: (_) => deactivated,
        onReactivate: (_) async => 'Não deu para reativar agora.',
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reactivate')));
      await tester.pumpAndSettle();

      expect(find.text('Não deu para reativar agora.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('editing the field takes the offer away', (tester) async {
      // An offer to reactivate "Limpeza" standing over a field that now reads
      // something else would reactivate the wrong row.
      await pumpDialog(
        tester,
        onSubmit: (_) async =>
            'O cadastro Limpeza existe, mas está desativado.',
        findReactivable: (_) => deactivated,
        onReactivate: (_) async => null,
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reactivate')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Limpezas');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reactivate')), findsNothing);
    });

    testWidgets('the label is the caller\'s', (tester) async {
      await pumpDialog(
        tester,
        onSubmit: (_) async => 'desativado',
        findReactivable: (_) => deactivated,
        onReactivate: (_) async => null,
        reactivateLabel: 'Reativar e acrescentar embalagem',
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Reativar e acrescentar embalagem'), findsOneWidget);
    });
  });
}

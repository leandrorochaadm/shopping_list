import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/catalog/widgets/pick_registration_dialog.dart';

void main() {
  const choices = IListConst([
    RegistrationChoice(id: 'reg-1', label: 'Coca-Cola original · Refrigerante'),
    RegistrationChoice(id: 'reg-2', label: 'Acém moído'),
    RegistrationChoice(id: 'reg-3', label: 'Omo pó · Sabão em pó'),
  ]);

  /// What the dialog handed back, read AFTER it closes — the future of `show`
  /// only completes then.
  String? answer;

  setUp(() => answer = null);

  /// The dialog reads no provider, so there is no ProviderScope here.
  Future<void> pumpDialog(
    WidgetTester tester, {
    IList<RegistrationChoice> offered = choices,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await PickRegistrationDialog.show(
                context,
                choices: offered,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  test('two choices of equal fields are equal', () {
    const a = RegistrationChoice(id: 'reg-1', label: 'Coca-Cola');
    const b = RegistrationChoice(id: 'reg-1', label: 'Coca-Cola');

    expect(a, b);
    expect(a.hashCode, b.hashCode);

    // One field at a time, which is what catches the field left out of `==`.
    expect(
      a == const RegistrationChoice(id: 'reg-2', label: 'Coca-Cola'),
      isFalse,
    );
    expect(a == const RegistrationChoice(id: 'reg-1', label: 'Pepsi'), isFalse);
  });

  testWidgets('lists every registration it was given', (tester) async {
    await pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();

    // The order is not asserted here: whoever calls sorts, and the screen's
    // own case covers that.
    expect(find.text('Coca-Cola original · Refrigerante'), findsWidgets);
    expect(find.text('Acém moído'), findsWidgets);
    expect(find.text('Omo pó · Sabão em pó'), findsWidgets);
  });

  testWidgets('the button is off until a registration is chosen', (
    tester,
  ) async {
    await pumpDialog(tester);

    FilledButton buttonOf() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('pick-registration')),
    );
    expect(buttonOf().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acém moído').last);
    await tester.pumpAndSettle();

    expect(buttonOf().onPressed, isNotNull);
  });

  testWidgets('the chosen id is what comes back', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('field-registration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acém moído').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-registration')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, 'reg-2');
  });

  testWidgets('cancelling answers with nothing', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(answer, isNull);
  });

  testWidgets('with no registration it explains instead of offering an empty '
      'list', (tester) async {
    await pumpDialog(tester, offered: const IListConst([]));

    expect(
      find.textContaining('Nenhum produto cadastrado ainda.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('field-registration')), findsNothing);
  });
}

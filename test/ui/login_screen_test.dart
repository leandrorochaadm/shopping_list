import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/auth/widgets/login_screen.dart';

import '../helpers/viewport.dart';

class _SpyAuthRepository extends AuthRepositoryLocal {
  _SpyAuthRepository({super.latency = Duration.zero}) : super(signedIn: false);

  Object? failNextCall;
  int signInCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    final failure = failNextCall;
    if (failure != null) {
      failNextCall = null;
      await Future<void>.delayed(latency);
      throw failure;
    }
    return super.signIn(email: email, password: password);
  }
}

Future<void> _pump(WidgetTester tester, _SpyAuthRepository spy) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWith((ref) => spy)],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
}

Finder get _email => find.byType(TextField).at(0);
Finder get _password => find.byType(TextField).at(1);

void main() {
  testWidgets('keeps both fields and the button above the keyboard', (
    tester,
  ) async {
    useIPhone12WithKeyboard(tester);
    await _pump(tester, _SpyAuthRepository());

    final button = find.widgetWithText(FilledButton, 'Entrar');
    expect(
      tester.getBottomLeft(_email).dy,
      lessThanOrEqualTo(iPhone12KeyboardFold),
    );
    expect(
      tester.getBottomLeft(_password).dy,
      lessThanOrEqualTo(iPhone12KeyboardFold),
    );
    expect(
      tester.getBottomLeft(button).dy,
      lessThanOrEqualTo(iPhone12KeyboardFold),
    );
    expect(
      tester.getTopLeft(_email).dy,
      lessThan(tester.getTopLeft(_password).dy),
    );
    expect(
      tester.getTopLeft(_password).dy,
      lessThan(tester.getTopLeft(button).dy),
    );
  });

  testWidgets('hides the password', (tester) async {
    useIPhone12(tester);
    await _pump(tester, _SpyAuthRepository());

    expect(tester.widget<TextField>(_password).obscureText, isTrue);
  });

  testWidgets('shows the empty-field sentence in a SnackBar', (tester) async {
    useIPhone12(tester);
    final spy = _SpyAuthRepository();
    await _pump(tester, spy);

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Preencha o e-mail e a senha.'), findsOneWidget);
    expect(spy.signInCalls, 0);
  });

  testWidgets('shows the wrong-password sentence in a SnackBar', (
    tester,
  ) async {
    useIPhone12(tester);
    final spy = _SpyAuthRepository()
      ..failNextCall = ApiException(401, 'invalid credentials');
    await _pump(tester, spy);

    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_password, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('disables the form while signing in', (tester) async {
    useIPhone12(tester);
    final spy = _SpyAuthRepository(latency: const Duration(milliseconds: 50));
    await _pump(tester, spy);

    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_password, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Entrando...');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.widget<TextField>(_email).enabled, isFalse);
    expect(tester.widget<TextField>(_password).enabled, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets("submits from the password field's done key", (tester) async {
    useIPhone12(tester);
    final spy = _SpyAuthRepository();
    await _pump(tester, spy);

    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_password, 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(spy.signInCalls, 1);
  });

  testWidgets('shows nothing after a successful sign in', (tester) async {
    useIPhone12(tester);
    final spy = _SpyAuthRepository();
    await _pump(tester, spy);

    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_password, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(spy.isSignedIn, isTrue);
  });
}

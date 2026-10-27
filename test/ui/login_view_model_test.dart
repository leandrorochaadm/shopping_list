import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/ui/auth/view_model/login_view_model.dart';

class _SpyAuthRepository extends AuthRepositoryLocal {
  _SpyAuthRepository({super.latency = Duration.zero}) : super(signedIn: false);

  Object? failNextCall;
  int signInCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    final failure = failNextCall;
    if (failure != null) {
      failNextCall = null;
      await Future<void>.delayed(latency);
      throw failure;
    }
    return super.signIn(email: email, password: password);
  }
}

ProviderContainer _container(_SpyAuthRepository spy) => ProviderContainer.test(
  overrides: [authRepositoryProvider.overrideWith((ref) => spy)],
);

const _filled = 'Preencha o e-mail e a senha.';

void main() {
  late _SpyAuthRepository spy;
  late ProviderContainer container;

  setUp(() {
    spy = _SpyAuthRepository();
    container = _container(spy);
  });

  LoginViewModel vm() => container.read(loginViewModelProvider.notifier);

  test('returns null and signs in with valid credentials', () async {
    final result = await vm().signIn(email: 'a@b.com', password: 'secret');

    expect(result, isNull);
    expect(spy.signInCalls, 1);
    expect(spy.isSignedIn, isTrue);
    expect(container.read(loginViewModelProvider), isFalse);
  });

  test('trims the email but not the password', () async {
    await vm().signIn(email: '  a@b.com  ', password: ' secret ');

    expect(spy.lastEmail, 'a@b.com');
    expect(spy.lastPassword, ' secret ');
  });

  test('asks for both fields when the email is blank', () async {
    expect(await vm().signIn(email: '   ', password: 'x'), _filled);
    expect(spy.signInCalls, 0);
  });

  test('asks for both fields when the password is empty', () async {
    expect(await vm().signIn(email: 'a@b.com', password: ''), _filled);
    expect(spy.signInCalls, 0);
  });

  test('tells a wrong password apart from a server failure', () async {
    spy.failNextCall = ApiException(401, 'invalid credentials');

    expect(
      await vm().signIn(email: 'a@b.com', password: 'x'),
      'E-mail ou senha incorretos.',
    );
  });

  test('reports no connection on a transport failure', () async {
    spy.failNextCall = NetworkException(Exception('offline'));

    expect(
      await vm().signIn(email: 'a@b.com', password: 'x'),
      'Sem conexão. Tente de novo.',
    );
  });

  test('reports the server as unavailable on 503 and 500', () async {
    const sentence =
        'O servidor está indisponível. Tente de novo em instantes.';
    spy.failNextCall = ApiException(503, '');
    expect(await vm().signIn(email: 'a@b.com', password: 'x'), sentence);

    spy.failNextCall = ApiException(500, '');
    expect(await vm().signIn(email: 'a@b.com', password: 'x'), sentence);
  });

  test('never shows the raw detail of an unknown failure', () async {
    spy.failNextCall = Exception('detail-123');

    final message = await vm().signIn(email: 'a@b.com', password: 'x');

    expect(message, 'Não foi possível entrar. Tente de novo.');
    expect(message, isNot(contains('detail-123')));
  });

  test(
    'unwraps the ProviderException of a failing repository provider',
    () async {
      final failing = ProviderContainer.test(
        overrides: [
          authRepositoryProvider.overrideWith(
            (ref) => throw NetworkException(Exception('offline')),
          ),
        ],
      );

      final message = await failing
          .read(loginViewModelProvider.notifier)
          .signIn(email: 'a@b.com', password: 'x');

      expect(message, 'Sem conexão. Tente de novo.');
    },
  );

  test('ignores the second tap while signing in', () async {
    final slow = _SpyAuthRepository(latency: const Duration(milliseconds: 10));
    final slowContainer = _container(slow);
    final model = slowContainer.read(loginViewModelProvider.notifier);

    final first = model.signIn(email: 'a@b.com', password: 'x');
    final second = model.signIn(email: 'a@b.com', password: 'x');

    expect(await second, isNull);
    expect(await first, isNull);
    expect(slow.signInCalls, 1);
  });

  test('is busy only while signing in, even when it fails', () async {
    final slow = _SpyAuthRepository(latency: const Duration(milliseconds: 10));
    final slowContainer = _container(slow);
    final model = slowContainer.read(loginViewModelProvider.notifier);
    slow.failNextCall = ApiException(401, 'invalid credentials');

    final pending = model.signIn(email: 'a@b.com', password: 'x');
    expect(slowContainer.read(loginViewModelProvider), isTrue);

    await pending;
    expect(slowContainer.read(loginViewModelProvider), isFalse);
  });
}

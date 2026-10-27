import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';

void main() {
  test('starts signed in by default', () {
    expect(AuthRepositoryLocal().isSignedIn, isTrue);
  });

  test('starts signed out when asked', () {
    expect(AuthRepositoryLocal(signedIn: false).isSignedIn, isFalse);
  });

  test('signs in and out, emitting each change', () async {
    final repository = AuthRepositoryLocal(
      signedIn: false,
      latency: Duration.zero,
    );
    addTearDown(repository.dispose);

    final emitted = <bool>[];
    repository.changes.listen(emitted.add);

    await repository.signIn(email: 'a@b.test', password: 'x');
    expect(repository.isSignedIn, isTrue);
    await repository.signOut();
    expect(repository.isSignedIn, isFalse);
    await pumpEventQueue();

    expect(emitted, [true, false]);
  });

  test('does not emit when the state does not change', () async {
    final repository = AuthRepositoryLocal(latency: Duration.zero);
    addTearDown(repository.dispose);

    final emitted = <bool>[];
    repository.changes.listen(emitted.add);

    await repository.signIn(email: 'a@b.test', password: 'x');
    await pumpEventQueue();

    expect(emitted, isEmpty);
  });
}

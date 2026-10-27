import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository.dart';
import 'package:shopping_list/data/repositories/purchase_draft/purchase_draft_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/device_user.dart';
import 'package:shopping_list/domain/models/purchase_draft.dart';
import 'package:shopping_list/ui/settings/view_model/sign_out_view_model.dart';

class _SpyAuthRepository extends AuthRepositoryLocal {
  _SpyAuthRepository() : super(signedIn: true, latency: Duration.zero);

  Object? failNextCall;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = failNextCall;
    failNextCall = null;
    if (failure != null) throw failure;
    return super.signOut();
  }
}

void main() {
  final today = DateTime(2026, 10, 25);
  late _SpyAuthRepository spy;
  late PurchaseDraftRepositoryLocal drafts;
  late DeviceUserRepositoryLocal users;
  late PurchaseDraft initialDraft;

  setUp(() {
    spy = _SpyAuthRepository();
    initialDraft = PurchaseDraft.startedOn(today, 'Leandro');
    drafts = PurchaseDraftRepositoryLocal(initial: initialDraft);
    users = DeviceUserRepositoryLocal(
      initial: DeviceUser('Leandro'),
      latency: Duration.zero,
    );
  });

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWith((ref) => spy),
      purchaseDraftRepositoryProvider.overrideWith((ref) => drafts),
      deviceUserRepositoryProvider.overrideWith((ref) => users),
    ],
  );

  test('returns null and signs out once', () async {
    final container = makeContainer();
    final emitted = <bool>[];
    final sub = spy.changes.listen(emitted.add);

    final error = await container
        .read(signOutViewModelProvider.notifier)
        .signOut();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(error, isNull);
    expect(spy.signOutCalls, 1);
    expect(spy.isSignedIn, isFalse);
    expect(emitted, [false]);
  });

  test('keeps the purchase draft and the device user label', () async {
    final container = makeContainer();

    await container.read(signOutViewModelProvider.notifier).signOut();

    expect(drafts.readNow(), initialDraft);
    expect(drafts.writes, 0);
    expect(users.readNow(), DeviceUser('Leandro'));
  });

  test('never shows the raw detail when signing out fails', () async {
    final container = makeContainer();
    spy.failNextCall = Exception('disk-full');

    final error = await container
        .read(signOutViewModelProvider.notifier)
        .signOut();

    expect(error, 'Não foi possível sair. Tente de novo.');
    expect(error, isNot(contains('disk-full')));
  });

  test('unwraps the ProviderException of a failing auth provider', () async {
    final container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => throw NetworkException('offline'),
        ),
      ],
    );

    final error = await container
        .read(signOutViewModelProvider.notifier)
        .signOut();

    expect(error, 'Sem conexão. Verifique a internet e tente de novo.');
  });

  test('ignores the second tap while signing out', () async {
    final container = makeContainer();
    final notifier = container.read(signOutViewModelProvider.notifier);

    final first = notifier.signOut();
    final second = notifier.signOut();

    expect(await second, isNull);
    expect(await first, isNull);
    expect(spy.signOutCalls, 1);
  });

  test('is busy only while signing out, even when it fails', () async {
    final container = makeContainer();
    final notifier = container.read(signOutViewModelProvider.notifier);
    expect(container.read(signOutViewModelProvider), isFalse);

    final running = notifier.signOut();
    expect(container.read(signOutViewModelProvider), isTrue);
    await running;
    expect(container.read(signOutViewModelProvider), isFalse);

    spy.failNextCall = Exception('disk-full');
    final failing = notifier.signOut();
    expect(container.read(signOutViewModelProvider), isTrue);
    await failing;
    expect(container.read(signOutViewModelProvider), isFalse);
  });

  test('builds without reading the auth repository', () {
    final container = ProviderContainer.test(
      overrides: [
        purchaseDraftRepositoryProvider.overrideWith((ref) => drafts),
        deviceUserRepositoryProvider.overrideWith((ref) => users),
      ],
    );

    expect(container.read(signOutViewModelProvider), isFalse);
  });
}

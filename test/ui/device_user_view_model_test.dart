import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository.dart';
import 'package:shopping_list/data/repositories/device_user/device_user_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/device_user.dart';
import 'package:shopping_list/ui/device_user/view_model/device_user_view_model.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends DeviceUserRepositoryLocal {
  _SpyRepository({super.initial}) : super(latency: Duration.zero);

  Object? failNextCall;
  int saveCalls = 0;
  int readCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<DeviceUser?> read() async {
    readCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.read();
  }

  @override
  Future<void> save(DeviceUser user) async {
    saveCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.save(user);
  }
}

void main() {
  ProviderContainer containerWith(DeviceUserRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          deviceUserRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  test('starts with the label already on the device', () async {
    final repository = _SpyRepository(initial: DeviceUser('Leandro'));
    final container = containerWith(repository);

    expect(
      await container.read(deviceUserViewModelProvider.future),
      DeviceUser('Leandro'),
    );
  });

  test('starts with null on a phone that was never asked', () async {
    final container = containerWith(_SpyRepository());

    expect(await container.read(deviceUserViewModelProvider.future), isNull);
  });

  test(
    'shows the failure on the screen when there is nothing to show',
    () async {
      // No previous value: the error has to OCCUPY the screen. Leaving it in
      // loading is a spinner that never resolves.
      final repository = _SpyRepository()..failNextCall = NetworkException('x');
      final container = containerWith(repository);

      await expectLater(
        container.read(deviceUserViewModelProvider.future),
        throwsA(isA<NetworkException>()),
      );
      expect(container.read(deviceUserViewModelProvider), isA<AsyncError>());
    },
  );

  test('saves the label and answers with no message', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);

    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .save('Esposa');

    expect(error, isNull);
    expect(repository.saveCalls, 1);
    expect(
      container.read(deviceUserViewModelProvider).value,
      DeviceUser('Esposa'),
    );
  });

  test('makes the redirect see the label that was just saved', () async {
    // A plain Provider caches: without the invalidate in save(), the router
    // would keep reading the null of the first read and the welcome screen
    // would never go away — a symptom that points at nothing.
    final container = containerWith(_SpyRepository());
    await container.read(deviceUserViewModelProvider.future);

    expect(container.read(storedDeviceUserProvider), isNull);

    await container.read(deviceUserViewModelProvider.notifier).save('Leandro');

    expect(container.read(storedDeviceUserProvider), DeviceUser('Leandro'));
  });

  test('refuses a blank name without touching the repository', () async {
    // A rule of the domain saying no is not a failure: nothing is logged and
    // nothing is written.
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);

    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .save('   ');

    expect(error, const EmptyDeviceUserName().message);
    expect(repository.saveCalls, 0);
  });

  test('keeps what is on the screen when saving fails', () async {
    // An ACTION that fails never takes the screen over: the label that was
    // already there stays, and the sentence goes to a SnackBar.
    final repository = _SpyRepository(initial: DeviceUser('Leandro'));
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);

    repository.failNextCall = ApiException(500, 'boom');
    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .save('Esposa');

    expect(error, 'O servidor está indisponível. Tente de novo em instantes.');
    expect(
      container.read(deviceUserViewModelProvider).value,
      DeviceUser('Leandro'),
    );
  });

  test('never puts the raw exception in the sentence', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);

    repository.failNextCall = ApiException(
      500,
      'duplicate key value violates x',
    );

    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .save('Leandro');

    expect(error, isNot(contains('duplicate key')));
    expect(error, isNot(contains('ApiException')));
  });

  test('reloads on refresh', () async {
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);
    final readsAfterBuild = repository.readCalls;

    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .refresh();

    expect(error, isNull);
    expect(repository.readCalls, readsAfterBuild + 1);
    expect(
      container.read(deviceUserViewModelProvider),
      isA<AsyncData<DeviceUser?>>(),
    );
  });

  test('keeps the previous label when a refresh fails', () async {
    final repository = _SpyRepository(initial: DeviceUser('Leandro'));
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);

    repository.failNextCall = NetworkException('offline');
    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .refresh();

    expect(error, 'Sem conexão. Verifique a internet e tente de novo.');
    expect(
      container.read(deviceUserViewModelProvider).value,
      DeviceUser('Leandro'),
    );
    expect(
      container.read(deviceUserViewModelProvider),
      isA<AsyncData<DeviceUser?>>(),
    );
  });

  test(
    'leaves the error on the screen when the load never succeeded',
    () async {
      // The other half of the same rule — and a null label is NOT this case: a
      // phone that was never asked loaded fine, and its value is null. "Nothing
      // to fall back on" means the load itself failed.
      final repository = _SpyRepository()
        ..failNextCall = ApiException(403, 'no');
      final container = containerWith(repository);

      await expectLater(
        container.read(deviceUserViewModelProvider.future),
        throwsA(isA<ApiException>()),
      );

      repository.failNextCall = ApiException(403, 'no');
      final error = await container
          .read(deviceUserViewModelProvider.notifier)
          .refresh();

      expect(error, 'O servidor recusou o acesso a este dado.');
      expect(container.read(deviceUserViewModelProvider), isA<AsyncError>());
    },
  );

  test('ignores the second tap on Continuar', () async {
    // Without the reentrancy guard a double tap writes twice — and the button
    // stays tappable because the screen is not replaced during the action.
    final repository = _SpyRepository();
    final container = containerWith(repository);
    await container.read(deviceUserViewModelProvider.future);
    final viewModel = container.read(deviceUserViewModelProvider.notifier);

    final first = viewModel.save('Leandro');
    final second = viewModel.save('Esposa');
    await Future.wait([first, second]);

    expect(repository.saveCalls, 1);
    expect(
      container.read(deviceUserViewModelProvider).value,
      DeviceUser('Leandro'),
    );
  });

  test('unwraps the ProviderException Riverpod wraps the failure in', () async {
    // Riverpod 3 wraps whatever a provider rethrows, ONE LAYER PER HOP. If the
    // unwrap in AppFailure ever becomes a single `if` instead of a loop, this
    // sentence turns into the generic one.
    final container = ProviderContainer.test(
      overrides: <Override>[
        deviceUserRepositoryProvider.overrideWith(
          (ref) => throw NetworkException('the socket never answered'),
        ),
      ],
    );

    final error = await container
        .read(deviceUserViewModelProvider.notifier)
        .refresh();

    expect(error, 'Sem conexão. Verifique a internet e tente de novo.');
  });
}

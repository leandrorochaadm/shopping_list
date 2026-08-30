import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/store.dart';
import 'package:shopping_list/ui/store/view_model/store_view_model.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends StoreRepositoryLocal {
  _SpyRepository({super.initial}) : super(latency: Duration.zero);

  Object? failNextCall;
  int createCalls = 0;
  int fetchCalls = 0;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IList<Store>> fetchAll() async {
    fetchCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchAll();
  }

  @override
  Future<Store> create(Store store) async {
    createCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.create(store);
  }
}

void main() {
  ProviderContainer containerWith(StoreRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          storeRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  final seed = [
    Store(id: '1', name: 'Carrefour'),
    Store(id: '2', name: 'Mercearia do Zé', active: false),
  ];

  test('starts with the stores the repository has', () async {
    final container = containerWith(_SpyRepository(initial: seed));

    expect(
      await container.read(storeViewModelProvider.future),
      seed.toIList(),
    );
  });

  test('adds the created store to the list on screen', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    final error = await container
        .read(storeViewModelProvider.notifier)
        .create('Assaí');

    expect(error, isNull);
    expect(repository.createCalls, 1);
    expect(
      container.read(storeViewModelProvider).value!.map((s) => s.name),
      containsAll(<String>['Carrefour', 'Assaí']),
    );
  });

  test('refuses a name made of blanks, before any I/O', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    expect(
      await container.read(storeViewModelProvider.notifier).create('   '),
      'Informe um nome.',
    );
    // The rule answered without touching the repository — that is the point of
    // the guard living in the entity.
    expect(repository.createCalls, 0);
  });

  test('refuses a name already taken, ignoring case and accents', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    expect(
      await container
          .read(storeViewModelProvider.notifier)
          .create('  CARREFOUR '),
      'Já existe o mercado Carrefour.',
    );
    expect(repository.createCalls, 0);
  });

  test('offers to reactivate a deactivated store instead of a second one', () async {
    // Decision B3: the guard sees the deactivated rows too, and a second
    // "Mercearia do Zé" would split its purchase history in two forever.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    expect(
      await container
          .read(storeViewModelProvider.notifier)
          .create('mercearia do ze'),
      // No destination in it since H10: the dialog showing this sentence
      // offers `[ Reativar ]` right there, so sending anyone to another
      // screen would be a detour, not a way out.
      'O cadastro Mercearia do Zé existe, mas está desativado.',
    );
    expect(repository.createCalls, 0);
  });

  test('turns a failed create into a sentence, keeping the list on screen', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    repository.failNextCall = NetworkException('offline');

    expect(
      await container.read(storeViewModelProvider.notifier).create('Assaí'),
      'Sem conexão. Verifique a internet e tente de novo.',
    );
    // An ACTION that failed never takes over the screen.
    expect(container.read(storeViewModelProvider).value, seed.toIList());
  });

  test('classifies the duplicate the database caught as its own sentence', () async {
    // The Dart guard only sees what it loaded; the unique index is the net
    // underneath, and 23505 arrives here as a 409.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    repository.failNextCall = ApiException(409, 'duplicate key');

    expect(
      await container.read(storeViewModelProvider.notifier).create('Assaí'),
      'Já existe um cadastro com esses dados.',
    );
  });

  test('shows the failure on screen when there is nothing to fall back on', () async {
    final repository = _SpyRepository(initial: seed)
      ..failNextCall = NetworkException('offline');
    final container = containerWith(repository);

    await expectLater(
      container.read(storeViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );
    expect(container.read(storeViewModelProvider).hasError, isTrue);

    // And the retry that works puts the list back.
    expect(
      await container.read(storeViewModelProvider.notifier).refresh(),
      isNull,
    );
    expect(container.read(storeViewModelProvider).value, seed.toIList());
  });

  test('keeps the previous list when a refresh fails', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    repository.failNextCall = ApiException(500, 'boom');

    expect(
      await container.read(storeViewModelProvider.notifier).refresh(),
      'O servidor está indisponível. Tente de novo em instantes.',
    );
    expect(container.read(storeViewModelProvider).value, seed.toIList());
    expect(container.read(storeViewModelProvider).hasError, isFalse);
  });

  test('writes once on a double tap', () async {
    // Without the reentrancy guard this registers the store twice: the list
    // stays on screen during the action, so the button stays tappable.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(storeViewModelProvider.future);

    final notifier = container.read(storeViewModelProvider.notifier);
    await Future.wait([notifier.create('Assaí'), notifier.create('Assaí')]);

    expect(repository.createCalls, 1);
  });
}

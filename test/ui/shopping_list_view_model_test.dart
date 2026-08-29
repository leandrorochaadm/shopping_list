import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/data/services/api_exception.dart';
import 'package:shopping_list/domain/models/base_unit.dart';
import 'package:shopping_list/domain/models/category.dart';
import 'package:shopping_list/domain/models/product_type.dart';
import 'package:shopping_list/domain/models/shopping_list_item.dart';
import 'package:shopping_list/ui/shopping_list/view_model/shopping_list_view_model.dart';

/// The `_local` fake with a switch that makes the next call fail — no
/// mocktail, and no second implementation of the repository to keep in sync.
class _SpyRepository extends ShoppingListRepositoryLocal {
  _SpyRepository({super.initial}) : super(latency: Duration.zero);

  Object? failNextCall;
  int fetchCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  int removeCalls = 0;
  DateTime? removedOn;
  ShoppingListItem? lastAdded;

  Object? _take() {
    final failure = failNextCall;
    failNextCall = null;
    return failure;
  }

  @override
  Future<IList<ShoppingListItem>> fetchAll() async {
    fetchCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.fetchAll();
  }

  @override
  Future<ShoppingListItem> add(ShoppingListItem item) async {
    addCalls++;
    lastAdded = item;
    final failure = _take();
    if (failure != null) throw failure;
    return super.add(item);
  }

  @override
  Future<ShoppingListItem> update(ShoppingListItem item) async {
    updateCalls++;
    final failure = _take();
    if (failure != null) throw failure;
    return super.update(item);
  }

  @override
  Future<void> remove(ShoppingListItem item, DateTime day) async {
    removeCalls++;
    removedOn = day;
    final failure = _take();
    if (failure != null) throw failure;
    return super.remove(item, day);
  }
}

final _drinks = Category(id: 'cat-1', name: 'Bebidas');

final _milk = ProductType(
  id: 'type-9',
  name: 'Leite',
  categoryId: 'cat-1',
  baseUnit: BaseUnit.liter,
);

ShoppingListItem _item({
  String id = 'item-1',
  int? quantity = 6000,
  bool picked = false,
}) => ShoppingListItem(
  id: id,
  type: _milk,
  category: _drinks,
  quantity: quantity,
  enteredOn: DateTime(2026, 8, 28),
  picked: picked,
);

void main() {
  ProviderContainer containerWith(ShoppingListRepository repository) =>
      ProviderContainer.test(
        overrides: <Override>[
          shoppingListRepositoryProvider.overrideWith((ref) => repository),
        ],
      );

  final seed = [_item(), _item(id: 'item-2', quantity: null)];

  test('starts with the list the repository has', () async {
    final container = containerWith(_SpyRepository(initial: seed));

    expect(
      await container.read(shoppingListViewModelProvider.future),
      seed.toIList(),
    );
  });

  test('adds an item with the day the phone is on, and nothing else', () async {
    // The clock enters the system in the ViewModel (decision 13, rule 9): a
    // fixed instant here, `DateTime.now()` on the screen.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    final error = await container
        .read(shoppingListViewModelProvider.notifier)
        .add(_milk, _drinks, today: DateTime(2026, 8, 28, 21, 30));

    expect(error, isNull);
    expect(repository.addCalls, 1);
    expect(repository.lastAdded!.enteredOn, DateTime(2026, 8, 28));
    // Born with no quantity and no preferences — the dialog is what changes
    // that afterwards.
    expect(repository.lastAdded!.quantity, isNull);
    expect(repository.lastAdded!.preferredBrand, isNull);
    expect(repository.lastAdded!.preferredProduct, isNull);
    expect(container.read(shoppingListViewModelProvider).value!.length, 3);
  });

  test('the key is born on the phone, not in the database', () async {
    // Without it there is no way to discard the echo of our own INSERT, and a
    // resent `add` after a timeout would be a second item on the list.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    await container
        .read(shoppingListViewModelProvider.notifier)
        .add(_milk, _drinks, today: DateTime(2026, 8, 28));

    expect(repository.lastAdded!.id, isNotNull);
    expect(repository.lastAdded!.id!.length, 36);
  });

  test('the checkbox flips the right line and leaves the others alone', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    final error = await container
        .read(shoppingListViewModelProvider.notifier)
        .togglePicked(seed.first);

    expect(error, isNull);
    final items = container.read(shoppingListViewModelProvider).value!;
    expect(items.firstWhere((i) => i.id == 'item-1').picked, isTrue);
    expect(items.firstWhere((i) => i.id == 'item-2').picked, isFalse);
  });

  test('the checkbox never passes through "não encontrei"', () async {
    final marked = _item().markedNotFound();
    final repository = _SpyRepository(initial: [marked]);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    await container
        .read(shoppingListViewModelProvider.notifier)
        .togglePicked(marked);

    final item = container.read(shoppingListViewModelProvider).value!.single;
    expect(item.picked, isTrue);
    expect(item.notFound, isTrue);
  });

  test('saves the whole dialog in one write', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    final edited = seed.first.copyWith(quantity: 2000).markedNotFound();
    final error = await container
        .read(shoppingListViewModelProvider.notifier)
        .save(edited);

    expect(error, isNull);
    expect(repository.updateCalls, 1);
    expect(
      container.read(shoppingListViewModelProvider).value!.first,
      edited,
    );
  });

  test('removes the line by hand', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    final error = await container
        .read(shoppingListViewModelProvider.notifier)
        .remove(seed.first);

    expect(error, isNull);
    expect(repository.removeCalls, 1);
    expect(
      container.read(shoppingListViewModelProvider).value!.map((i) => i.id),
      ['item-2'],
    );
  });

  test('a failed action keeps the list on screen and answers a sentence', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    repository.failNextCall = NetworkException('offline');

    expect(
      await container
          .read(shoppingListViewModelProvider.notifier)
          .togglePicked(seed.first),
      'Sem conexão. Verifique a internet e tente de novo.',
    );
    expect(container.read(shoppingListViewModelProvider).value, seed.toIList());
    expect(container.read(shoppingListViewModelProvider).hasError, isFalse);
  });

  test('shows the failure on screen when there is nothing to fall back on', () async {
    final repository = _SpyRepository(initial: seed)
      ..failNextCall = NetworkException('offline');
    final container = containerWith(repository);

    await expectLater(
      container.read(shoppingListViewModelProvider.future),
      throwsA(isA<NetworkException>()),
    );
    expect(container.read(shoppingListViewModelProvider).hasError, isTrue);

    // And the retry that works puts the list back.
    expect(
      await container.read(shoppingListViewModelProvider.notifier).refresh(),
      isNull,
    );
    expect(container.read(shoppingListViewModelProvider).value, seed.toIList());
  });

  test('keeps the previous list when a refresh fails', () async {
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    repository.failNextCall = ApiException(500, 'boom');

    expect(
      await container.read(shoppingListViewModelProvider.notifier).refresh(),
      'O servidor está indisponível. Tente de novo em instantes.',
    );
    expect(container.read(shoppingListViewModelProvider).value, seed.toIList());
    expect(container.read(shoppingListViewModelProvider).hasError, isFalse);
  });

  test('writes once on a double tap', () async {
    // Without the reentrancy guard this writes twice — and in an aisle, with a
    // trolley in hand, the double tap on a checkbox is the common case.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    final notifier = container.read(shoppingListViewModelProvider.notifier);
    await Future.wait([
      notifier.togglePicked(seed.first),
      notifier.togglePicked(seed.first),
    ]);

    expect(repository.updateCalls, 1);
  });

  test('unwraps a ProviderException however deep it is nested', () async {
    // Riverpod wraps one layer PER HOP of the provider chain, so the unwrap is
    // a loop. If it becomes a single `if`, this reads the generic sentence.
    final repository = _SpyRepository(initial: seed);
    final container = containerWith(repository);
    await container.read(shoppingListViewModelProvider.future);

    // `ProviderException` is @internal, and building one by hand is the only
    // way to exercise the loop that unwraps it — the real thing is thrown by
    // Riverpod itself, from inside a provider chain no test can assemble.
    // ignore: invalid_use_of_internal_member
    repository.failNextCall = ProviderException(
      // ignore: invalid_use_of_internal_member
      ProviderException(NetworkException('offline'), StackTrace.empty),
      StackTrace.empty,
    );

    expect(
      await container
          .read(shoppingListViewModelProvider.notifier)
          .togglePicked(seed.first),
      'Sem conexão. Verifique a internet e tente de novo.',
    );
  });

  group('classifies each failure as its own sentence', () {
    final sentences = <Object, String>{
      ApiException(401, 'no'): 'O servidor recusou o acesso a este dado.',
      ApiException(404, 'gone'):
          'Este registro não existe mais. Atualize a tela.',
      ApiException(409, 'dup'): 'Já existe um cadastro com esses dados.',
      ApiException(500, 'boom'):
          'O servidor está indisponível. Tente de novo em instantes.',
      NetworkException('offline'):
          'Sem conexão. Verifique a internet e tente de novo.',
    };

    for (final entry in sentences.entries) {
      test('${entry.key.runtimeType} ${entry.key}', () async {
        final repository = _SpyRepository(initial: seed);
        final container = containerWith(repository);
        await container.read(shoppingListViewModelProvider.future);

        repository.failNextCall = entry.key;

        expect(
          await container
              .read(shoppingListViewModelProvider.notifier)
              .togglePicked(seed.first),
          entry.value,
        );
      });
    }
  });
}

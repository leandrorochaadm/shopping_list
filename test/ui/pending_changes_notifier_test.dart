import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';
import 'package:shopping_list/domain/models/pending_changes.dart';
import 'package:shopping_list/ui/shopping_list/view_model/pending_changes_notifier.dart';

void main() {
  late ShoppingListRepositoryLocal repository;

  ProviderContainer container() => ProviderContainer.test(
    overrides: <Override>[
      shoppingListRepositoryProvider.overrideWith((ref) => repository),
    ],
  );

  setUp(
    () => repository = ShoppingListRepositoryLocal(latency: Duration.zero),
  );

  test('starts with no banner at all', () {
    expect(container().read(pendingChangesProvider), PendingChanges.none);
  });

  test('counts what the other phone added', () async {
    final c = container();
    c.read(pendingChangesProvider);

    repository
      ..emitRemoteChange(ListChangeKind.added)
      ..emitRemoteChange(ListChangeKind.added);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(pendingChangesProvider).addedCount, 2);
    expect(c.read(pendingChangesProvider).label, '2 itens novos — atualizar');
  });

  test('a change on top of two additions drops the count', () async {
    final c = container();
    c.read(pendingChangesProvider);

    repository
      ..emitRemoteChange(ListChangeKind.added)
      ..emitRemoteChange(ListChangeKind.added)
      ..emitRemoteChange(ListChangeKind.changed);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(pendingChangesProvider).label, 'A lista mudou — tocar para ver');
  });

  test('the tap on the banner clears it', () async {
    final c = container();
    c.read(pendingChangesProvider);

    repository.emitRemoteChange(ListChangeKind.added);
    await Future<void>.delayed(Duration.zero);
    c.read(pendingChangesProvider.notifier).clear();

    expect(c.read(pendingChangesProvider), PendingChanges.none);
  });

  test('drops the subscription when the screen goes away', () async {
    // What proves the `ref.onDispose`: without it the notifier keeps writing
    // to a state that no longer exists, and the emit below throws.
    final c = container();
    c.read(pendingChangesProvider);
    c.dispose();

    repository.emitRemoteChange(ListChangeKind.added);
    await Future<void>.delayed(Duration.zero);
    // Nothing to assert beyond "it did not throw" — that IS the rule.
  });

  test('survives being rebuilt, because the fake broadcasts', () async {
    // Riverpod recreates notifiers on every rebuild of the provider, and a
    // single-subscription controller would throw on the second build().
    final c = container();
    c.read(pendingChangesProvider);
    c.invalidate(pendingChangesProvider);
    // The read is what rebuilds it — an invalidated provider is lazy.
    c.read(pendingChangesProvider);

    repository.emitRemoteChange(ListChangeKind.changed);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(pendingChangesProvider).hasOtherChanges, isTrue);
  });
}

import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../../../domain/models/store.dart';
import 'store_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class StoreRepositoryLocal implements StoreRepository {
  StoreRepositoryLocal({
    Iterable<Store>? initial,
    this.latency = const Duration(milliseconds: 400),
  }) : _stores = [
         ...initial ??
             [
               Store(id: 'store-1', name: 'Carrefour'),
               Store(id: 'store-2', name: 'Feira do Bairro'),
               // Deactivated on purpose: it is what makes the B3 guard
               // visible while developing against the fakes.
               Store(id: 'store-3', name: 'Mercearia do Zé', active: false),
             ],
       ];

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  final List<Store> _stores;

  var _nextId = 100;

  @override
  Future<IList<Store>> fetchAll() async {
    await Future<void>.delayed(latency);
    return _stores.toIList();
  }

  @override
  Future<Store> create(Store store) async {
    await Future<void>.delayed(latency);
    final created = store.copyWith(id: 'store-${_nextId++}');
    _stores.add(created);
    return created;
  }
}

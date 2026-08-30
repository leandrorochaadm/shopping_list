import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/store.dart';

/// Where a purchase was made. I/O only — what a valid name is, and whether a
/// name is already taken, are rules of [Store] and `findNameConflict`.
abstract class StoreRepository {
  /// Every store, **including the deactivated ones** (decision B3): the
  /// duplicate guard has to see them, otherwise deactivating a store becomes
  /// the shortest path to a second one with the same name.
  Future<IList<Store>> fetchAll();

  /// Creates and returns the row, with the id the database generated.
  Future<Store> create(Store store);

  /// Renaming "Carrefur" to "Carrefour" — and the store comparison then shows
  /// ONE store, with the history of both under it. Deactivating and
  /// reactivating are this same method, with the transition coming from the
  /// entity (rule 7).
  Future<Store> update(Store store);
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => throw UnimplementedError(
    'storeRepositoryProvider was not overridden. See config/dependencies.dart.',
  ),
);

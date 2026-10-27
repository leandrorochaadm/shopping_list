import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../domain/models/store.dart';
import '../../services/pb_schema.dart';
import '../../services/pocketbase_error.dart';
import 'store_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
final class StoreRepositoryRemote implements StoreRepository {
  StoreRepositoryRemote(this._pb);

  final PocketBase _pb;

  @override
  Future<IList<Store>> fetchAll() async {
    try {
      requireSession(_pb);
      // No `active` filter: the duplicate guard of decision B3 needs the
      // deactivated rows, and the screen is what decides to grey them out.
      // No owner filter: the `listRule` already limits the list to the
      // signed-in user.
      final records = await _pb
          .collection(PbCollections.store)
          .getFullList(sort: PbFields.name);
      return records.map(_storeOf).toIList();
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Store> create(Store store) async {
    try {
      requireSession(_pb);
      // The duplicate guard lives in the domain (`findNameConflict`); the
      // server has no unique index on the name, so `toJson` sends it as typed.
      final record = await _pb
          .collection(PbCollections.store)
          .create(
            body: {...store.toJson(), PbFields.user: _pb.authStore.record!.id},
          );
      return _storeOf(record);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Store> update(Store store) async {
    try {
      requireSession(_pb);
      // Neither the id nor the owner go in the body: the id is in the path,
      // and the `updateRule` refuses an owner swap.
      final body = store.toJson()..remove(PbFields.id);
      final record = await _pb
          .collection(PbCollections.store)
          .update(store.id!, body: body);
      return _storeOf(record);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  Store _storeOf(RecordModel record) =>
      Store.fromJson({...record.data, PbFields.id: record.id});
}

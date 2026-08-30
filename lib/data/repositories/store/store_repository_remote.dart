import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/store.dart';
import '../../services/supabase_error.dart';
import 'store_repository.dart';

/// The real thing. The client is PRIVATE: the UI never reaches it.
final class StoreRepositoryRemote implements StoreRepository {
  StoreRepositoryRemote(this._client);

  final SupabaseClient _client;

  static const _table = 'store';

  @override
  Future<IList<Store>> fetchAll() async {
    try {
      // No `.eq('active', true)`: the duplicate guard of decision B3 needs the
      // deactivated rows, and the screen is what decides to grey them out.
      final rows = await _client.from(_table).select().order('name');
      return rows.map(Store.fromJson).toIList();
    } on Object catch (e, st) {
      // Without this the SQLSTATE 23505 of the unique index would be read as
      // "status 23505", fall into the >= 500 arm and tell the user the server
      // is down when the name is simply taken.
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Store> create(Store store) async {
    try {
      final row = await _client
          .from(_table)
          // The generated `name_normalized` column and its unique index are
          // the net underneath: `toJson` sends the name as typed.
          .insert(store.toJson())
          .select()
          .single();
      return Store.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }

  @override
  Future<Store> update(Store store) async {
    try {
      // The id leaves the payload because it is already in the `.eq`, and
      // sending a primary key inside an update is asking to swap it by
      // accident one day.
      final payload = store.toJson()..remove('id');
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', store.id!)
          .select()
          .single();
      return Store.fromJson(row);
    } on Object catch (e, st) {
      rethrowAsKnownFailure(e, st);
    }
  }
}

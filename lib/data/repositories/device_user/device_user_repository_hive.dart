import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../../domain/models/device_user.dart';
import 'device_user_repository.dart';

/// The real implementation, and it is HIVE — not Supabase.
///
/// `handoff §8` is explicit: the label does not go to the database. What
/// reaches Postgres is the `registered_by` text copied onto each purchase, at
/// the moment it is registered.
final class DeviceUserRepositoryHive implements DeviceUserRepository {
  /// The box arrives already opened and stays PRIVATE: opening it is `main`'s
  /// job, because a refusal there has to become a screen and not an exception
  /// thrown from inside the first repository call. Positional because Dart has
  /// no named initializing formal for a private field.
  DeviceUserRepositoryHive(this._box);

  /// The name of the box `main` opens before runApp. Hive on web writes to
  /// IndexedDB, which Safari denies in a private window — that refusal is
  /// caught in `main` and shown by `MisconfiguredApp.storageUnavailable()`.
  static const boxName = 'device_user';

  /// One box, one row. A key instead of `box.getAt(0)` so a second value can
  /// be added later without the positions shifting under it.
  static const _key = 'current';

  final Box<String> _box;

  @override
  Future<DeviceUser?> read() async => readNow();

  @override
  DeviceUser? readNow() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    return DeviceUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(DeviceUser user) =>
      // JSON, and not the bare name, so the day this row grows a second field
      // the old value still reads back instead of throwing a cast error on a
      // phone nobody can open a console on.
      _box.put(_key, jsonEncode(user.toJson()));
}

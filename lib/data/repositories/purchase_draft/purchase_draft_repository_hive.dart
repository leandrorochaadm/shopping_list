import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../../domain/models/purchase_draft.dart';
import 'purchase_draft_repository.dart';

/// The real implementation: one row in one box, as JSON.
///
/// It is the second of the two things Hive holds (`tecnico §4.2`) — the other
/// being the device label — and it copies `DeviceUserRepositoryHive` line for
/// line on purpose: same private box handed over already open, same JSON
/// instead of a bare value.
final class PurchaseDraftRepositoryHive implements PurchaseDraftRepository {
  /// The box arrives already opened and stays PRIVATE: opening it is `main`'s
  /// job, because a refusal there has to become a screen and not an exception
  /// thrown from inside the first repository call. Positional because Dart has
  /// no named initializing formal for a private field.
  PurchaseDraftRepositoryHive(this._box);

  /// The name of the box `main` opens before runApp. Hive on web writes to
  /// IndexedDB, which Safari denies in a private window — that refusal is
  /// caught in `main` and shown by `MisconfiguredApp.storageUnavailable()`.
  static const boxName = 'purchase_draft';

  /// VERSIONED (`tecnico §4.8`): the day the structure changes, the key
  /// becomes `draft_v2` and the old draft is ignored. Nobody writes a
  /// migration for data that lives for hours.
  static const _key = 'draft_v1';

  final Box<String> _box;

  @override
  PurchaseDraft? readNow() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    try {
      return PurchaseDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // A draft written by an older shape of the app, or a half-written row
      // from a browser that closed mid-save. Losing a draft is bad; refusing
      // to open screen 3 forever because of one is worse — and there is no
      // console to read on an installed PWA.
      return null;
    }
  }

  @override
  Future<void> save(PurchaseDraft draft) =>
      _box.put(_key, jsonEncode(draft.toJson()));

  @override
  Future<void> clear() => _box.delete(_key);
}

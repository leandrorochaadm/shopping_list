import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:pocketbase/pocketbase.dart';

/// The third Hive box, next to the draft and the device user label.
const authBoxName = 'auth';

const _sessionKey = 'session';

/// Builds the store PocketBase keeps the session in (token + user).
///
/// The box arrives already open: opening it is `main`'s job. The token sits in
/// IndexedDB without encryption, like the purchase draft (`tecnico §9.5`) — an
/// accepted decision for a personal PWA.
AsyncAuthStore buildAuthStore(Box<String> box) => AsyncAuthStore(
  save: (data) async => box.put(_sessionKey, data),
  clear: () async => box.delete(_sessionKey),
  initial: _readSession(box),
);

String? _readSession(Box<String> box) {
  final stored = box.get(_sessionKey);
  if (stored == null) return null;
  try {
    if (jsonDecode(stored) is Map) return stored;
  } on FormatException {
    // Falls through to the drop below.
  }
  // Unreadable value: drop it, or the app would fail at every opening on a
  // phone where nobody can open a console.
  box.delete(_sessionKey);
  return null;
}

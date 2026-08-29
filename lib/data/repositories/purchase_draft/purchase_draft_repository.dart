import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/purchase_draft.dart';

/// Where the purchase being typed lives while it is not a purchase yet.
///
/// It is HIVE and not Supabase, for the same reason the device label is: a
/// draft that needed the network to survive would be worthless in exactly the
/// situation H8 exists for.
abstract class PurchaseDraftRepository {
  /// **Synchronous.** The box is opened by `main` before runApp, and screen 3
  /// has to know whether there is a draft BEFORE any network answer — that is
  /// the airplane-mode criterion, and a Future would put a frame of "no
  /// draft" in front of eighteen recovered items.
  PurchaseDraft? readNow();

  Future<void> save(PurchaseDraft draft);

  Future<void> clear();
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Hive everywhere else.
final purchaseDraftRepositoryProvider = Provider<PurchaseDraftRepository>(
  (ref) => throw UnimplementedError(
    'purchaseDraftRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);

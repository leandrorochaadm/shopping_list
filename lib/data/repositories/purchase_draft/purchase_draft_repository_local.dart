import '../../../domain/models/purchase_draft.dart';
import 'purchase_draft_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// write, which is how the "o navegador recusou o armazenamento" path gets
/// exercised without mocktail.
class PurchaseDraftRepositoryLocal implements PurchaseDraftRepository {
  PurchaseDraftRepositoryLocal({PurchaseDraft? initial})
    : _stored = initial?.toJson();

  /// Stored as JSON, exactly like Hive does it — not as the object. Keeping
  /// the instance would make the fake forgiving about what actually survives
  /// a round trip, and the whole point of the draft is what survives.
  Map<String, dynamic>? _stored;

  /// How many times the box was WRITTEN to — saves and clears alike, since
  /// both leave the draft different from what it was.
  ///
  /// It is the same precedent as `PurchaseRepositoryLocal.saved`: the fake
  /// carries what a test needs to look at. What it buys is the proof that
  /// the `#3a` panel of H19 writes nowhere — a claim no assertion could make
  /// otherwise, because the panel is handed no repository at all.
  int writes = 0;

  @override
  PurchaseDraft? readNow() =>
      _stored == null ? null : PurchaseDraft.fromJson(_stored!);

  @override
  Future<void> save(PurchaseDraft draft) async {
    writes++;
    _stored = draft.toJson();
  }

  @override
  Future<void> clear() async {
    writes++;
    _stored = null;
  }
}

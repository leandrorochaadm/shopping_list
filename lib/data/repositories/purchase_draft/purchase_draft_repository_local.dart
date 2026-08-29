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

  @override
  PurchaseDraft? readNow() =>
      _stored == null ? null : PurchaseDraft.fromJson(_stored!);

  @override
  Future<void> save(PurchaseDraft draft) async => _stored = draft.toJson();

  @override
  Future<void> clear() async => _stored = null;
}

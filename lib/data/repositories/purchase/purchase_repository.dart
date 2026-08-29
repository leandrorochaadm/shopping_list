import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase.dart';

/// A purchase and what it takes off the list — the package of ONE
/// transaction. It is not a DTO: both halves are entities, and they travel
/// together because the write that stores them is single.
final class PurchaseSubmission {
  const PurchaseSubmission({required this.purchase, required this.writeOffs});

  final Purchase purchase;
  final IList<ListWriteOff> writeOffs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseSubmission &&
          other.purchase == purchase &&
          other.writeOffs == writeOffs;

  @override
  int get hashCode => Object.hash(purchase, writeOffs);
}

/// One line of a past purchase, reduced to the four numbers screen 3 needs:
/// which leaf, how much of it, what it cost, and when.
///
/// Both the ordering of the picker (how many times each leaf was bought) and
/// the pre-filled value (what the last purchase paid) are computed from this,
/// in Dart — one round trip instead of one per product chosen (P4).
final class PurchaseHistoryEntry {
  const PurchaseHistoryEntry({
    required this.productId,
    required this.quantityInBaseUnit,
    required this.paid,
    required this.purchasedOn,
  });

  final String productId;
  final int quantityInBaseUnit;
  final Money paid;
  final DateTime purchasedOn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseHistoryEntry &&
          other.productId == productId &&
          other.quantityInBaseUnit == quantityInBaseUnit &&
          other.paid == paid &&
          other.purchasedOn == purchasedOn;

  @override
  int get hashCode =>
      Object.hash(productId, quantityInBaseUnit, paid, purchasedOn);
}

/// Registering a purchase, and the two reads screen 3 opens with. I/O only:
/// the write-off is decided by `planWriteOffs`, in the domain, before a
/// method here is called.
abstract class PurchaseRepository {
  /// The ACTIVE leaves, each with its registration, type and brand — what the
  /// Produto picker shows.
  Future<IList<ProductOption>> fetchProductOptions();

  /// Every purchase line since [since]. [since] is computed in the ViewModel,
  /// from the phone's clock: no `now()` and no `current_date` in SQL
  /// (decision 7).
  Future<IList<PurchaseHistoryEntry>> fetchRecentItems(DateTime since);

  /// The single transactional write.
  ///
  /// Returns **true when the purchase was already there** — H8's resend that
  /// arrived twice. It is not an error and it must not become a duplicate:
  /// the caller treats it as the same success, and the draft dies either way.
  Future<bool> save(PurchaseSubmission submission);
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => throw UnimplementedError(
    'purchaseRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);

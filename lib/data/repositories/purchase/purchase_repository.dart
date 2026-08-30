import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/list_write_off.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/product_option.dart';
import '../../../domain/models/purchase.dart';
import '../../../domain/models/purchase_item.dart';
import '../../../domain/models/purchase_summary.dart';
import '../../../domain/models/same_day_alert.dart';
import '../../../domain/models/spending_cap.dart';
import '../../../domain/models/write_off_undo.dart';

/// A purchase and what it takes off the list — the package of ONE
/// transaction. It is not a DTO: both halves are entities, and they travel
/// together because the write that stores them is single.
final class PurchaseSubmission {
  const PurchaseSubmission({
    required this.purchase,
    required this.writeOffs,
    // Nothing to write: it is what a month with no cap sends. The default is
    // a convenience of CALLING and not of equality — the field is compared
    // like any other below (rule 8).
    this.capAlerts = const IList.empty(),
  });

  final Purchase purchase;
  final IList<ListWriteOff> writeOffs;

  /// The desired state of the month's two marks, as `evaluateSpendingCap`
  /// decided it (H13). It travels with the purchase because the mark and the
  /// write that moved the month across a cut have to commit TOGETHER.
  final IList<CapAlerts> capAlerts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseSubmission &&
          other.purchase == purchase &&
          other.writeOffs == writeOffs &&
          other.capAlerts == capAlerts;

  @override
  int get hashCode => Object.hash(purchase, writeOffs, capAlerts);
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

/// A page of the history, and what the screen needs in order to know whether
/// to ask for the next one.
final class PurchaseHistoryPage {
  const PurchaseHistoryPage({required this.purchases, required this.hasMore});

  final IList<PurchaseSummary> purchases;
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseHistoryPage &&
          other.purchases == purchases &&
          other.hasMore == hasMore;

  @override
  int get hashCode => Object.hash(purchases, hasMore);
}

/// The purchase opened for correction, with everything the screen shows and
/// everything the undo needs: the items and the TRAIL it left on the list.
///
/// `items` is `IList<PurchaseItem>` and nothing more: the purchase item
/// already carries the whole `ProductOption`, so leaf, registration, type and
/// brand arrive with it. There is no view to build around it.
final class PurchaseDetail {
  const PurchaseDetail({
    required this.purchase,
    required this.items,
    required this.trail,
  });

  final Purchase purchase;
  final IList<PurchaseItem> items;
  final IList<ListWriteOff> trail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseDetail &&
          other.purchase == purchase &&
          other.items == items &&
          other.trail == trail;

  @override
  int get hashCode => Object.hash(purchase, items, trail);
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

  /// The app's only paginated screen (`tecnico §1.9`), newest first. [limit]
  /// is how many fit on a page; the repository asks for ONE more and drops
  /// it, which is how `hasMore` is answered without a second query.
  Future<PurchaseHistoryPage> fetchPage({
    required int offset,
    required int limit,
  });

  /// One purchase with its items and the trail those items left.
  Future<PurchaseDetail> fetchDetail(String purchaseId);

  /// The correction (H9), through `update_purchase`. It is NOT [save]: that
  /// one is insert-only, and turning it into an upsert would kill the
  /// idempotence of H8's resend (D3).
  ///
  /// [restored] is what `undoWriteOffs` computed and [writeOffs] what
  /// `planWriteOffs` computed over the restored list — this method decides
  /// nothing, it only writes.
  Future<void> correct({
    required Purchase purchase,
    required IList<ListWriteOff> writeOffs,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  });

  /// Deletes the purchase and gives the list back what it had taken.
  Future<void> delete({
    required String purchaseId,
    required IList<RestoredListItem> restored,
    IList<CapAlerts> capAlerts = const IList.empty(),
  });

  /// The types of this purchase that SOMEONE ELSE also bought on [date]
  /// (H14). [registeredBy] is the label of whoever is registering, and the
  /// filter is `<>`: a purchase of one's own never warns.
  ///
  /// [date] is decided in the ViewModel, off the phone's clock — never
  /// `current_date`, which at 21:00 UTC−4 on the 30th answers the 31st.
  Future<IList<SameDayAlert>> fetchSameDayTypes({
    required DateTime date,
    required String registeredBy,
    required ISet<String> productTypeIds,
  });
}

/// Overridden in `config/dependencies.dart` — the fake in debug without
/// --dart-define, Supabase everywhere else.
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => throw UnimplementedError(
    'purchaseRepositoryProvider was not overridden. See '
    'config/dependencies.dart.',
  ),
);

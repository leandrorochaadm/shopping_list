import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'calendar_day.dart';
import 'money.dart';
import 'purchase_item.dart';
import 'uuid.dart';

/// The purchase being typed — H8's whole story.
///
/// It lives in Hive, and it is what makes "fechar o app no corredor e voltar
/// uma hora depois" not lose eighteen items. Everything in it survives a
/// closed app, a dropped connection and a phone that ran out of battery.
final class PurchaseDraft {
  const PurchaseDraft({
    required this.purchaseId,
    required this.date,
    required this.registeredBy,
    this.storeId,
    this.items = const IList.empty(),
    this.pendingSubmission = false,
    this.bannerDismissed = false,
  });

  /// A brand new draft: a fresh key, today, and this phone's label.
  factory PurchaseDraft.startedOn(DateTime today, String registeredBy) =>
      PurchaseDraft(
        purchaseId: newUuidV4(),
        date: dayOf(today),
        registeredBy: registeredBy,
      );

  /// Read back from Hive.
  factory PurchaseDraft.fromJson(Map<String, dynamic> json) => PurchaseDraft(
    purchaseId: json['purchase_id'] as String,
    date: decodeCalendarDay(json['purchase_date'] as String),
    registeredBy: json['registered_by'] as String? ?? '',
    storeId: json['store_id'] as String?,
    items: [
      for (final item in (json['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>())
        PurchaseItem.fromJson(item),
    ].toIList(),
    pendingSubmission: json['pending_submission'] as bool? ?? false,
    bannerDismissed: json['banner_dismissed'] as bool? ?? false,
  );

  /// The purchase's key, born with the draft and NOT at save time (P9). A
  /// resend that arrives twice has to find the same id, or it becomes a
  /// second purchase and writes the list off again.
  final String purchaseId;

  final DateTime date;

  /// This phone's label, **copied when the purchase began**. It does not get
  /// read at save time on purpose: the label can be changed in Configurações
  /// between typing and saving, and `handoff §8` says what the purchase keeps
  /// is the label of the MOMENT of the purchase. Copied here, it also
  /// survives H8's resend.
  final String registeredBy;

  final String? storeId;

  final IList<PurchaseItem> items;

  /// Saved with no signal: the draft is waiting for the connection to come
  /// back, or for the next opening of the app.
  final bool pendingSubmission;

  /// Whether `[ Continuar ]` was already tapped on the recovery banner.
  ///
  /// **Persisted**, and that is the point: the ViewModel is recreated
  /// whenever the device label changes, and a flag living inside it would
  /// bring the banner back with it.
  ///
  /// Whether the banner shows at all is NOT here — it is
  /// `startedWithDraftProvider`, because "came from a previous run of the
  /// app" is a question about the session and not about the purchase. An
  /// entity flag cannot answer it: the same stored draft has to read as "born
  /// now" to the session that wrote it and "recovered" to the next one.
  final bool bannerDismissed;

  Map<String, dynamic> toJson() => {
    'purchase_id': purchaseId,
    'purchase_date': encodeCalendarDay(date),
    'registered_by': registeredBy,
    'store_id': storeId,
    // The DRAFT shape, which carries the whole leaf of each line: a recovered
    // draft has to draw and re-edit itself with no network at all.
    'items': [for (final item in items) item.toDraftJson()],
    'pending_submission': pendingSubmission,
    'banner_dismissed': bannerDismissed,
  };

  bool get isEmpty => storeId == null && items.isEmpty;

  bool get isNotEmpty => !isEmpty;

  Money get total => items.fold(Money.zero, (sum, item) => sum + item.paid);

  /// Adds the line, or REPLACES the one with the same id — which is what the
  /// `[ed]` of an item already in the purchase does.
  PurchaseDraft withItem(PurchaseItem item) {
    final index = items.indexWhere((entry) => entry.id == item.id);
    return copyWith(
      items: index < 0 ? items.add(item) : items.replace(index, item),
    );
  }

  PurchaseDraft withoutItem(String itemId) =>
      copyWith(items: items.removeWhere((entry) => entry.id == itemId));

  PurchaseDraft markedPending() => copyWith(pendingSubmission: true);

  /// The `[ Continuar ]` of the banner: it goes away because someone
  /// dismissed it, never because a provider was rebuilt.
  PurchaseDraft dismissedBanner() => copyWith(bannerDismissed: true);

  PurchaseDraft copyWith({
    DateTime? date,
    String? registeredBy,
    String? storeId,
    IList<PurchaseItem>? items,
    bool? pendingSubmission,
    bool? bannerDismissed,
  }) => PurchaseDraft(
    // The key NEVER changes: it is the purchase this draft will become.
    purchaseId: purchaseId,
    date: date ?? this.date,
    registeredBy: registeredBy ?? this.registeredBy,
    storeId: storeId ?? this.storeId,
    items: items ?? this.items,
    pendingSubmission: pendingSubmission ?? this.pendingSubmission,
    bannerDismissed: bannerDismissed ?? this.bannerDismissed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseDraft &&
          other.purchaseId == purchaseId &&
          other.date == date &&
          other.registeredBy == registeredBy &&
          other.storeId == storeId &&
          other.items == items &&
          other.pendingSubmission == pendingSubmission &&
          other.bannerDismissed == bannerDismissed);

  @override
  int get hashCode => Object.hash(
    purchaseId,
    date,
    registeredBy,
    storeId,
    items,
    pendingSubmission,
    bannerDismissed,
  );

  @override
  String toString() =>
      'PurchaseDraft(${encodeCalendarDay(date)}, ${items.length} itens, '
      'pending: $pendingSubmission, dismissed: $bannerDismissed)';
}

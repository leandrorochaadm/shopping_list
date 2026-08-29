import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/online_status.dart';
import 'new_purchase_view_model.dart';
import 'purchase_draft_view_model.dart';

/// Where a purchase kept offline stands.
enum PendingSubmission {
  /// Nothing waiting, or an attempt that did not go through — the purchase is
  /// still on the phone and will be tried again.
  idle,

  sending,

  /// It went up. This is the only transition the app announces.
  sent,
}

/// The automatic resend of H8.
///
/// **It lives outside screen 3 on purpose** (P8): the acceptance criterion
/// says "na abertura seguinte", and on the next opening the screen showing is
/// `/`, not this one.
///
/// **It never runs with the app closed.** WebKit has no Background Sync
/// (`R16`), and the wording of the offline banner promises no more than that.
final class PendingPurchaseSubmitter extends Notifier<PendingSubmission> {
  bool _running = false;

  @override
  PendingSubmission build() {
    // The connection coming back, with the app OPEN.
    ref.listen(onlineStatusProvider, (_, online) {
      if (online) unawaited(_try());
    });

    // The attempt of the OPENING, scheduled for after the provider is built
    // rather than during it — a network call from inside a build is how a
    // provider ends up modifying itself while it is being created.
    Future.microtask(_try);

    return PendingSubmission.idle;
  }

  Future<void> _try() async {
    if (_running) return;

    // **The order matters.** The "nothing pending" exit comes BEFORE any read
    // of the purchase ViewModel: reading it fires the two catalog queries,
    // and every single opening of the app would pay for them with nothing to
    // send.
    final draft = ref.read(purchaseDraftViewModelProvider);
    if (!draft.pendingSubmission || draft.items.isEmpty) return;
    if (!ref.read(onlineStatusProvider)) return;

    _running = true;
    try {
      state = PendingSubmission.sending;

      // The SAME write path screen 3 uses — one way in, which is what keeps
      // "último a escrever vence" (`tecnico §4.5`) a single decision. The
      // purchase key was born with the draft, so an attempt that arrives
      // twice cannot become a second purchase.
      final outcome = await ref
          .read(newPurchaseViewModelProvider.notifier)
          .save(draft: draft, today: DateTime.now());
      if (!ref.mounted) return;

      // Anything but success leaves it pending, silently: it will be tried
      // again when the connection comes back or when the app opens next, and
      // a message about a purchase nobody is looking at is noise.
      state = outcome is PurchaseSaved
          ? PendingSubmission.sent
          : PendingSubmission.idle;
    } finally {
      _running = false;
    }
  }
}

/// No `retry`: `save` classifies its own failures and never throws.
final pendingPurchaseSubmitterProvider =
    NotifierProvider<PendingPurchaseSubmitter, PendingSubmission>(
      PendingPurchaseSubmitter.new,
    );

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository.dart';
import 'package:shopping_list/data/repositories/spending_cap/spending_cap_repository_local.dart';
import 'package:shopping_list/domain/models/money.dart';
import 'package:shopping_list/domain/models/spending_cap.dart';

/// The cap fake every test that saves a purchase needs, in ONE place — the
/// same reason `catalog.dart`, `purchase.dart` and `report.dart` exist.
///
/// **Without it every test that reaches `NewPurchaseViewModel.save` dies of
/// `UnimplementedError`**, because the provider is born throwing.
///
/// The latency is zero, not the fake's 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay.
///
/// **And the month starts with nothing spent**, which the debug fake does not:
/// its seeded R$ 1.300 is 87% of the cap, so every test that merely saves a
/// purchase would cross the 80% cut and get a dialog belonging to a story it
/// is not testing. A test about the cap states its own spending.
Override spendingCapOverride({SpendingCapRepository? repository}) =>
    spendingCapRepositoryProvider.overrideWith(
      (ref) =>
          repository ??
          SpendingCapRepositoryLocal(latency: Duration.zero, spending: const {}),
    );

/// The cap of the acceptance criteria: R$ 1.500 in force since August 2026.
final referenceCap = SpendingCap(
  amount: const Money(150000),
  effectiveFrom: DateTime(2026, 8, 1),
);

/// August 2026 with R$ 1.300 spent and neither cut marked — 87% of the cap,
/// which is the case `requisitos §9` is written around.
MonthCapStatus capStatus({
  DateTime? month,
  SpendingCap? cap,
  // "No cap" is a case the fixture has to be able to state, and a plain `??`
  // over [cap] could not tell it from "the default one".
  bool hasCap = true,
  Money spent = const Money(130000),
  bool warned80 = false,
  bool warned100 = false,
}) {
  final at = month ?? DateTime(2026, 8, 1);
  return MonthCapStatus(
    month: at,
    cap: hasCap ? cap ?? referenceCap : null,
    spent: spent,
    alerts: CapAlerts(month: at, warned80: warned80, warned100: warned100),
  );
}

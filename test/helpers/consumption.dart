import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/consumption/consumption_repository.dart';
import 'package:shopping_list/data/repositories/consumption/consumption_repository_local.dart';

/// The consumption fake every test of screens 2 and 6 needs, in ONE place —
/// the same reason `catalog.dart`, `report.dart` and `shopping_list.dart`
/// exist.
///
/// The latency is zero, not the fake's 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay. It is also
/// what keeps the frozen-clock trap away — inside `testWidgets` a
/// `Future.delayed` only fires when a frame is pumped WITH a duration.
Override consumptionOverride({ConsumptionRepository? repository}) =>
    consumptionRepositoryProvider.overrideWith(
      (ref) => repository ?? ConsumptionRepositoryLocal(latency: Duration.zero),
    );

/// The day both screens are pinned to in every test: the closed window is
/// 01/05 → 31/07/2026 and the month in progress is August. Never
/// `DateTime.now()` — a case that reads "Agosto/2026" would pass in August and
/// fail in September on a CI nobody touched.
final testToday = DateTime(2026, 8, 15);

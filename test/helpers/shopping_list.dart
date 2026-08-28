import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository.dart';
import 'package:shopping_list/data/repositories/shopping_list/shopping_list_repository_local.dart';

/// The shopping list fake every widget test of screen 1 needs, in ONE place —
/// the same reason `catalog.dart` and `device_user.dart` exist.
///
/// The latency is zero, not the fake's 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay.
Override shoppingListOverride({ShoppingListRepository? repository}) =>
    shoppingListRepositoryProvider.overrideWith(
      (ref) => repository ?? ShoppingListRepositoryLocal(latency: Duration.zero),
    );

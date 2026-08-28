import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/catalog/catalog_repository.dart';
import 'package:shopping_list/data/repositories/catalog/catalog_repository_local.dart';
import 'package:shopping_list/data/repositories/store/store_repository.dart';
import 'package:shopping_list/data/repositories/store/store_repository_local.dart';

/// The catalog fakes every widget test of screen 4 needs, in ONE place — the
/// same reason `device_user.dart` exists: nine more screens are coming and
/// each of them would otherwise repeat these two lines.
///
/// The latency is zero, not the fake's 400 ms: what is being tested is the
/// screen, and every pumpAndSettle would otherwise carry the delay.
Override catalogOverride({CatalogRepository? repository}) =>
    catalogRepositoryProvider.overrideWith(
      (ref) => repository ?? CatalogRepositoryLocal(latency: Duration.zero),
    );

Override storeOverride({StoreRepository? repository}) =>
    storeRepositoryProvider.overrideWith(
      (ref) => repository ?? StoreRepositoryLocal(latency: Duration.zero),
    );

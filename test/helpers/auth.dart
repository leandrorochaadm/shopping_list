import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shopping_list/data/repositories/auth/auth_repository.dart';
import 'package:shopping_list/data/repositories/auth/auth_repository_local.dart';

/// The session every widget test needs, in ONE place.
Override authOverride({bool signedIn = true}) =>
    authRepositoryProvider.overrideWith((ref) {
      final repository = AuthRepositoryLocal(
        signedIn: signedIn,
        latency: Duration.zero,
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

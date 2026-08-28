import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client, injected into every `_remote` repository as a PRIVATE
/// member — the UI never reaches it.
///
/// No `retry`: a failure here means `Supabase.initialize` did not run, which
/// is an initialization Error, and Riverpod's automatic retry skips Errors.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Demo and development without a backend: every repository is overridden with
/// its `_local` fake.
///
/// Each feature adds ONE line here — the repository provider itself is
/// declared next to its repository, and the override lives in this list.
final List<Override> overridesLocal = [
  // shoppingListRepositoryProvider.overrideWith((ref) => ShoppingListRepositoryLocal()),
];

/// Production and `dev` against the real Supabase project. Requires
/// `Environment.initializeSupabase()` to have run in `main`.
final List<Override> overridesRemote = [
  // shoppingListRepositoryProvider.overrideWith(
  //   (ref) => ShoppingListRepositoryRemote(client: ref.watch(supabaseClientProvider)),
  // ),
];

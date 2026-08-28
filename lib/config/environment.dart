import 'package:supabase_flutter/supabase_flutter.dart';

/// Which Supabase project this build talks to. There are two — `dev` and
/// `prod` (`tecnico §1.5`) — and they are chosen at build time, never at
/// runtime: web has no flavors, so the separation is `--dart-define` plus two
/// Cloudflare Pages deploys.
///
///     flutter run -d chrome \
///       --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///       --dart-define=SUPABASE_ANON_KEY=eyJ...
abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Fails early with a useful message: String.fromEnvironment returns '' when
  /// --dart-define was not passed, and Supabase.initialize would otherwise
  /// fail much later, as a generic error inside the first query.
  ///
  /// The message is in English because the reader is the developer at the
  /// console, not the user on the screen.
  static Future<void> initializeSupabase() async {
    if (!isSupabaseConfigured) {
      throw ArgumentError(
        'SUPABASE_URL/SUPABASE_ANON_KEY are empty. Run with: flutter run '
        '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    // `publishableKey`, not `anonKey`: the SDK renamed the parameter and
    // deprecated the old name. The value is the same public key the
    // Supabase dashboard shows (tecnico 2.1, decision 6).
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}

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

  /// The guard below is a SAFETY NET, not the mechanism that protects a
  /// forgotten deploy: `main` only calls this inside `StartupPlan.remote`, and
  /// that plan is only returned when [isSupabaseConfigured] is already true, so
  /// the throw is unreachable from the app as it runs today. What actually
  /// catches a build shipped without the two --dart-define is
  /// `resolveStartup` in `startup.dart`, returning `missingConfiguration` and
  /// landing on `MisconfiguredApp`.
  ///
  /// It stays because it is free and because it covers the second caller this
  /// function will eventually have — one that has not asked `startup.dart`
  /// first.
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
      // There is no login here (decision 6): the barrier is an undisclosed
      // URL. The SDK defaults assume an app that has one — they build a
      // SharedPreferences-backed LocalStorage and AWAIT its initialize()
      // inside this call, restore a session that never exists and watch the
      // URL for an auth callback.
      //
      // The damage is not speed, it is the wrong message: in a Safari private
      // window the storage refusal would be raised from INSIDE this call, land
      // in main's catch and tell the user to check SUPABASE_URL — two values
      // that are correct — on a phone with no console to disprove it. With
      // persistSession false the local storage becomes EmptyLocalStorage,
      // whose initialize() is empty, so a browser that denies storage can no
      // longer make THIS call throw: that failure belongs to Hive, and
      // `MisconfiguredApp.storageUnavailable()` is the screen for it.
      //
      // The PKCE storage above it in the SDK is still created unconditionally,
      // but outside the awaited path — at worst it prints a line to a console
      // where it confuses nobody.
      authOptions: const FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  }
}

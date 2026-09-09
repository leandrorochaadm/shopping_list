import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/config/environment.dart';

void main() {
  group('Environment', () {
    // `flutter test` runs with no --dart-define, so String.fromEnvironment
    // returns '' here — the very state a forgotten deploy flag produces.
    // The other half of the `&&` (one value present, the other missing) can
    // only be exercised by re-running this file with a single define.
    test('reports the build as unconfigured when the defines are missing', () {
      expect(Environment.supabaseUrl, isEmpty);
      expect(Environment.supabaseAnonKey, isEmpty);
      expect(Environment.isSupabaseConfigured, isFalse);
    });

    test('refuses to initialize Supabase without both values', () async {
      // This guards the SAFETY NET, not the deploy: `main` only calls
      // initializeSupabase inside StartupPlan.remote, which is only chosen
      // when the defines are already there, so nothing in the app as it runs
      // today reaches this throw. What protects a build shipped without the
      // flags is resolveStartup — see startup_test.dart. The guard is kept for
      // the second caller this function will eventually have, and this test is
      // what keeps it honest until then.
      //
      // expectLater, awaited: an async matcher left unawaited can report its
      // failure outside this test.
      await expectLater(
        Environment.initializeSupabase(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
          ),
        ),
      );
    });
  });

  group('app version', () {
    test('the version constant matches pubspec.yaml', () {
      // `flutter test` runs with the project root as the working directory.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(
        match,
        isNotNull,
        reason: 'pubspec.yaml has no `version: x.y.z` line',
      );
      // Bumping the pubspec and forgetting the constant is what this catches —
      // the app would keep announcing the previous version forever.
      expect(match!.group(1), Environment.fallbackVersionName);
    });

    test('with no define at all the build is a local one', () {
      // Same state as a forgotten deploy flag, and the same state every test
      // run is in: no --dart-define, so the three reads come back empty.
      final version = Environment.appVersion;

      expect(version.name, Environment.fallbackVersionName);
      expect(version.buildNumber, isNull);
      expect(version.commit, isNull);
      expect(version.isLocalBuild, isTrue);
    });
  });
}

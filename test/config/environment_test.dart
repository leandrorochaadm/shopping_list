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
      // Fails here, naming the two flags, instead of much later as a generic
      // error inside the first query. expectLater, awaited: an async matcher
      // left unawaited can report its failure outside this test.
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
}

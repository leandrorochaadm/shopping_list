import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/config/startup.dart';

void main() {
  group('resolveStartup', () {
    test('talks to the real project whenever the defines are there', () {
      expect(
        resolveStartup(configured: true, debug: false),
        StartupPlan.remote,
      );
      // Debug does not divert a configured build to the fakes: developing
      // against the dev project is the normal way to work.
      expect(resolveStartup(configured: true, debug: true), StartupPlan.remote);
    });

    test('falls back to the fakes only while debugging', () {
      expect(resolveStartup(configured: false, debug: true), StartupPlan.fakes);
    });

    test('refuses to run a build outside debug with no configuration', () {
      // The gap this closes: silently using the fakes here would ship an app
      // that looks like it works and saves nothing. A profile build counts as
      // outside debug, which is why main passes kDebugMode and not
      // kReleaseMode.
      expect(
        resolveStartup(configured: false, debug: false),
        StartupPlan.missingConfiguration,
      );
    });
  });
}

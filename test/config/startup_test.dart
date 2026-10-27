import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/config/app_config.dart';
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

  group('configured by AppConfig', () {
    test('a test run without defines is not configured', () {
      final configured = AppConfig.fromEnvironment().missingKeys.isEmpty;
      expect(configured, isFalse);
      expect(
        resolveStartup(configured: configured, debug: true),
        StartupPlan.fakes,
      );
      expect(
        resolveStartup(configured: configured, debug: false),
        StartupPlan.missingConfiguration,
      );
    });

    test('an address makes it remote in debug and outside it', () {
      final configured = const AppConfig(
        pocketBaseUrl: 'http://127.0.0.1:8095',
      ).missingKeys.isEmpty;
      expect(
        resolveStartup(configured: configured, debug: true),
        StartupPlan.remote,
      );
      expect(
        resolveStartup(configured: configured, debug: false),
        StartupPlan.remote,
      );
    });

    test('a blank address is missing configuration outside debug', () {
      final configured = const AppConfig(
        pocketBaseUrl: '   ',
      ).missingKeys.isEmpty;
      expect(
        resolveStartup(configured: configured, debug: false),
        StartupPlan.missingConfiguration,
      );
    });
  });
}

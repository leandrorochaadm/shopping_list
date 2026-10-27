import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/config/environment.dart';

void main() {
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

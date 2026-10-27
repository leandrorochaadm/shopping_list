import '../domain/models/app_version.dart';

/// What the CI knows about this build: version, build number and commit.
/// Where the backend lives is not here — `AppConfig`
/// (`lib/config/app_config.dart`) reads it from
/// `--dart-define-from-file=config/<env>.json`.
abstract final class Environment {
  /// The `version:` of `pubspec.yaml`, WITHOUT the `+build` suffix.
  ///
  /// It is duplicated here because the pubspec is not readable at runtime on
  /// web and reading it would cost a new dependency, which the frozen list of
  /// `tecnico §3` rules out. What keeps the copy honest is
  /// `test/config/environment_test.dart`, which reads the pubspec and fails
  /// when the two drift apart.
  static const fallbackVersionName = '1.0.0';

  /// Filled by the CI from the pubspec; empty on a local run, when the
  /// constant above answers instead.
  static const _versionName = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: fallbackVersionName,
  );

  /// `github.run_number`. Empty on a local run.
  static const _buildNumber = String.fromEnvironment('APP_BUILD_NUMBER');

  /// The first 7 chars of `github.sha`. Empty on a local run.
  static const _commit = String.fromEnvironment('APP_COMMIT');

  /// What the `≡` shows in its footer.
  ///
  /// An empty define and an absent define are the same thing here — a local
  /// build — and both become `null`, never `''` or `0`: [AppVersion] treats
  /// `null` as "nobody counted this run". `int.tryParse('')` already returns
  /// `null`, which is why the build number needs no extra `if`.
  static AppVersion get appVersion => AppVersion(
    name: _versionName.isEmpty ? fallbackVersionName : _versionName,
    buildNumber: int.tryParse(_buildNumber),
    commit: _commit.isEmpty ? null : _commit,
  );
}

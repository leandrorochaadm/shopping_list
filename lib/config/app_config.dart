import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// Build-time settings. The value enters through
/// `--dart-define-from-file=config/<env>.json`; `test/config/app_config_test.dart`
/// checks that the example files carry exactly these keys.
final class AppConfig {
  const AppConfig({required this.pocketBaseUrl});

  // `String.fromEnvironment` must be `const`; otherwise it returns empty in
  // release and web builds.
  factory AppConfig.fromEnvironment() =>
      const AppConfig(pocketBaseUrl: String.fromEnvironment(pocketBaseUrlKey));

  static const pocketBaseUrlKey = 'POCKETBASE_URL';

  final String pocketBaseUrl;

  IList<String> get missingKeys =>
      IList([if (pocketBaseUrl.trim().isEmpty) pocketBaseUrlKey]);

  @override
  bool operator ==(Object other) =>
      other is AppConfig && other.pocketBaseUrl == pocketBaseUrl;

  @override
  int get hashCode => pocketBaseUrl.hashCode;
}

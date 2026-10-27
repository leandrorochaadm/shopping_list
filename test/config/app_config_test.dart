import 'dart:convert';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/config/app_config.dart';

Map<String, Object?> readExample(String name) =>
    jsonDecode(File('config/$name').readAsStringSync()) as Map<String, Object?>;

void main() {
  group('AppConfig', () {
    test('fromEnvironment without defines misses the PocketBase URL', () {
      expect(
        AppConfig.fromEnvironment().missingKeys,
        [AppConfig.pocketBaseUrlKey].lock,
      );
    });

    test('has no missing keys when the URL is set', () {
      const config = AppConfig(pocketBaseUrl: 'http://127.0.0.1:8095');
      expect(config.missingKeys, isEmpty);
    });

    test('reports the key when the URL is blank', () {
      const config = AppConfig(pocketBaseUrl: '   ');
      expect(config.missingKeys, [AppConfig.pocketBaseUrlKey].lock);
    });

    test('equality covers the URL', () {
      const a = AppConfig(pocketBaseUrl: 'https://a.example.com');
      const same = AppConfig(pocketBaseUrl: 'https://a.example.com');
      const other = AppConfig(pocketBaseUrl: 'https://b.example.com');
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(other));
    });

    for (final name in ['dev.json.example', 'prod.json.example']) {
      test('$name has only the PocketBase URL key, filled', () {
        final json = readExample(name);
        expect(json.keys, [AppConfig.pocketBaseUrlKey]);
        expect(json[AppConfig.pocketBaseUrlKey], isA<String>());
        expect(
          (json[AppConfig.pocketBaseUrlKey]! as String).trim(),
          isNotEmpty,
        );
      });
    }

    test('prod example uses https', () {
      final url = readExample('prod.json.example')[AppConfig.pocketBaseUrlKey]!;
      expect(url as String, startsWith('https://'));
    });
  });
}

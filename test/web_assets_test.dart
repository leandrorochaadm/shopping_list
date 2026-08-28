import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/ui/core/themes/app_theme.dart';

/// The PWA shell is the one part of the app the Dart compiler never sees: the
/// splash color, the iOS status bar color and the installed name live in
/// `web/`, and nothing else would notice them drifting from the theme.
void main() {
  String hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final indexHtml = File('web/index.html').readAsStringSync();
  final robotsTxt = File('web/robots.txt').readAsStringSync();

  test('manifest colors follow the theme, not a copy of it', () {
    final scheme = AppTheme.light.colorScheme;

    // Changing the seed in app_theme.dart is what this catches: the splash
    // would keep the old color and only the phone would show it.
    expect(manifest['theme_color'], hex(scheme.primary));
    expect(manifest['background_color'], hex(scheme.surface));
  });

  test('index.html declares the same theme color as the manifest', () {
    expect(
      indexHtml,
      contains(
        '<meta name="theme-color" content="${manifest['theme_color']}">',
      ),
    );
  });

  test('the installed app is named and described in pt-BR', () {
    expect(manifest['name'], 'Lista de compras');
    expect(manifest['short_name'], 'Lista');
    expect(manifest['lang'], 'pt-BR');
    expect(indexHtml, contains('<html lang="pt-BR">'));
    expect(indexHtml, contains('<title>Lista de compras</title>'));
    // The Flutter template's own line, which says nothing about this app.
    expect(indexHtml, isNot(contains('A new Flutter project')));
  });

  test('keeps the phone in portrait, as decision 2 froze it', () {
    expect(manifest['orientation'], 'portrait-primary');
    expect(manifest['display'], 'standalone');
  });

  test('declares apple-mobile-web-app-capable, for iOS older than the manifest '
      'display member', () {
    // Current iOS decides full screen from mobile-web-app-capable plus the
    // manifest, both already here. This one is the net for older versions,
    // and the H0 acceptance criteria name it by name.
    expect(
      indexHtml,
      contains('<meta name="apple-mobile-web-app-capable" content="yes">'),
    );
  });

  test(
    'asks search engines to stay away, since the URL is the only barrier',
    () {
      // Decision 6: no login, permissive RLS, a public anon key. Whoever
      // has the address has the database, so it cannot end up in an index.
      expect(indexHtml, contains('<meta name="robots" content="noindex">'));
    },
  );

  test('ships a robots.txt that disallows everything', () {
    // The tag above only reaches crawlers that parse the page; this file is
    // for the ones that read it before asking for anything else.
    expect(robotsTxt, contains('User-agent: *'));
    expect(robotsTxt, contains('Disallow: /'));
  });
}

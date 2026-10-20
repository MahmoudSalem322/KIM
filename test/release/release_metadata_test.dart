import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/l10n/app_strings.dart';

void main() {
  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!;

  test('displayed version matches the release in pubspec', () {
    expect(AppStrings('en')('version'), 'Kim · version ${version[1]}');
    expect(AppStrings('ar')('version'), contains(version[1]!));
    expect(int.parse(version[2]!), greaterThan(1));
  });

  test('web shell is offline-first, accessible and has no external assets', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(index, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    expect(index, contains('<noscript>'));
    expect(index, contains('prefers-color-scheme:dark'));
    expect(index, isNot(contains('dir="rtl"')));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(bootstrap, contains('offline_worker.js'));
    for (final source in [index, bootstrap]) {
      expect(RegExp(r'''(src|href)=["']https?://''').hasMatch(source), false);
      expect(source, isNot(contains('gstatic.com')));
    }
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    expect(manifest['start_url'], '.');
    expect(manifest['display'], 'standalone');
    for (final icon in manifest['icons'] as List) {
      expect(File('web/${(icon as Map)['src']}').existsSync(), true);
    }
  });

  test('pubspec bundles the fonts used for Arabic and Latin rendering', () {
    for (final font in ['NotoSansArabic.ttf', 'NotoSans.ttf']) {
      expect(File('assets/fonts/$font').existsSync(), true, reason: font);
    }
    expect(AppDatabase.schemaVersion, 11);
  });
}

import 'dart:convert';
import 'dart:io';

/// Run after every release build. Revision changes install a complete new cache;
/// activation happens only when all files have been downloaded successfully.
///
/// Only files the configured loader can request are precached and deployed:
/// debug symbol maps and renderer variants for other build modes are removed,
/// so first offline installation downloads what the app actually runs.
void main() {
  final root = Directory('build/web');
  if (!root.existsSync()) throw StateError('Run flutter build web first');
  final bootstrap = File('build/web/flutter_bootstrap.js').readAsStringSync();
  final unused = unusedRuntimeFiles(bootstrap);
  var pruned = 0;
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    if (unused(relative(file))) {
      pruned += file.lengthSync();
      file.deleteSync();
    }
  }
  for (final directory
      in root.listSync(recursive: true).whereType<Directory>().toList()
        ..sort((a, b) => b.path.length.compareTo(a.path.length))) {
    if (directory.listSync().isEmpty) directory.deleteSync();
  }
  final entries =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => (path: relative(f), bytes: f.lengthSync()))
          .where(
            (f) =>
                f.path != 'offline_worker.js' &&
                f.path != 'flutter_service_worker.js' &&
                f.path != '.last_build_id' &&
                !f.path.endsWith('.map'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final files = [for (final f in entries) f.path];
  final bytes = entries.fold<int>(0, (sum, f) => sum + f.bytes);
  final revision = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final source =
      '''
const PREFIX = 'kim-' + encodeURIComponent(self.registration.scope) + '-';
const CACHE = PREFIX + '$revision';
const FILES = ${jsonEncode(files)};
const urls = FILES.map(path => new URL(path, self.registration.scope).href);
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      await cache.addAll(urls.map(url => new Request(url, {cache: 'reload'})));
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (!url.href.startsWith(self.registration.scope)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request, {ignoreSearch: true});
    if (cached) return cached;
    if (event.request.mode === 'navigate') {
      const shell = await cache.match(new URL('index.html', self.registration.scope).href);
      if (shell) return shell;
    }
    return fetch(event.request);
  })());
});
''';
  File('build/web/offline_worker.js').writeAsStringSync(source);
  stdout.writeln(
    'Offline cache generated: ${files.length} local files, '
    '${(bytes / 1048576).toStringAsFixed(1)} MiB; '
    'removed ${(pruned / 1048576).toStringAsFixed(1)} MiB of unused files.',
  );
}

String relative(File file) =>
    file.path.replaceAll('\\', '/').replaceFirst('build/web/', '');

/// Decides from the generated loader configuration which engine files can
/// never be requested. Unknown configurations keep every file.
bool Function(String) unusedRuntimeFiles(String bootstrap) {
  final match = RegExp(r'_flutter\.buildConfig = (\{.*?\});')
      .firstMatch(bootstrap);
  if (match == null) return (_) => false;
  final config = jsonDecode(match[1]!) as Map<String, Object?>;
  final renderers = {
    for (final build in (config['builds'] as List? ?? const []))
      if ((build as Map)['renderer'] case final Object renderer) renderer,
  };
  if (renderers.isEmpty ||
      !renderers.every(const {'canvaskit', 'skwasm'}.contains)) {
    return (_) => false;
  }
  final skwasm = renderers.contains('skwasm');
  // The inlined engine loader always mentions this option; only the app's
  // own load call after the build configuration can enable it.
  final webParagraph = bootstrap
      .substring(match.end)
      .contains('preferWebParagraph');
  return (path) =>
      path.endsWith('.symbols') ||
      (!skwasm && RegExp(r'^canvaskit/(skwasm|wimp)').hasMatch(path)) ||
      (!webParagraph && path.startsWith('canvaskit/webparagraph/'));
}

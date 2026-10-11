import 'dart:convert';
import 'dart:io';

/// Run after every release build. Revision changes install a complete new cache;
/// activation happens only when all files have been downloaded successfully.
void main() {
  final root = Directory('build/web');
  if (!root.existsSync()) throw StateError('Run flutter build web first');
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (f) => f.path.replaceAll('\\', '/').replaceFirst('build/web/', ''),
          )
          .where(
            (f) =>
                f != 'offline_worker.js' &&
                f != 'flutter_service_worker.js' &&
                !f.endsWith('.map'),
          )
          .toList()
        ..sort();
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
  stdout.writeln('Offline cache generated: ${files.length} local files.');
}

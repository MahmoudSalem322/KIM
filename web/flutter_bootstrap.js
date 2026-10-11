{{flutter_js}}
{{flutter_build_config}}

// Flutter's release build includes CanvasKit locally. No CDN runtime requests.
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      // Register only release builds produced by tool/build_web.ps1.
      const response = await fetch('offline_worker.js', {cache: 'no-store'});
      if (!response.ok || !(response.headers.get('content-type') || '').includes('javascript')) return;
      await navigator.serviceWorker.register('offline_worker.js');
    } catch (error) {
      console.info('Kim offline cache will retry on the next online visit.', error);
    }
  });
}

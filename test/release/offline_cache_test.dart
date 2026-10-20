import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_offline.dart' show unusedRuntimeFiles;

void main() {
  // The real generated file inlines the engine loader, which itself mentions
  // preferWebParagraph, before the build configuration and the app's call.
  String bootstrap(String builds, {String extra = ''}) =>
      'let o=i&&e.preferWebParagraph&&s.hasTextCluster;\n'
      '_flutter.buildConfig = {"engineRevision":"x","builds":$builds,'
      '"useLocalCanvasKit":true};\n'
      "_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'$extra}});";

  test(
    'dart2js CanvasKit builds keep only the CanvasKit variants they load',
    () {
      final unused = unusedRuntimeFiles(
        bootstrap(
          '[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"},{}]',
        ),
      );
      for (final kept in [
        'main.dart.js',
        'index.html',
        'canvaskit/canvaskit.js',
        'canvaskit/canvaskit.wasm',
        'canvaskit/chromium/canvaskit.js',
        'canvaskit/chromium/canvaskit.wasm',
        'assets/assets/fonts/NotoSansArabic.ttf',
      ]) {
        expect(unused(kept), false, reason: kept);
      }
      for (final removed in [
        'canvaskit/canvaskit.js.symbols',
        'canvaskit/chromium/canvaskit.js.symbols',
        'canvaskit/skwasm.wasm',
        'canvaskit/skwasm_heavy.js',
        'canvaskit/wimp.wasm',
        'canvaskit/webparagraph/canvaskit.wasm',
      ]) {
        expect(unused(removed), true, reason: removed);
      }
    },
  );

  test('wasm and opt-in renderer builds keep their engine files', () {
    final wasm = unusedRuntimeFiles(
      bootstrap(
        '[{"compileTarget":"dart2wasm","renderer":"skwasm","mainWasmPath":"main.dart.wasm"},'
        '{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]',
        extra: ', preferWebParagraph: true',
      ),
    );
    expect(wasm('canvaskit/skwasm.wasm'), false);
    expect(wasm('canvaskit/wimp.js'), false);
    expect(wasm('canvaskit/webparagraph/canvaskit.wasm'), false);
    expect(wasm('canvaskit/skwasm.js.symbols'), true);
  });

  test('unknown loader configuration never prunes engine files', () {
    expect(unusedRuntimeFiles('custom loader')('canvaskit/skwasm.wasm'), false);
    expect(
      unusedRuntimeFiles(
        bootstrap('[{"compileTarget":"dart2js","renderer":"future"}]'),
      )('canvaskit/canvaskit.js.symbols'),
      false,
    );
  });
}

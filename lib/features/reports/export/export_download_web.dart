import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

abstract final class ExportDownload {
  static Future<String> save(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // Permit the browser to consume the object URL before releasing it.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => web.URL.revokeObjectURL(url),
    );
    return filename;
  }
}

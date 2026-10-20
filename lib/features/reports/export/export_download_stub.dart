import 'dart:typed_data';

abstract final class ExportDownload {
  static Future<String> save(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async => throw UnsupportedError('File export unavailable');
}

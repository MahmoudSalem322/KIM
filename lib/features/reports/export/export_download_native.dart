import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

abstract final class ExportDownload {
  static Future<String> save(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

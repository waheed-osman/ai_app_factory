import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands generated files to the user through the Android share sheet
/// (save to Files, Drive, WhatsApp, ...).
class FileExporter {
  Future<void> shareBytes(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    );
  }
}

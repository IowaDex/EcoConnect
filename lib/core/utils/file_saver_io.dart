import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the data URL to a temporary file and opens the system share sheet.
///
/// A phone has no "downloads" folder an app may write to, so the share sheet
/// is the platform's own save path: the officer picks Files, Drive or a printer
/// and the PDF lands wherever they choose. Returns false only when the file
/// could not be written or the sheet could not be opened — a dismissed sheet
/// still counts as a successful export, because the user chose to close it.
Future<bool> saveDataUrl(String dataUrl, String fileName) async {
  final bytes = _decode(dataUrl);
  if (bytes == null) return false;

  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        subject: fileName,
        title: fileName,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

Uint8List? _decode(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } on FormatException {
    return null;
  }
}

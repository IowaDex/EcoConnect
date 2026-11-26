import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves a base64 data URL through the platform's own save dialog.
///
/// Android, iOS and desktop builds have no browser download, so the decoded
/// bytes are handed to the system file picker. The user chooses the folder —
/// Downloads, Files, Drive — and the file is written there with its real name.
/// On Android this is the system "Save to" sheet (`ACTION_CREATE_DOCUMENT`),
/// which needs no storage permission.
///
/// Returns false when the dialog is cancelled or the platform refuses the
/// write, so the caller can tell the user instead of claiming success.
Future<bool> saveDataUrl(String dataUrl, String fileName) async {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return false;

  late final Uint8List bytes;
  try {
    bytes = base64Decode(dataUrl.substring(comma + 1));
  } on FormatException {
    return false;
  }

  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      // The same helper saves PDF manuals and HTML memos, so the type comes
      // from the data URL itself rather than being pinned to PDF.
      mimeType: _mimeType(dataUrl, comma, fileName),
      dialogTitle: 'Save file',
    );
    return uri != null;
  } catch (_) {
    return false;
  }
}

/// Reads `application/pdf` out of `data:application/pdf;base64,…`, falling
/// back to the file extension when the URL carries no type.
String _mimeType(String dataUrl, int comma, String fileName) {
  final header = dataUrl.substring(0, comma);
  if (header.startsWith('data:')) {
    final declared = header.substring(5).split(';').first.trim();
    if (declared.contains('/')) return declared;
  }
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'html' || 'htm' => 'text/html',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

import 'package:web/web.dart' as web;

/// Triggers a real browser download for an inline data URL.
///
/// An anchor with the `download` attribute is the only way to save a data URL
/// without a server round trip; clicking it opens the browser's own save
/// dialog, so the file lands in the user's downloads with its original name.
Future<bool> saveDataUrl(String dataUrl, String fileName) async {
  final anchor = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

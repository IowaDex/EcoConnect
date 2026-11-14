import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// Saves a base64 data URL to the user's downloads.
///
/// Returns false on platforms without a browser download (Android/iOS), so the
/// caller can fall back to opening the file in a viewer.
Future<bool> saveDataUrl(String dataUrl, String fileName) =>
    impl.saveDataUrl(dataUrl, fileName);

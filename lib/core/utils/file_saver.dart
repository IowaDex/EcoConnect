import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    as impl;

/// Saves a base64 data URL to the user's device.
///
/// The web build triggers a browser download; every other platform opens the
/// system save dialog and writes the bytes to the folder the user picks.
/// Returns false when the save was cancelled or refused, so the caller can
/// report it instead of claiming success.
Future<bool> saveDataUrl(String dataUrl, String fileName) =>
    impl.saveDataUrl(dataUrl, fileName);

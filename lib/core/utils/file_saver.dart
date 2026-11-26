import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart'
    as impl;

/// Saves a base64 data URL to the device.
///
/// Web triggers a browser download; Android and iOS write the file to a
/// temporary folder and open the system share sheet so the officer can save
/// it, mail it or print it. Returns false only when the export could not be
/// started at all.
Future<bool> saveDataUrl(String dataUrl, String fileName) =>
    impl.saveDataUrl(dataUrl, fileName);

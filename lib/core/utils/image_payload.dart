import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A file encoded for Firestore storage.
///
/// The project does not ship a Storage bucket, so uploads are compressed and
/// stored as data URLs in the owning document. That keeps every feature
/// working without extra infrastructure and keeps each file scoped by the
/// same Firestore rules as its record.
class UploadPayload {
  const UploadPayload({
    required this.dataUrl,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String dataUrl;
  final String fileName;
  final String mimeType;
  final int bytes;

  bool get isPdf => mimeType == 'application/pdf';

  double get sizeKb => bytes / 1024;

  Map<String, dynamic> toMap() => {
        'dataUrl': dataUrl,
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      };

  static UploadPayload? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final url = raw['dataUrl'];
    if (url is! String || url.isEmpty) return null;
    return UploadPayload(
      dataUrl: url,
      fileName: (raw['fileName'] as String?) ?? 'file',
      mimeType: (raw['mimeType'] as String?) ?? 'image/jpeg',
      bytes: (raw['bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class UploadException implements Exception {
  const UploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Validates, resizes and compresses files before they reach Firestore.
abstract final class UploadCodec {
  /// Firestore documents are capped at 1 MiB. Waste and request records can
  /// hold up to three photos, so each photo is compressed to 190 KB: three
  /// base64 payloads plus metadata stay comfortably under the limit.
  static const int maxDocumentBytes = 190 * 1024;

  /// A single ID document has the whole record to itself.
  static const int maxIdImageBytes = 500 * 1024;

  static const int maxPdfBytes = 600 * 1024;

  static const Set<String> allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> allowedDocumentExtensions = {
    'jpg',
    'jpeg',
    'png',
    'pdf',
  };

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static bool isAllowedDocument(String fileName) =>
      allowedDocumentExtensions.contains(extensionOf(fileName));

  static bool isPdf(String fileName) => extensionOf(fileName) == 'pdf';

  /// Decodes, downsizes and JPEG-encodes an image until it fits.
  static Future<UploadPayload> image(
    Uint8List bytes, {
    required String fileName,
    int maxDimension = 1280,
  }) async {
    if (!allowedImageExtensions.contains(extensionOf(fileName))) {
      throw const UploadException('Please choose a JPG, PNG or WebP image.');
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const UploadException('That image could not be read.');
    }

    var image = decoded;
    if (image.width > maxDimension || image.height > maxDimension) {
      final landscape = image.width >= image.height;
      image = img.copyResize(
        image,
        width: landscape ? maxDimension : null,
        height: landscape ? null : maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    // Lower quality first, then shrink the long edge, until the encoded file
    // fits. Normal phone photos reach the target in two or three passes.
    var quality = 74;
    var encoded = img.encodeJpg(image, quality: quality);
    var attempt = 0;
    while (encoded.length > maxDocumentBytes && attempt < 8) {
      attempt++;
      if (quality > 44) {
        quality -= 10;
      } else {
        image = img.copyResize(
          image,
          width: (image.width * 0.75).round(),
          interpolation: img.Interpolation.average,
        );
        quality = 62;
      }
      encoded = img.encodeJpg(image, quality: quality);
    }

    if (encoded.length > maxDocumentBytes) {
      throw const UploadException(
        'This image could not be compressed enough. Please choose another photo.',
      );
    }

    return UploadPayload(
      dataUrl: 'data:image/jpeg;base64,${base64Encode(encoded)}',
      fileName: fileName,
      mimeType: 'image/jpeg',
      bytes: encoded.length,
    );
  }

  /// Wraps a PDF or image used as an identification document.
  static UploadPayload document(Uint8List bytes, {required String fileName}) {
    if (!isAllowedDocument(fileName)) {
      throw const UploadException('Please upload a JPG, PNG or PDF file.');
    }

    final ext = extensionOf(fileName);
    if (ext == 'pdf') {
      if (bytes.length > maxPdfBytes) {
        throw const UploadException(
          'That PDF is too large. Please upload a file under 600 KB.',
        );
      }
      return UploadPayload(
        dataUrl: 'data:application/pdf;base64,${base64Encode(bytes)}',
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes.length,
      );
    }

    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    if (bytes.length > maxIdImageBytes) {
      throw const UploadException(
        'That image is too large. Please choose a photo under 500 KB.',
      );
    }
    return UploadPayload(
      dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
      fileName: fileName,
      mimeType: mime,
      bytes: bytes.length,
    );
  }
}

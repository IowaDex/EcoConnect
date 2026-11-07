import 'dart:convert';
import 'dart:typed_data';

import 'package:eco_connect/core/utils/image_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg(int width, int height, {int? orientation}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 140, 60));
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image));
}

img.Image _decode(UploadPayload payload) =>
    img.decodeJpg(base64Decode(payload.dataUrl.split(',').last))!;

void main() {
  group('UploadCodec.image', () {
    test('encodes a photo to a JPEG data URL under the size cap', () async {
      final payload =
          await UploadCodec.image(_jpeg(2400, 1800), fileName: 'photo.jpg');

      expect(payload.mimeType, 'image/jpeg');
      expect(payload.dataUrl, startsWith('data:image/jpeg;base64,'));
      expect(payload.bytes, lessThanOrEqualTo(UploadCodec.maxDocumentBytes));
      final decoded = _decode(payload);
      expect(decoded.width, 1280);
      expect(decoded.height, 960);
    });

    test('applies the EXIF rotation so portrait photos stay upright', () async {
      // Stored landscape with orientation 6 = "rotate 90 degrees to view".
      final payload = await UploadCodec.image(
        _jpeg(200, 100, orientation: 6),
        fileName: 'portrait.jpg',
      );

      final decoded = _decode(payload);
      expect(decoded.width, 100);
      expect(decoded.height, 200);
    });

    test('rejects bytes that are not an image with a readable message', () async {
      await expectLater(
        UploadCodec.image(Uint8List.fromList([1, 2, 3]), fileName: 'x.jpg'),
        throwsA(isA<UploadException>()
            .having((e) => e.message, 'message', 'That image could not be read.')),
      );
    });

    test('rejects an unsupported file type before decoding', () async {
      await expectLater(
        UploadCodec.image(_jpeg(10, 10), fileName: 'notes.gif'),
        throwsA(isA<UploadException>()),
      );
    });
  });
}

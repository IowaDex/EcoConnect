import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';

/// Captures a signature without paper.
///
/// Two ways in, one way out: draw it with a finger or a mouse, or upload a
/// photo of a wet signature. Both come back as a base64 PNG data URL so the
/// ticket can store it inside Firestore with no storage bucket.
Future<String?> showSignatureSheet(
  BuildContext context, {
  required String signerLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SignatureSheet(signerLabel: signerLabel),
  );
}

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet({required this.signerLabel});

  final String signerLabel;

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final _boundary = GlobalKey();
  final _picker = ImagePicker();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  bool _busy = false;
  String? _error;

  bool get _hasInk => _strokes.any((stroke) => stroke.length > 1);

  void _start(Offset point) {
    setState(() {
      _current = [point];
      _strokes.add(_current);
    });
  }

  void _extend(Offset point) {
    if (_current.isEmpty) return;
    setState(() => _current.add(point));
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _error = null;
    });
  }

  Future<void> _saveDrawing() async {
    if (!_hasInk) {
      setState(() => _error = 'Pumirma muna bago i-save.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final object = _boundary.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) {
        throw const UploadException('Could not capture the signature.');
      }
      final image = await object.toImage(pixelRatio: 2.4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const UploadException('Could not encode the signature.');
      }
      final encoded = base64Encode(bytes.buffer.asUint8List());
      if (!mounted) return;
      Navigator.of(context).pop('data:image/png;base64,$encoded');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final payload = await UploadCodec.image(bytes, fileName: file.name);
      if (!mounted) return;
      Navigator.of(context).pop(payload.dataUrl);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pirma ng ${widget.signerLabel}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gumuhit gamit ang daliri (o mouse), o mag-upload ng picture ng '
            'pirma. Walang print, digital lahat.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _boundary,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sage),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: (details) => _start(details.localPosition),
                  onPanUpdate: (details) => _extend(details.localPosition),
                  onPanEnd: (_) => _current = [],
                  child: CustomPaint(
                    painter: _InkPainter(_strokes),
                    size: Size.infinite,
                    child: _hasInk
                        ? const SizedBox.expand()
                        : const Center(
                            child: Text(
                              'Pumirma dito',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.sage,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 10, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Burahin'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkMuted,
                    side: const BorderSide(color: AppColors.sage),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Upload'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.sage),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _busy ? null : _saveDrawing,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('I-save ang pirma'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B2B1F)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.4, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}

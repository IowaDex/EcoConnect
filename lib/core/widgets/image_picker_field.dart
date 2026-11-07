import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../utils/image_payload.dart';

/// Photo picker with preview, used by waste uploads, announcements, events
/// and government ID submission.
///
/// Set [documentMode] to also accept a PDF. Files are compressed by
/// [UploadCodec] before they are handed back, so callers only ever deal with
/// payloads that fit in a Firestore document.
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Photo',
    this.helper = 'JPG, PNG or WebP · compressed automatically',
    this.documentMode = false,
    this.previewHeight = 150,
    this.enabled = true,
  });

  final UploadPayload? value;
  final ValueChanged<UploadPayload?> onChanged;
  final String label;
  final String helper;
  final bool documentMode;
  final double previewHeight;
  final bool enabled;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final payload = await UploadCodec.image(
        bytes,
        fileName: file.name.isEmpty ? 'photo.jpg' : file.name,
      );
      if (mounted) widget.onChanged(payload);
    } on UploadException catch (e) {
      _error(e.message);
    } catch (e) {
      _error('Could not read that photo. Please try another one.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPdf() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _error('Could not read that file. Please try again.');
        return;
      }
      final payload = UploadCodec.document(bytes, fileName: file.name);
      if (mounted) widget.onChanged(payload);
    } on UploadException catch (e) {
      _error(e.message);
    } catch (e) {
      _error('Could not read that file. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
  }

  Future<void> _chooseSource() async {
    if (!widget.enabled) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            if (widget.documentMode)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined,
                    color: AppColors.primary),
                title: const Text('Choose a file (JPG, PNG or PDF)'),
                onTap: () => Navigator.of(ctx).pop('file'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _pick(ImageSource.camera);
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'file':
        await _pickPdf();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreen,
              ),
            ),
            const Spacer(),
            if (value != null)
              TextButton(
                onPressed: widget.enabled
                    ? () => widget.onChanged(null)
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _chooseSource,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: widget.previewHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightGreen.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: value == null
                    ? AppColors.sage
                    : AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _busy
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                : value == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.documentMode
                                ? 'Add a photo or PDF'
                                : 'Add a photo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.helper,
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      )
                    : _preview(value),
          ),
        ),
      ],
    );
  }

  Widget _preview(UploadPayload payload) {
    if (payload.isPdf) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 34, color: AppColors.error),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                payload.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${payload.sizeKb.toStringAsFixed(0)} KB · tap to replace',
              style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
            ),
          ],
        ),
      );
    }

    final comma = payload.dataUrl.indexOf(',');
    final encoded = comma >= 0 ? payload.dataUrl.substring(comma + 1) : '';
    final bytes = encoded.isEmpty ? null : base64Decode(encoded);
    if (bytes == null) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Tap to replace',
              style: TextStyle(fontSize: 8.5, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../services/waste_service.dart';

/// Resident waste upload: photos, category, quantity and pickup location.
class WasteUploadScreen extends StatefulWidget {
  const WasteUploadScreen({super.key});

  @override
  State<WasteUploadScreen> createState() => _WasteUploadScreenState();
}

class _WasteUploadScreenState extends State<WasteUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = WasteService();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _location = TextEditingController();

  final List<UploadPayload> _images = [];
  WasteCategory _category = WasteCategory.biodegradable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _location.text = user?.fullAddress == 'No address on file'
        ? ''
        : (user?.fullAddress ?? '');
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final location = context.read<LocationProvider>();
    final ok = await location.getCurrentLocation();
    if (!mounted) return;
    if (!ok || !location.hasLocation) {
      AppFeedback.error(
        context,
        location.error ?? 'Could not read your location.',
      );
      return;
    }
    setState(() {
      _location.text =
          '${location.latitude!.toStringAsFixed(5)}, '
          '${location.longitude!.toStringAsFixed(5)}';
    });
    AppFeedback.success(context, 'GPS coordinates added');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      AppFeedback.error(context, 'Add at least one photo of the waste.');
      return;
    }
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await _service.submit(
        userId: user.uid,
        userName: user.displayName ?? 'Resident',
        description: _description.text,
        category: _category,
        quantity: _quantity.text,
        location: _location.text,
        barangay: user.barangay,
        images: _images,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            size: 34,
            color: AppColors.primary,
          ),
          title: const Text('Waste submitted'),
          content: const Text(
            'Barangay staff will validate your waste photos. '
            'You will receive a notification once it is reviewed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('View my uploads'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/waste-history');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = _images.length >= 3;

    return EcoPageScaffold(
      eyebrow: 'RESIDENT · WASTE',
      title: 'Upload waste',
      subtitle: 'Send a photo so staff can validate and schedule the pickup.',
      onBack: () => ecoBack(context, '/user'),
      actions: [
        EcoIconAction(
          icon: Icons.history_rounded,
          tooltip: 'My uploads',
          onTap: () => context.push('/waste-history'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            const DeskSectionHeader(
              icon: Icons.photo_camera_outlined,
              title: 'Waste photos',
              subtitle:
                  'Up to 3 clear photos. Good light is the difference between '
                  'approved and sent back.',
            ),
            const SizedBox(height: EcoSpace.sm),
            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(EcoRadius.md),
                        child: Image.memory(
                          _bytes(_images[i].dataUrl),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 3,
                        top: 3,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EcoSpace.sm),
            ],
            if (full)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '3 photos attached. Remove one to swap it out.',
                        style: EcoType.bodySmall(
                          context,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ImagePickerField(
                value: null,
                label: _images.isEmpty ? 'Add a photo' : 'Add another photo',
                helper: 'JPG, PNG or WebP · camera or gallery',
                previewHeight: 120,
                onChanged: (value) {
                  if (value != null) setState(() => _images.add(value));
                },
              ),
            const SizedBox(height: EcoSpace.lg),
            const DeskSectionHeader(
              icon: Icons.category_outlined,
              title: 'Waste details',
              subtitle: 'The stream decides which truck takes it.',
            ),
            const SizedBox(height: EcoSpace.sm),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final category in WasteCategory.values)
                  DeskFilterChip(
                    label: category.shortLabel,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: EcoSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_category.icon, size: 14, color: _category.color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${_category.label} · ${_category.hint}',
                    style: EcoType.bodySmall(
                      context,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.md),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Estimated quantity',
                hintText: 'e.g. 2 sacks, 1 bin, 5 kg',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please estimate the quantity'
                  : null,
            ),
            const SizedBox(height: EcoSpace.md),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is the waste and where is it stored?',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().length < 5)
                  ? 'Please describe the waste'
                  : null,
            ),
            const SizedBox(height: EcoSpace.lg),
            const DeskSectionHeader(
              icon: Icons.place_outlined,
              title: 'Collection location',
              subtitle: 'Where should the collector pick this up?',
            ),
            const SizedBox(height: EcoSpace.sm),
            TextFormField(
              controller: _location,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Address or landmark',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please add the pickup location'
                  : null,
            ),
            const SizedBox(height: EcoSpace.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 15),
                label: Text(
                  'Use my current GPS location',
                  style: EcoType.label(context, color: AppColors.primary),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: EcoSpace.lg),
            PrimaryButton(
              label: 'Submit for validation',
              loading: _saving,
              onPressed: _submit,
            ),
            const SizedBox(height: EcoSpace.sm),
            Text(
              'The same photo cannot be uploaded twice. Staff may reject '
              'unclear or mis-segregated waste.',
              textAlign: TextAlign.center,
              style: EcoType.meta(context, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}

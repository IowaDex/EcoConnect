import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
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
          '${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}';
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
          icon: const Icon(Icons.check_circle_rounded,
              size: 34, color: AppColors.primary),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Upload waste',
              subtitle: 'Send a photo so staff can validate and schedule pickup.',
              onBack: () => context.go('/user'),
              actions: [
                IconButton(
                  onPressed: () => context.go('/waste-history'),
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'My uploads',
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'Waste photos',
                              subtitle:
                                  'Add up to 3 clear photos. Good lighting helps validation.',
                            ),
                            const SizedBox(height: 12),
                            if (_images.isNotEmpty) ...[
                              SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _images.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) => Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _bytes(_images[i].dataUrl),
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: 2,
                                        top: 2,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _images.removeAt(i),
                                          ),
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
                              const SizedBox(height: 10),
                            ],
                            if (_images.length < 3)
                              ImagePickerField(
                                value: null,
                                label: 'Add a photo',
                                helper: 'JPG, PNG or WebP · camera or gallery',
                                previewHeight: 120,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _images.add(value));
                                  }
                                },
                              )
                            else
                              const Text(
                                'Maximum of 3 photos reached.',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'Waste details'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<WasteCategory>(
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Waste category',
                              ),
                              items: [
                                for (final category in WasteCategory.values)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(category.label),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _category.hint,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _quantity,
                              decoration: const InputDecoration(
                                labelText: 'Estimated quantity',
                                hintText: 'e.g. 2 sacks, 1 bin, 5 kg',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please estimate the quantity'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _description,
                              minLines: 3,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText:
                                    'What is the waste and where is it stored?',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 5)
                                      ? 'Please describe the waste'
                                      : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'Collection location',
                              subtitle:
                                  'Where should the collector pick this up?',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _location,
                              minLines: 2,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Address or landmark',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please add the pickup location'
                                      : null,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 16),
                              label: const Text('Use my current GPS location'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit for validation'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Uploading the same photo twice is not allowed by validation. '
                        'Staff may reject unclear or mis-segregated waste.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/collection_request.dart';
import '../services/collection_request_service.dart';

/// Collection request form.
///
/// Every resident may ask for a standard or a special pickup: their ID was
/// checked by the barangay at sign-up. Firestore enforces the same rule (only
/// approved residents, never crews).
class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key, this.initialKind = RequestKind.resident});

  /// Wave 2: the resident is reporting garbage that was not collected. The
  /// report still goes to the barangay first for verification.
  /// Opened as an uncollected-garbage (wave 2) report from the resident home.
  final RequestKind initialKind;

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CollectionRequestService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _location = TextEditingController();
  final _remarks = TextEditingController();

  final List<UploadPayload> _images = [];
  WasteCategory _category = WasteCategory.recyclable;
  late RequestKind _kind = widget.initialKind;
  DateTime _preferred = DateTime.now().add(const Duration(days: 2));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _location.text = user?.fullAddress == 'No address on file'
        ? ''
        : (user?.fullAddress ?? '');
    if (_kind == RequestKind.uncollected) {
      _title.text = 'Uncollected garbage';
      _category = WasteCategory.residual;
      _preferred = DateTime.now();
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _quantity, _location, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _preferred,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_preferred),
    );
    if (time == null) return;
    setState(() {
      _preferred = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (_images.isEmpty) {
      AppFeedback.error(context, 'Add at least one photo of the waste.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Photos go up first, so the truck overlay explains the wait.
      await EcoLoadingOverlay.run(
        context,
        () => _service.create(
          requesterId: user.uid,
          requesterName: user.displayName ?? 'Resident',
          requesterPhone: user.phone,
          requesterBarangay: user.barangay,
          kind: _kind,
          title: _title.text,
          description: _description.text,
          category: _category,
          estimatedQuantity: _quantity.text,
          location: _location.text,
          preferredDate: _preferred,
          remarks: _remarks.text,
          images: _images,
        ),
        message: 'Sending your collection request',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.task_alt_rounded,
            size: 34,
            color: AppColors.primary,
          ),
          title: const Text('Request submitted'),
          content: Text(switch (_kind) {
            RequestKind.special =>
              'Barangay staff will review your special collection request and '
                  'assign a schedule.',
            RequestKind.uncollected =>
              'Barangay Batasan Hills will check your report and ask City Hall '
                  'for a second (wave 2) collection.',
            RequestKind.resident =>
              'Barangay staff will review your request. You will be notified '
                  'when it is approved or scheduled.',
          }),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('View my requests'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/my-requests');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canSpecial = user?.role == UserRole.user;
    final uncollected = _kind == RequestKind.uncollected;
    final full = _images.length >= 3;

    return EcoPageScaffold(
      eyebrow: uncollected
          ? 'RESIDENT · WAVE 2 REPORT'
          : 'RESIDENT · COLLECTION',
      title: uncollected
          ? 'Report uncollected garbage'
          : canSpecial
          ? 'Collection request'
          : 'Request a collection',
      subtitle: uncollected
          ? 'The barangay verifies the report before City Hall decides.'
          : canSpecial
          ? 'Standard or special pickup for government personnel.'
          : 'Tell the barangay what needs to be collected.',
      onBack: () => ecoBack(context, '/user'),
      actions: [
        EcoIconAction(
          icon: Icons.history_rounded,
          tooltip: 'My requests',
          onTap: () => context.push('/my-requests'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            if (uncollected) ...[
              const EcoBanner(
                message:
                    'This is a Wave 2 report. Barangay staff verify it, then '
                    'forward it to City Hall for a decision. You are notified '
                    'at every step.',
                icon: Icons.report_problem_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(height: EcoSpace.md),
            ],
            if (canSpecial) ...[
              DeskSegmented<RequestKind>(
                value: _kind,
                onChanged: (value) => setState(() => _kind = value),
                segments: const [
                  DeskSegment<RequestKind>(
                    value: RequestKind.resident,
                    label: 'Standard',
                    icon: Icons.home_outlined,
                  ),
                  DeskSegment<RequestKind>(
                    value: RequestKind.special,
                    label: 'Special',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
              const SizedBox(height: EcoSpace.xs + 2),
              Text(
                _kind == RequestKind.special
                    ? 'Government offices, schools and public facilities.'
                    : 'Household pickup on the regular route.',
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
              const SizedBox(height: EcoSpace.lg),
            ] else if (user?.isGovernment == true) ...[
              EcoBanner(
                message: user?.verificationStatus == VerificationStatus.rejected
                    ? 'Your government ID was rejected. Standard requests '
                          'still work while you resubmit your document.'
                    : 'Your government account is pending verification. '
                          'Special collection requests unlock once staff approve '
                          'your ID.',
                icon: Icons.badge_outlined,
                color: user?.verificationStatus == VerificationStatus.rejected
                    ? AppColors.error
                    : AppColors.warning,
              ),
              const SizedBox(height: EcoSpace.lg),
            ],
            if (_kind == RequestKind.special) ...[
              const EcoBanner(
                message:
                    'Include the office name and an authorised contact in the '
                    'description.',
                icon: Icons.info_outline_rounded,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(height: EcoSpace.lg),
            ],
            const DeskSectionHeader(
              icon: Icons.assignment_outlined,
              title: 'What to collect',
              subtitle: 'Clear details are approved faster.',
            ),
            const SizedBox(height: EcoSpace.sm),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Request title',
                hintText: 'e.g. Bulky waste pickup at the barangay hall',
              ),
              validator: (value) => (value == null || value.trim().length < 5)
                  ? 'Please add a short title'
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
                hintText:
                    'What needs to be collected and any access instructions',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please describe the request'
                  : null,
            ),
            const SizedBox(height: EcoSpace.md),
            Text(
              'WASTE CATEGORY',
              style: EcoType.eyebrow(context, color: AppColors.inkMuted),
            ),
            const SizedBox(height: EcoSpace.xs + 2),
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
            const SizedBox(height: EcoSpace.xs + 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_category.icon, size: 14, color: _category.color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _category.hint,
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.md),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Estimated quantity',
                hintText: 'e.g. 10 sacks, 2 truckloads',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please estimate the quantity'
                  : null,
            ),
            const SizedBox(height: EcoSpace.lg),
            const DeskSectionHeader(
              icon: Icons.place_outlined,
              title: 'Pickup',
              subtitle: 'Where and when the crew should come.',
            ),
            const SizedBox(height: EcoSpace.sm),
            TextFormField(
              controller: _location,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Collection location',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please add the collection location'
                  : null,
            ),
            const SizedBox(height: EcoSpace.sm),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(EcoRadius.md),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(EcoRadius.sm),
                      ),
                      child: const Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: EcoSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREFERRED DATE',
                            style: EcoType.eyebrow(
                              context,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateTimeLabel(_preferred),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EcoType.bodyStrong(
                              context,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: EcoSpace.md),
            TextFormField(
              controller: _remarks,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Additional remarks (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: EcoSpace.lg),
            const DeskSectionHeader(
              icon: Icons.photo_camera_outlined,
              title: 'Photos',
              subtitle: 'At least one photo is required for validation.',
            ),
            const SizedBox(height: EcoSpace.sm),
            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 88,
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
                          width: 88,
                          height: 88,
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
                              size: 12,
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
                helper: 'JPG, PNG or WebP',
                previewHeight: 110,
                onChanged: (value) {
                  if (value != null) setState(() => _images.add(value));
                },
              ),
            const SizedBox(height: EcoSpace.lg),
            PrimaryButton(
              label: _kind == RequestKind.special
                  ? 'Submit special request'
                  : 'Submit request',
              loading: _saving,
              onPressed: _submit,
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

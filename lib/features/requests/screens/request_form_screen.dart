import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/collection_request.dart';
import '../services/collection_request_service.dart';

/// Collection request form.
///
/// The special collection variant is only rendered for verified government
/// personnel. The same rule is enforced by Firestore, so a modified client
/// cannot submit a special request from a resident account.
class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

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
  RequestKind _kind = RequestKind.resident;
  DateTime _preferred = DateTime.now().add(const Duration(days: 2));
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
    if (_kind == RequestKind.special && !user.isVerifiedGovernment) {
      AppFeedback.error(
        context,
        'Special collection requests are only available to verified government personnel.',
      );
      return;
    }
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
          content: Text(
            _kind == RequestKind.special
                ? 'Barangay staff will review your special collection request and assign a schedule.'
                : 'Barangay staff will review your request. You will be notified when it is approved or scheduled.',
          ),
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
    final canSpecial = user?.isVerifiedGovernment ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: canSpecial ? 'Collection request' : 'Request a collection',
              subtitle: canSpecial
                  ? 'Standard or special pickup for government personnel.'
                  : 'Tell the barangay what needs to be collected.',
              onBack: () => context.go('/user'),
              actions: [
                IconButton(
                  onPressed: () => context.go('/my-requests'),
                  icon: const Icon(Icons.history_rounded),
                  tooltip: 'My requests',
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
                      if (canSpecial) ...[
                        _KindSelector(
                          kind: _kind,
                          onChanged: (value) => setState(() => _kind = value),
                        ),
                        const SizedBox(height: 14),
                      ] else if (user?.isGovernment == true) ...[
                        EcoBanner(
                          message:
                              user?.verificationStatus ==
                                  VerificationStatus.rejected
                              ? 'Your government ID was rejected. Standard requests still work while you resubmit your document.'
                              : 'Your government account is pending verification. Special collection requests unlock once staff approve your ID.',
                          icon: Icons.badge_outlined,
                          color:
                              user?.verificationStatus ==
                                  VerificationStatus.rejected
                              ? AppColors.error
                              : AppColors.warning,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_kind == RequestKind.special) ...[
                        const EcoBanner(
                          message:
                              'Special collection is for government offices, schools and public facilities. Include the office name and authorized contact in the description.',
                          icon: Icons.info_outline_rounded,
                          color: Color(0xFF1565C0),
                        ),
                        const SizedBox(height: 14),
                      ],
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'Request details',
                              subtitle:
                                  'Clear details help staff approve faster.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _title,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Request title',
                                hintText:
                                    'e.g. Bulky waste pickup at the barangay hall',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 5)
                                  ? 'Please add a short title'
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
                                    'What needs to be collected and any access instructions',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 10)
                                  ? 'Please describe the request'
                                  : null,
                            ),
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _quantity,
                              decoration: const InputDecoration(
                                labelText: 'Estimated quantity',
                                hintText: 'e.g. 10 sacks, 2 truckloads',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Please estimate the quantity'
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
                            const SectionHeader(title: 'Pickup'),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _location,
                              minLines: 2,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Collection location',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Please add the collection location'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.sage),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.event_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Preferred collection date',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                        Text(
                                          dateTimeLabel(_preferred),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.edit_calendar_outlined,
                                      size: 17,
                                      color: AppColors.inkMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'Photos',
                              subtitle:
                                  'At least one photo is required for validation.',
                            ),
                            const SizedBox(height: 12),
                            if (_images.isNotEmpty) ...[
                              SizedBox(
                                height: 88,
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
                                          width: 88,
                                          height: 88,
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
                              const SizedBox(height: 10),
                            ],
                            if (_images.length < 3)
                              ImagePickerField(
                                value: null,
                                label: 'Add a photo',
                                helper: 'JPG, PNG or WebP',
                                previewHeight: 110,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _images.add(value));
                                  }
                                },
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
                              : Text(
                                  _kind == RequestKind.special
                                      ? 'Submit special request'
                                      : 'Submit request',
                                ),
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

class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.kind, required this.onChanged});

  final RequestKind kind;
  final ValueChanged<RequestKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        children: [
          _option(
            context,
            kind: RequestKind.resident,
            label: 'Standard',
            icon: Icons.home_outlined,
            subtitle: 'Household pickup',
          ),
          _option(
            context,
            kind: RequestKind.special,
            label: 'Special',
            icon: Icons.badge_outlined,
            subtitle: 'Government',
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required RequestKind kind,
    required String label,
    required IconData icon,
    required String subtitle,
  }) {
    final active = this.kind == kind;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(kind),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.darkGreen,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 7.5,
                      color: active
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

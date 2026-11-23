import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

/// Resident → DSQC / City Hall. This is intentionally not a collection
/// request: no barangay approval step, no truck assignment.
class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();

  ComplaintCategory _category = ComplaintCategory.missedCollection;
  final List<UploadPayload?> _images = [null, null, null];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  /// Photo slots appear one at a time: a fresh form shows a single tile
  /// instead of three empty 110px boxes, and each photo you add reveals the
  /// next slot.
  int get _visibleSlots {
    final filled = _images.whereType<UploadPayload>().length;
    return (filled + 1).clamp(1, _images.length);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await ComplaintService().submit(
        residentId: user.uid,
        residentName: user.displayName ?? 'Resident',
        residentBarangay: user.barangay,
        title: _title.text,
        description: _description.text,
        category: _category,
        location: _location.text,
        images: _images.whereType<UploadPayload>().toList(growable: false),
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        'Complaint sent to City Hall. You can track it in My complaints.',
      );
      context.go('/my-complaints');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'RESIDENT · COMPLAINT',
      title: 'Complaint to DSQC',
      subtitle: 'Goes straight to City Hall. No barangay approval is needed.',
      onBack: () => ecoBack(context, '/user'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            const DeskSectionHeader(
              icon: Icons.report_outlined,
              title: 'What happened',
              subtitle: 'One line that names the problem, then the details.',
            ),
            const SizedBox(height: EcoSpace.sm),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Complaint title',
                hintText: 'e.g. Truck skipped our street for two weeks',
              ),
              validator: (value) => (value ?? '').trim().length < 5
                  ? 'Enter a short title'
                  : null,
            ),
            const SizedBox(height: EcoSpace.md),
            Text(
              'CATEGORY',
              style: EcoType.eyebrow(context, color: AppColors.inkMuted),
            ),
            const SizedBox(height: EcoSpace.xs + 2),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final category in ComplaintCategory.values)
                  DeskFilterChip(
                    label: category.label,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: EcoSpace.md),
            TextFormField(
              controller: _description,
              minLines: 5,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText:
                    'Include dates, times and any details that help DSQC act.',
                counterStyle: TextStyle(fontSize: 9),
              ),
              validator: (value) => (value ?? '').trim().length < 20
                  ? 'Please describe the complaint (at least 20 characters)'
                  : null,
            ),
            const SizedBox(height: EcoSpace.xs),
            const DeskSectionHeader(
              icon: Icons.place_outlined,
              title: 'Where',
              subtitle:
                  'Street, block or landmark. Optional, but it speeds '
                  'the check up.',
            ),
            const SizedBox(height: EcoSpace.sm),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'Street, barangay or landmark',
              ),
            ),
            const SizedBox(height: EcoSpace.lg),
            const DeskSectionHeader(
              icon: Icons.add_photo_alternate_outlined,
              title: 'Evidence',
              subtitle:
                  'Optional, up to 3 photos. A shot of the pile or the '
                  'bin says more than a paragraph.',
            ),
            const SizedBox(height: EcoSpace.sm),
            for (var i = 0; i < _visibleSlots; i++) ...[
              ImagePickerField(
                value: _images[i],
                onChanged: (value) => setState(() => _images[i] = value),
                label: 'Photo ${i + 1} of 3',
                previewHeight: 120,
              ),
              const SizedBox(height: EcoSpace.sm),
            ],
            const SizedBox(height: EcoSpace.xs),
            const _RoutingNote(),
            const SizedBox(height: EcoSpace.lg),
            PrimaryButton(
              label: 'Submit complaint',
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// One line about where the complaint lands, so a resident does not wait on
/// a barangay approval that never happens.
class _RoutingNote extends StatelessWidget {
  const _RoutingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.alt_route_rounded,
              size: 15,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'City Hall reads this directly and replies on the same thread. '
              'Track the answer in My complaints.',
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

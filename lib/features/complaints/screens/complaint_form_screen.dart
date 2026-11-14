import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/image_picker_field.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.canPop() ? context.pop() : context.go('/user'),
        ),
        title: const Text(
          'Complaint to DSQC',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            const Text(
              'This goes directly to DSQC / City Hall. It is not a collection '
              'request and does not wait for barangay approval.',
              style: TextStyle(
                fontSize: 10,
                height: 1.55,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 14),
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final category in ComplaintCategory.values)
                  ChoiceChip(
                    label: Text(
                      category.label,
                      style: const TextStyle(fontSize: 9.5),
                    ),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Include dates, times and any details that help DSQC act.',
                counterStyle: TextStyle(fontSize: 9),
              ),
              validator: (value) => (value ?? '').trim().length < 20
                  ? 'Please describe the complaint (at least 20 characters)'
                  : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'Street, barangay or landmark',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Evidence (optional, up to 3 photos)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _images.length; i++) ...[
              ImagePickerField(
                value: _images[i],
                onChanged: (value) => setState(() => _images[i] = value),
                label: 'Photo ${i + 1}',
                previewHeight: 110,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 17),
                label: const Text(
                  'Submit complaint',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

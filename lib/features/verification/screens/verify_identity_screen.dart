import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/verification_request.dart';
import '../services/verification_service.dart';

/// Lets a signed-in resident upload or replace the ID the barangay checks.
///
/// The sign-up form already asks for an ID, but a resident may need to
/// resubmit after a rejection or replace an unreadable photo. The document is
/// stored in `verificationRequests/{uid}`, so the barangay desk reviews the
/// same record it saw at registration.
class VerifyIdentityScreen extends StatefulWidget {
  const VerifyIdentityScreen({super.key});

  @override
  State<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends State<VerifyIdentityScreen> {
  final _service = VerificationService();
  UploadPayload? _document;
  bool _busy = false;

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().currentUser;
    final document = _document;
    if (user == null) return;
    if (document == null) {
      AppFeedback.error(context, 'Choose a photo of your ID first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.submitId(
        userId: user.uid,
        name: user.displayName ?? 'Resident',
        email: user.email ?? '',
        phone: user.phone,
        barangay: user.barangay,
        document: document,
      );
      if (!mounted) return;
      setState(() => _document = null);
      // The profile now says 'pending'; carry that to the dashboard behind.
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      AppFeedback.success(
        context,
        'ID submitted. Barangay staff will review it shortly.',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Verify my identity',
              subtitle:
                  'Upload a clear photo of your barangay ID or proof of '
                  'residence. Only you and barangay staff can see it.',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/user'),
            ),
            Expanded(
              child: StreamBuilder<VerificationRequest?>(
                stream: _service.watchMine(user.uid),
                builder: (context, snapshot) {
                  final request = snapshot.data;
                  final status =
                      request?.status ??
                      VerificationStatusX.fromName(
                        user.verificationStatus.name,
                      );
                  final rejected = status == VerificationStatus.rejected;
                  final verified = status == VerificationStatus.verified;
                  final canUpload = !verified;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                    children: [
                      EcoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 38,
                                  width: 38,
                                  decoration: BoxDecoration(
                                    color: status.color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    status.icon,
                                    size: 18,
                                    color: status.color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Verification status',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      StatusBadge(
                                        label: status.label,
                                        color: status.color,
                                        icon: status.icon,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              verified
                                  ? 'Your ID is verified. Barangay services '
                                        'that need a checked identity are open.'
                                  : rejected
                                  ? (request?.rejectionReason
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? 'Barangay staff could not accept '
                                              'your last ID: '
                                              '${request!.rejectionReason}'
                                        : 'Barangay staff could not accept '
                                              'your last ID. Upload a clearer '
                                              'photo.')
                                  : request == null
                                  ? 'No ID is on file yet. Upload one '
                                        'so the barangay can verify you.'
                                  : 'Your ID is waiting for barangay '
                                        'review. You can replace it with '
                                        'a clearer photo if needed.',
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.55,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canUpload) ...[
                        const SizedBox(height: 18),
                        const SectionLabel('UPLOAD YOUR ID'),
                        const SizedBox(height: 8),
                        ImagePickerField(
                          value: _document,
                          onChanged: (value) =>
                              setState(() => _document = value),
                          label: 'Barangay ID or proof of residence',
                          helper:
                              'JPG, PNG or PDF · name and Batasan Hills '
                              'address must be readable',
                          documentMode: true,
                          previewHeight: 170,
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: request == null
                              ? 'Submit ID for review'
                              : 'Replace my ID',
                          loading: _busy,
                          onPressed: _submit,
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Barangay staff check the name and address on the ID. '
                        'If it is rejected, you can upload another photo here '
                        'without making a new account.',
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.55,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
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

    return EcoPageScaffold(
      eyebrow: 'RESIDENT · IDENTITY',
      title: 'Verify my identity',
      subtitle: 'Only you and barangay staff can see the ID you upload here.',
      onBack: () => ecoBack(context, '/user'),
      body: StreamBuilder<VerificationRequest?>(
        stream: _service.watchMine(user.uid),
        builder: (context, snapshot) {
          final request = snapshot.data;
          final status =
              request?.status ??
              VerificationStatusX.fromName(user.verificationStatus.name);
          final rejected = status == VerificationStatus.rejected;
          final verified = status == VerificationStatus.verified;
          final canUpload = !verified;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _StatusPanel(
                status: status,
                message: _messageFor(status, request),
                submittedAt: request?.submittedAt,
              ),
              if (canUpload) ...[
                const SizedBox(height: EcoSpace.lg),
                const DeskSectionHeader(
                  icon: Icons.upload_file_rounded,
                  title: 'Upload your ID',
                  subtitle:
                      'JPG, PNG or PDF. The name and the Batasan Hills '
                      'address must be readable.',
                ),
                const SizedBox(height: EcoSpace.sm),
                ImagePickerField(
                  value: _document,
                  onChanged: (value) => setState(() => _document = value),
                  label: 'Barangay ID or proof of residence',
                  helper:
                      'A flat, well-lit photo works best. Blurred corners are '
                      'the usual reason an ID is sent back.',
                  documentMode: true,
                  previewHeight: 170,
                ),
                const SizedBox(height: EcoSpace.md),
                PrimaryButton(
                  label: request == null
                      ? 'Submit ID for review'
                      : 'Replace my ID',
                  loading: _busy,
                  onPressed: _submit,
                ),
              ],
              const SizedBox(height: EcoSpace.lg),
              const _DeskChecks(),
              if (rejected) ...[
                const SizedBox(height: EcoSpace.md),
                _RejectionNote(reason: request?.rejectionReason?.trim() ?? ''),
              ],
            ],
          );
        },
      ),
    );
  }

  String _messageFor(VerificationStatus status, VerificationRequest? request) {
    switch (status) {
      case VerificationStatus.verified:
        return 'Your ID is verified. Every barangay service that needs a '
            'checked identity is open to you.';
      case VerificationStatus.rejected:
        final reason = request?.rejectionReason?.trim() ?? '';
        return reason.isEmpty
            ? 'Barangay staff could not accept your last ID. Upload a clearer '
                  'photo and send it again.'
            : 'Barangay staff could not accept your last ID: $reason';
      case VerificationStatus.pending:
        return request == null
            ? 'Your ID is waiting for barangay review.'
            : 'Your ID is waiting for barangay review. You can still replace '
                  'it with a clearer photo.';
      case VerificationStatus.unverified:
        return 'No ID is on file yet. Upload one so the barangay can verify '
            'you and unlock the rest of the app.';
    }
  }
}

/// The status card: colour rail, mark, badge and the one line that explains
/// what the resident should do next.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.message,
    this.submittedAt,
  });

  final VerificationStatus status;
  final String message;
  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: status.color,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
                  borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
                ),
                child: Icon(status.icon, size: 18, color: status.color),
              ),
              const SizedBox(width: EcoSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERIFICATION STATUS',
                      style: EcoType.eyebrow(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
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
          const SizedBox(height: EcoSpace.md),
          Text(
            message,
            style: EcoType.body(context, color: AppColors.textDark),
          ),
          if (submittedAt != null) ...[
            const SizedBox(height: EcoSpace.sm),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Submitted ${dateLabel(submittedAt!)}',
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What the desk actually looks at, so a rejection never feels arbitrary.
class _DeskChecks extends StatelessWidget {
  const _DeskChecks();

  static const _lines = [
    'The name on the ID matches your account name.',
    'The address falls inside Barangay Batasan Hills.',
    'The photo is sharp enough to read both.',
  ];

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT THE DESK CHECKS',
            style: EcoType.eyebrow(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: EcoSpace.sm),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _lines.length - 1 ? 0 : 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lines[i],
                      style: EcoType.bodyStrong(
                        context,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A rejection with a stated reason gets its own tinted panel, because it is
/// the one line the resident has to act on.
class _RejectionNote extends StatelessWidget {
  const _RejectionNote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_bad_outlined, size: 15, color: AppColors.error),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              reason.isEmpty
                  ? 'No reason was recorded. Upload a clearer photo and the '
                        'desk will review it again.'
                  : 'Desk note: $reason',
              style: EcoType.bodySmall(context, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

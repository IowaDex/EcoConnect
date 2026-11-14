import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../verification/services/verification_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// User validation desk: pending driver/staff accounts, government ID
/// submissions and the resident directory.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Resident validation',
              subtitle:
                  'Check each resident’s ID before they unlock barangay '
                  'services. Drivers and staff are created by City Hall.',
              onBack: () => context.go('/admin-dashboard'),
              actions: const [NotificationBell()],
            ),
            const SizedBox(height: 6),
            const Expanded(child: _ResidentsTab()),
          ],
        ),
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.document});

  final UploadPayload document;

  @override
  Widget build(BuildContext context) {
    final isPdf = document.isPdf;
    if (isPdf) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 26, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                document.fileName,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _bytes(document.dataUrl),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

enum _ResidentAction {
  viewId,
  approveRegistration,
  rejectRegistration,
  verify,
  reject,
  reset,
}

String _registrationLabel(String status) => switch (status) {
      'pending' => 'Registration pending',
      'approved' => 'Awaiting resident',
      'declined' => 'Resident declined',
      'rejected' => 'Registration rejected',
      _ => 'Registration accepted',
    };

Color _registrationColor(String status) => switch (status) {
      'pending' => AppColors.warning,
      'approved' => const Color(0xFF1565C0),
      'declined' => AppColors.error,
      'rejected' => AppColors.error,
      _ => AppColors.primary,
    };

class _ResidentsTab extends StatefulWidget {
  const _ResidentsTab();

  @override
  State<_ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<_ResidentsTab> {
  final _service = VerificationService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final users = await context.read<AuthProvider>().getAllUsers();
    return users.where((u) => (u['role'] ?? 'user') == 'user').toList();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  /// Shows the ID the resident uploaded at sign-up.
  Future<void> _viewId(Map<String, dynamic> user) async {
    final request = await _service.fetchForUser(user['uid'] as String);
    if (!mounted) return;
    final document = request?.document;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ID · ${(user['name'] as String?) ?? 'Resident'}'),
        content: document == null
            ? const Text('This resident has not uploaded an ID.')
            : _DocumentPreview(document: document),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _set(
    Map<String, dynamic> user,
    VerificationStatus status,
  ) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    final openRegistration =
        ((user['registrationStatus'] as String?) ?? 'accepted') == 'pending';
    String? reason;
    if (status == VerificationStatus.rejected) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject account?'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain what needs to be corrected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = controller.text.trim();
    }
    try {
      await _service.setUserVerification(
        userId: user['uid'] as String,
        status: status,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: reason,
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        status == VerificationStatus.verified && openRegistration
            ? 'Registration approved — the resident can now sign in'
            : 'Verification updated',
      );
      _reload();
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: 'Loading residents');
        }
        if (snapshot.hasError) {
          return ErrorView(message: AppFeedback.describe(snapshot.error!));
        }
        final residents = snapshot.data ?? const [];
        if (residents.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No residents yet',
            message: 'Registered residents appear here for validation.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          itemCount: residents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final user = residents[i];
            final status = VerificationStatusX.fromName(
              user['verificationStatus'] as String?,
            );
            final accountType = AccountTypeX.fromName(
              user['accountType'] as String?,
            );
            final registration =
                (user['registrationStatus'] as String?) ?? 'accepted';
            // A new sign-up must confirm its email before the barangay can
            // approve it.
            final awaitingEmail = user['accountStatus'] == 'pending' &&
                user['emailVerified'] != true;
            return EcoCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.lightGreen,
                    child: Text(
                      ((user['name'] as String?) ?? 'R')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user['name'] as String?) ?? 'Resident',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${accountType.shortLabel} · ${(user['barangay'] as String?) ?? 'No barangay'}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StatusBadge(
                              label: status.label,
                              color: status.color,
                              icon: status.icon,
                              compact: true,
                            ),
                            StatusBadge(
                              label: _registrationLabel(registration),
                              color: _registrationColor(registration),
                              compact: true,
                            ),
                            if (awaitingEmail)
                              const StatusBadge(
                                label: 'Email not verified',
                                color: AppColors.warning,
                                compact: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_ResidentAction>(
                    icon: const Icon(Icons.more_vert_rounded,
                        size: 18, color: AppColors.inkMuted),
                    onSelected: (value) => switch (value) {
                      _ResidentAction.viewId => _viewId(user),
                      _ResidentAction.approveRegistration =>
                        _set(user, VerificationStatus.verified),
                      _ResidentAction.rejectRegistration =>
                        _set(user, VerificationStatus.rejected),
                      _ResidentAction.verify =>
                        _set(user, VerificationStatus.verified),
                      _ResidentAction.reject => _set(user, VerificationStatus.rejected),
                      _ResidentAction.reset =>
                        _set(user, VerificationStatus.unverified),
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _ResidentAction.viewId,
                        child: Text('View ID'),
                      ),
                      if (registration == 'pending' && !awaitingEmail) ...[
                        const PopupMenuItem(
                          value: _ResidentAction.approveRegistration,
                          child: Text('Approve registration'),
                        ),
                        const PopupMenuItem(
                          value: _ResidentAction.rejectRegistration,
                          child: Text('Reject registration'),
                        ),
                      ] else ...[
                        const PopupMenuItem(
                          value: _ResidentAction.verify,
                          child: Text('Mark verified'),
                        ),
                        const PopupMenuItem(
                          value: _ResidentAction.reject,
                          child: Text('Reject'),
                        ),
                        const PopupMenuItem(
                          value: _ResidentAction.reset,
                          child: Text('Reset to unverified'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}

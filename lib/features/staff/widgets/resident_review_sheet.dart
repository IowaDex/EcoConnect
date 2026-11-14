import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../verification/services/verification_service.dart';

/// Opens the resident's details and ID. Returns true once a decision was
/// saved, so the caller can refresh its list.
Future<bool> showResidentReview(
  BuildContext context,
  Map<String, dynamic> account,
) async {
  final decided = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.creamBright,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ResidentReviewSheet(
      account: account,
      verification: VerificationService(),
    ),
  );
  return decided == true;
}

/// Everything the resident entered, their ID, and the barangay's decision.
/// Pops `true` once a decision is saved.
class ResidentReviewSheet extends StatefulWidget {
  const ResidentReviewSheet({
    required this.account,
    required this.verification,
  });

  final Map<String, dynamic> account;
  final VerificationService verification;

  @override
  State<ResidentReviewSheet> createState() => _ResidentReviewSheetState();
}

class _ResidentReviewSheetState extends State<ResidentReviewSheet> {
  late final Future<String?> _idDataUrl = widget.verification
      .fetchForUser(widget.account['uid'] as String)
      .then((request) => request?.document?.dataUrl);
  bool _busy = false;

  Map<String, dynamic> get _a => widget.account;

  Future<void> _decide({required bool approve}) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await widget.verification.setUserVerification(
        userId: _a['uid'] as String,
        status:
            approve ? VerificationStatus.verified : VerificationStatus.rejected,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: reason,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final name = _a['name'] ?? 'Resident';
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
        content: Text(approve
            ? '$name approved. They can now sign in.'
            : '$name rejected.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save the decision: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  /// The reason shown to the resident at login, or null when cancelled.
  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this registration?'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to the resident)',
            hintText: 'e.g. The ID is unreadable / not a Batasan Hills address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (ok != true) return null;
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Give the resident a reason.'),
          backgroundColor: AppColors.danger,
        ));
      }
      return null;
    }
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final emailConfirmed = _a['emailVerified'] == true;
    final isPending = _a['accountStatus'] == 'pending';
    // Only a new, still-pending sign-up waits for the email confirmation.
    final canApprove = emailConfirmed || !isPending;
    final address = [
      _a['houseStreet'],
      _a['barangay'],
      _a['city'],
      _a['province'],
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (_a['name'] as String?) ?? 'Unnamed resident',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isPending ? 'Resident sign-up · waiting for approval' : 'Resident',
            style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Email', value: _a['email']),
          _InfoRow(
            label: 'Email confirmed',
            value: emailConfirmed ? 'Yes' : 'Not yet',
            valueColor: emailConfirmed ? AppColors.primary : AppColors.warning,
          ),
          _InfoRow(label: 'Phone', value: _a['phone']),
          _InfoRow(label: 'Age', value: _a['age']?.toString()),
          _InfoRow(
            label: 'Address',
            value: address.isEmpty ? null : address,
          ),
          _InfoRow(label: 'Signed up', value: _formatDate(_a['createdAt'])),
          const SizedBox(height: 18),
          const Text(
            'Valid ID',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<String?>(
            future: _idDataUrl,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _IdMessage(
                    'Could not load the ID: ${snapshot.error}');
              }
              final dataUrl = snapshot.data;
              if (dataUrl == null) {
                return const _IdMessage(
                    'This resident did not upload an ID.');
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints(maxHeight: 360),
                  width: double.infinity,
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.memory(
                      _bytes(dataUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _IdMessage(
                          'The ID file could not be shown.'),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Pinch to zoom. Check the name and that the address is in '
            'Batasan Hills.',
            style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 22),
          if (!canApprove)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'You can approve once the resident confirms their email.',
                style: TextStyle(fontSize: 10, color: AppColors.warning),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: (_busy || !canApprove)
                      ? null
                      : () => _decide(approve: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.valueColor});

  final String label;
  final Object? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              (text == null || text.isEmpty) ? '—' : text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdMessage extends StatelessWidget {
  const _IdMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
      ),
    );
  }
}

String? _formatDate(Object? raw) {
  if (raw is! Timestamp) return null;
  final d = raw.toDate().toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour:$minute '
      '${d.hour < 12 ? 'AM' : 'PM'}';
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../verification/services/verification_service.dart';

/// Resident sign-ups waiting for the barangay. Tapping one shows everything
/// the resident entered and their ID, with Approve / Reject.
///
/// Only residents appear here: drivers, guides and staff are created by City
/// Hall, already active.
class PendingAccountsScreen extends StatefulWidget {
  const PendingAccountsScreen({super.key});

  @override
  State<PendingAccountsScreen> createState() => _PendingAccountsScreenState();
}

class _PendingAccountsScreenState extends State<PendingAccountsScreen> {
  final _verification = VerificationService();
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final all = await context.read<AuthProvider>().getPendingAccounts();
    return all
        .where((a) => ((a['role'] as String?) ?? 'user') == 'user')
        .toList(growable: false);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openDetails(Map<String, dynamic> account) async {
    final decided = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamBright,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ResidentReviewSheet(
        account: account,
        verification: _verification,
      ),
    );
    if (decided == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.forest),
                    onPressed: () => context.go('/admin-dashboard'),
                  ),
                  const SizedBox(width: 10),
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.refresh_rounded,
                        size: 18, color: AppColors.inkMuted),
                    onPressed: _reload,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: Text(
                'Resident sign-ups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 14),
              child: Text(
                'New residents cannot sign in until you check their ID and '
                'approve them. Tap a resident to see their details and ID.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const EcoLoadingView(label: 'Loading sign-ups');
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load sign-ups: ${snapshot.error}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkMuted),
                      ),
                    );
                  }
                  final accounts = snapshot.data ?? const [];
                  if (accounts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No resident is waiting for approval.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.inkMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ResidentCard(
                      account: accounts[i],
                      onTap: () => _openDetails(accounts[i]),
                    ),
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

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.account, required this.onTap});

  final Map<String, dynamic> account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emailConfirmed = account['emailVerified'] == true;
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.lightGreen,
                child: Text(
                  _initial(account['name']),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (account['name'] as String?) ?? 'Unnamed resident',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (account['email'] as String?) ?? '',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emailConfirmed
                          ? 'Email confirmed · ready for review'
                          : 'Waiting for the resident to confirm their email',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: emailConfirmed
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything the resident entered, their ID, and the barangay's decision.
/// Pops `true` once a decision is saved.
class _ResidentReviewSheet extends StatefulWidget {
  const _ResidentReviewSheet({
    required this.account,
    required this.verification,
  });

  final Map<String, dynamic> account;
  final VerificationService verification;

  @override
  State<_ResidentReviewSheet> createState() => _ResidentReviewSheetState();
}

class _ResidentReviewSheetState extends State<_ResidentReviewSheet> {
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
          const Text(
            'Resident sign-up',
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
          if (!emailConfirmed)
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
                  onPressed: (_busy || !emailConfirmed)
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

String _initial(Object? name) {
  final text = (name as String?)?.trim() ?? '';
  return text.isEmpty ? 'R' : text.substring(0, 1).toUpperCase();
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

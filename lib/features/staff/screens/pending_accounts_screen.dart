import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../auth/models/account_type.dart';
import '../../verification/services/verification_service.dart';

class PendingAccountsScreen extends StatefulWidget {
  const PendingAccountsScreen({super.key});

  @override
  State<PendingAccountsScreen> createState() => _PendingAccountsScreenState();
}

class _PendingAccountsScreenState extends State<PendingAccountsScreen> {
  AuthProvider get _auth => context.read<AuthProvider>();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _auth.getPendingAccounts();
  }

  void _reload() {
    setState(() => _future = _auth.getPendingAccounts());
  }

  final _verification = VerificationService();

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : null,
        ),
      );
  }

  /// A resident sign-up: approving checks their ID and lets them sign in;
  /// rejecting keeps them out and shows the reason at login. The same decision
  /// as Verification -> Residents.
  Future<void> _reviewResident(
    Map<String, dynamic> account, {
    required bool approve,
  }) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject this registration?'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
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
      if (ok != true) return;
      reason = controller.text.trim();
      if (reason.isEmpty) {
        _snack('Give the resident a reason.', error: true);
        return;
      }
    }
    try {
      await _verification.setUserVerification(
        userId: account['uid'] as String,
        status:
            approve ? VerificationStatus.verified : VerificationStatus.rejected,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: reason,
      );
      if (!mounted) return;
      final name = account['name'] ?? 'Resident';
      _snack(approve
          ? '$name approved. They can now sign in.'
          : '$name rejected.');
      _reload();
    } catch (e) {
      if (mounted) _snack('Could not save the decision: $e', error: true);
    }
  }

  Future<void> _viewId(Map<String, dynamic> account) async {
    final request = await _verification.fetchForUser(account['uid'] as String);
    if (!mounted) return;
    final dataUrl = request?.document?.dataUrl;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ID · ${account['name'] ?? 'Resident'}'),
        content: dataUrl == null
            ? const Text('This resident has not uploaded an ID.')
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_bytes(dataUrl), fit: BoxFit.contain),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Uint8List _bytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return Uint8List(0);
    return base64Decode(dataUrl.substring(comma + 1));
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    await _auth.approveAccount(account['uid'] as String);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${account['name'] ?? 'Account'} approved'),
        ),
      );
    _reload();
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
                'Pending accounts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 14),
              child: Text(
                'New residents, drivers and staff cannot sign in until '
                'you approve them. Check each resident ID first.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const EcoLoadingView(label: 'Loading accounts');
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load accounts: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.danger),
                        ),
                      ),
                    );
                  }
                  final accounts = snapshot.data ?? const [];
                  if (accounts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nothing to approve right now.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.inkMuted),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final account = accounts[i];
                      final role = (account['role'] as String?) ?? 'driver';
                      final isResident = role == 'user';
                      // Residents confirm their email before the
                      // barangay can approve them.
                      final emailConfirmed =
                          account['emailVerified'] == true;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.sage.withValues(alpha: 0.8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (account['name'] as String?) ?? 'Unnamed account',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${(account['email'] as String?) ?? ''} · '
                              '${isResident ? 'Resident' : role == 'admin' ? 'Barangay staff' : 'Driver'}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.inkMuted),
                            ),
                            const SizedBox(height: 12),
                            if (isResident) ...[
                              if (!emailConfirmed)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Waiting for the resident to confirm their '
                                    'email before you can approve.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _viewId(account),
                                      icon: const Icon(Icons.badge_outlined,
                                          size: 16),
                                      label: const Text('View ID'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _reviewResident(account,
                                          approve: false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: emailConfirmed
                                          ? () => _reviewResident(account,
                                              approve: true)
                                          : null,
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: FilledButton(
                                  onPressed: () => _approve(account),
                                  child: const Text('Approve'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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

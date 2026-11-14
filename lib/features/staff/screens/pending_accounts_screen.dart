import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/resident_review_sheet.dart';

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
  late Stream<List<Map<String, dynamic>>> _stream = _watch();

  Stream<List<Map<String, dynamic>>> _watch() {
    return context.read<AuthProvider>().watchPendingAccounts().map(
      (all) => all
          .where((a) => ((a['role'] as String?) ?? 'user') == 'user')
          .toList(growable: false),
    );
  }

  void _reload() => setState(() => _stream = _watch());

  Future<void> _openDetails(Map<String, dynamic> account) async {
    if (await showResidentReview(context, account) && mounted) _reload();
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
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _stream,
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

String _initial(Object? name) {
  final text = (name as String?)?.trim() ?? '';
  return text.isEmpty ? 'R' : text.substring(0, 1).toUpperCase();
}

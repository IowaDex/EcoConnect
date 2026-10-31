import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';

class PendingAccountsScreen extends StatefulWidget {
  const PendingAccountsScreen({super.key});

  @override
  State<PendingAccountsScreen> createState() => _PendingAccountsScreenState();
}

class _PendingAccountsScreenState extends State<PendingAccountsScreen> {
  final _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _authService.getPendingAccounts();
  }

  void _reload() {
    setState(() => _future = _authService.getPendingAccounts());
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    await _authService.approveAccount(account['uid'] as String);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(((account['name'] ?? 'Account') as String) + ' approved'),
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
                'Drivers and staff cannot sign in until you approve them.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load accounts: ' + snapshot.error.toString(),
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
                              ((account['email'] as String?) ?? '') +
                                  ' · ' +
                                  (role == 'admin' ? 'Barangay staff' : 'Driver'),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.inkMuted),
                            ),
                            const SizedBox(height: 12),
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

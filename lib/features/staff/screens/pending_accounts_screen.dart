import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_loading.dart';

class PendingAccountsScreen extends StatefulWidget {
  const PendingAccountsScreen({super.key});

  @override
  State<PendingAccountsScreen> createState() => _PendingAccountsScreenState();
}

class _PendingAccountsScreenState extends State<PendingAccountsScreen> {
  AuthProvider get _auth => context.read<AuthProvider>();
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  String _query = '';
  String _role = 'all';
  int _page = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _future = _auth.getPendingAccounts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _auth.getPendingAccounts());
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    await _auth.approveAccount(account['uid'] as String);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${account['name'] ?? 'Account'} approved')),
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
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppColors.forest,
                    ),
                    onPressed: () => context.go('/admin-dashboard'),
                  ),
                  const SizedBox(width: 10),
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
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
                            fontSize: 11,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    );
                  }
                  final all = snapshot.data ?? const <Map<String, dynamic>>[];
                  final query = _query.trim().toLowerCase();
                  final accounts = all
                      .where((account) {
                        final role = (account['role'] as String?) ?? 'driver';
                        if (_role != 'all' && role != _role) return false;
                        if (query.isEmpty) return true;
                        final name = ((account['name'] as String?) ?? '')
                            .toLowerCase();
                        final email = ((account['email'] as String?) ?? '')
                            .toLowerCase();
                        return name.contains(query) || email.contains(query);
                      })
                      .toList(growable: false);
                  final page = clampPage(_page, accounts.length, _pageSize);
                  final visible = pageSlice(accounts, page, _pageSize);
                  if (all.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nothing to approve right now.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        child: EcoSearchField(
                          controller: _search,
                          hint: 'Search name or email',
                          onChanged: (value) => setState(() {
                            _query = value;
                            _page = 0;
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                        child: Wrap(
                          spacing: 7,
                          children: [
                            for (final option in const [
                              ('all', 'All'),
                              ('driver', 'Drivers'),
                              ('admin', 'Barangay staff'),
                            ])
                              FilterChip(
                                label: Text(option.$2),
                                selected: _role == option.$1,
                                onSelected: (_) => setState(() {
                                  _role = option.$1;
                                  _page = 0;
                                }),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: accounts.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No accounts match this search.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  8,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final account = visible[i];
                                  final role =
                                      (account['role'] as String?) ?? 'driver';
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.cream,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.sage.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (account['name'] as String?) ??
                                              'Unnamed account',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${(account['email'] as String?) ?? ''} · '
                                          '${role == 'admin' ? 'Barangay staff' : 'Driver'}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.inkMuted,
                                          ),
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
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                        child: EcoPaginationBar(
                          page: page,
                          pageSize: _pageSize,
                          total: accounts.length,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          onPageSizeChanged: (value) => setState(() {
                            _pageSize = value;
                            _page = 0;
                          }),
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

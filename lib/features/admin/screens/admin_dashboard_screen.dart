import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/collection_route.dart';
import '../../../core/models/incident.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/incident_service.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _incidentService = IncidentService();
  final _routeService = RouteService();
  final _authService = AuthService();

  late final Stream<List<Incident>> _incidentStream;
  late final Stream<CollectionRoute?> _routeStream;
  late Future<List<Map<String, dynamic>>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _incidentStream = _incidentService.watchAll();
    _routeStream = _routeService.watchActiveRoute();
    _pendingFuture = _authService.getPendingAccounts();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Barangay staff',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.displayName ?? 'Staff',
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<Incident>>(
                stream: _incidentStream,
                builder: (context, snapshot) {
                  final pending = (snapshot.data ?? const <Incident>[])
                      .where((i) => i.status == IncidentStatus.pending)
                      .length;
                  return _ActionTile(
                    icon: Icons.report_outlined,
                    title: 'Incident desk',
                    subtitle: snapshot.hasData
                        ? pending.toString() +
                            (pending == 1 ? ' report needs review' : ' reports need review')
                        : 'Loading reports…',
                    accent: pending > 0,
                    onTap: () => context.go('/incidents'),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _ActionTile(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Pending accounts',
                    subtitle: snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading accounts…'
                        : count.toString() +
                            (count == 1 ? ' account awaiting approval' : ' accounts awaiting approval'),
                    accent: count > 0,
                    onTap: () => context.go('/pending-accounts'),
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<CollectionRoute?>(
                stream: _routeStream,
                builder: (context, snapshot) {
                  final route = snapshot.data;
                  return _ActionTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Live routes',
                    subtitle: route != null
                        ? '${route.driverName} · '
                            '${route.isStale ? 'signal lost' : route.status.label}'
                        : 'No driver is collecting right now',
                    accent: route != null,
                    onTap: () => context.go('/tracking'),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.route_outlined,
                title: 'Route assignments',
                subtitle: 'Assign today’s collection runs to drivers',
                onTap: () => context.go('/routes'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.recycling_outlined,
                title: 'Recycling drop-off',
                subtitle: 'Weigh recyclables and credit resident points',
                onTap: () => context.go('/dropoff'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Manage users',
                subtitle: 'Roles, accounts and access',
                onTap: () => context.go('/admin'),
              ),
              const SizedBox(height: 22),
              const _RoadmapCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent ? AppColors.mint : AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent ? AppColors.forest : AppColors.sage.withValues(alpha: 0.8),
            width: accent ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: accent ? AppColors.forest : AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 19,
                color: accent ? Colors.white : AppColors.forest,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.moss),
          ],
        ),
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next up',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Zone & schedule assignment, recycling drop-off points and campaign '
            'management are not wired to Firestore yet.',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.5,
              color: AppColors.forest.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

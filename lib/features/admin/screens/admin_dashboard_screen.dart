import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../core/widgets/motion.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AuthProvider get _auth => context.read<AuthProvider>();

  late Future<List<Map<String, dynamic>>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _auth.getPendingRegistrations();
  }

  Future<void> _logout() async {
    if (!await confirmLogout(context) || !mounted) return;
    final authProvider = context.read<AuthProvider>();
    // Delete the shared pin while still signed in; rules reject it afterwards.
    await context.read<LocationProvider>().endSession();
    await authProvider.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              name: user?.displayName ?? 'Staff',
              pendingFuture: _pendingFuture,
              onLogout: _logout,
              onReview: () => context.go('/verification'),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.paddingOf(context).bottom + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel('NEEDS ATTENTION'),
                  const SizedBox(height: 12),
                  // The approval queue already sits in the hero above.
                  const _RequestsCard(),
                  const SizedBox(height: 22),
                  _QuickActions(
                    onRequests: () => context.go('/staff-requests'),
                    onVerification: () => context.go('/verification'),
                    onWaste: () => context.go('/waste-validation'),
                    onPoints: () => context.go('/collection-points'),
                    onAnnouncements: () => context.go('/announcements'),
                    onMemos: () => context.push('/memos/barangay'),
                    onEvents: () => context.go('/events'),
                    onParticipation: () => context.go('/event-participation'),
                    onRecycling: () => context.go('/dropoff'),
                    onTickets: () => context.go('/ticket-signatures'),
                    onWave2: () => context.go('/wave2/pass'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark hero: wordmark, sign-out, title and the approval queue.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.pendingFuture,
    required this.onLogout,
    required this.onReview,
  });

  final String name;
  final Future<List<Map<String, dynamic>>> pendingFuture;
  final VoidCallback onLogout;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, topInset + 16, 22, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandWordmark(fontSize: 12, color: AppColors.creamBright),
              const Spacer(),
              NotificationBell(
                iconSize: 18,
                color: AppColors.creamBright,
                circleColor: AppColors.creamBright.withValues(alpha: 0.14),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onLogout,
                customBorder: const CircleBorder(),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: AppColors.creamBright.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.creamBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Barangay staff',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.creamBright,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.creamBright.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          _ApprovalCard(pendingFuture: pendingFuture, onTap: onReview),
        ],
      ),
    );
  }
}

/// The barangay's own queue, in the hero: accounts waiting for review.
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.pendingFuture, required this.onTap});

  final Future<List<Map<String, dynamic>>> pendingFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(18),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: pendingFuture,
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resident applications',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      waiting
                          ? 'Checking the list…'
                          : count == 0
                              ? 'No one is waiting right now'
                              : '$count resident'
                                  '${count == 1 ? '' : 's'} waiting · check the ID',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.creamBright,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onRequests,
    required this.onVerification,
    required this.onWaste,
    required this.onPoints,
    required this.onAnnouncements,
    required this.onMemos,
    required this.onEvents,
    required this.onParticipation,
    required this.onRecycling,
    required this.onTickets,
    required this.onWave2,
  });

  final VoidCallback onRequests;
  final VoidCallback onVerification;
  final VoidCallback onWaste;
  final VoidCallback onPoints;
  final VoidCallback onAnnouncements;
  final VoidCallback onMemos;
  final VoidCallback onEvents;
  final VoidCallback onRecycling;
  final VoidCallback onParticipation;
  final VoidCallback onTickets;
  final VoidCallback onWave2;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _QuickTile(
        icon: Icons.confirmation_number_outlined,
        label: 'Trip tickets',
        onTap: onTickets,
      ),
      _QuickTile(icon: Icons.layers_outlined, label: 'Wave 2', onTap: onWave2),
      _QuickTile(
        icon: Icons.assignment_outlined,
        label: 'Requests',
        onTap: onRequests,
      ),
      _QuickTile(
        icon: Icons.verified_user_outlined,
        label: 'Verify',
        onTap: onVerification,
      ),
      _QuickTile(
        icon: Icons.inventory_2_outlined,
        label: 'Waste',
        onTap: onWaste,
      ),
      _QuickTile(
        icon: Icons.add_location_alt_outlined,
        label: 'Points',
        onTap: onPoints,
      ),
      _QuickTile(
        icon: Icons.campaign_outlined,
        label: 'Notices',
        onTap: onAnnouncements,
      ),
      // Memos and endorsements City Hall sends to this barangay.
      _QuickTile(
        icon: Icons.mail_outline_rounded,
        label: 'Memos',
        onTap: onMemos,
      ),
      _QuickTile(
        icon: Icons.event_available_outlined,
        label: 'Events',
        onTap: onEvents,
      ),
      _QuickTile(
        icon: Icons.groups_2_outlined,
        label: 'Sign-ups',
        onTap: onParticipation,
      ),
      _QuickTile(
        icon: Icons.recycling_rounded,
        label: 'Recycling',
        onTap: onRecycling,
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 6,
      childAspectRatio: 0.82,
      children: [
        for (var i = 0; i < items.length; i++)
          FadeSlideIn(
            index: i,
            offset: 10,
            child: HoverLift(child: items[i]),
          ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Center(
                        child: Icon(icon, size: 20, color: AppColors.forest),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live queue of resident collection requests. New submissions appear here
/// without a refresh, and tapping opens the staff desk to verify and assign.
class _RequestsCard extends StatelessWidget {
  const _RequestsCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CollectionRequest>>(
      stream: CollectionRequestService().watchAll(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <CollectionRequest>[];
        final open = all
            .where(
              (r) =>
                  r.status == RequestStatus.pending ||
                  r.status == RequestStatus.underReview ||
                  r.status == RequestStatus.approved,
            )
            .toList(growable: false);
        final pending = open
            .where((r) => r.status == RequestStatus.pending)
            .length;

        return InkWell(
          onTap: () => context.go('/staff-requests'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: AppColors.creamBright,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: open.isEmpty
                    ? AppColors.sage.withValues(alpha: 0.7)
                    : AppColors.forest.withValues(alpha: 0.45),
                width: open.isEmpty ? 1 : 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 17,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collection requests',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            open.isEmpty
                                ? 'Nothing waiting for review'
                                : pending == 0
                                ? '${open.length} in progress with staff'
                                : '$pending waiting for review · ${open.length} open',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pending > 0)
                      Container(
                        height: 22,
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.all(Radius.circular(11)),
                        ),
                        child: Text(
                          '$pending',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.moss,
                    ),
                  ],
                ),
                if (open.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final request in open.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: request.status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request.status.label,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: request.status.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (open.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+${open.length - 3} more',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

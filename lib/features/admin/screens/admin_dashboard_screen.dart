import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../route/models/collection_route.dart';
import '../../incident/models/incident.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../core/widgets/motion.dart';
import '../../incident/services/incident_service.dart';
import '../../route/services/route_service.dart';
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
  final _incidentService = IncidentService();
  final _routeService = RouteService();
  AuthProvider get _auth => context.read<AuthProvider>();

  late final Stream<List<Incident>> _incidentStream;
  late final Stream<CollectionRoute?> _routeStream;
  late Future<List<Map<String, dynamic>>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _incidentStream = _incidentService.watchAll();
    _routeStream = _routeService.watchActiveRoute();
    _pendingFuture = _auth.getPendingAccounts();
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
              routeStream: _routeStream,
              onLogout: _logout,
              onAssign: () => context.go('/routes'),
              onOpenMap: () => context.push('/live-routes'),
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
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _pendingFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _PendingCard(
                        count: count,
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                        onTap: () => context.go('/pending-accounts'),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const _RequestsCard(),
                  const SizedBox(height: 22),
                  StreamBuilder<List<Incident>>(
                    stream: _incidentStream,
                    builder: (context, snapshot) {
                      final pending = (snapshot.data ?? const <Incident>[])
                          .where((i) => i.status == IncidentStatus.pending)
                          .length;
                      return _QuickActions(
                        incidentBadge: pending,
                        onIncidents: () => context.go('/incidents'),
                        onRequests: () => context.go('/staff-requests'),
                        onRoutes: () => context.go('/routes'),
                        onVerification: () => context.go('/verification'),
                        onWaste: () => context.go('/waste-validation'),
                        onPoints: () => context.go('/collection-points'),
                        onAnnouncements: () => context.go('/announcements'),
                        onEvents: () => context.go('/events'),
                        onParticipation: () => context.go('/event-participation'),
                        onRecycling: () => context.go('/dropoff'),
                        onUsers: () => context.go('/admin'),
                        onTickets: () => context.go('/ticket-signatures'),
                        onDelays: () => context.go('/delays'),
                        onWave2: () => context.go('/wave2/pass'),
                      );
                    },
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

/// Dark hero: wordmark, sign-out, title and the live-route card.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.routeStream,
    required this.onLogout,
    required this.onAssign,
    required this.onOpenMap,
  });

  final String name;
  final Stream<CollectionRoute?> routeStream;
  final VoidCallback onLogout;
  final VoidCallback onAssign;
  final VoidCallback onOpenMap;

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
          _LiveRoutesCard(
            routeStream: routeStream,
            onAssign: onAssign,
            onOpenMap: onOpenMap,
          ),
        ],
      ),
    );
  }
}

class _LiveRoutesCard extends StatelessWidget {
  const _LiveRoutesCard({
    required this.routeStream,
    required this.onAssign,
    required this.onOpenMap,
  });

  final Stream<CollectionRoute?> routeStream;
  final VoidCallback onAssign;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: GestureDetector(
              onTap: onOpenMap,
              behavior: HitTestBehavior.opaque,
              child: const _MapPreview(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: StreamBuilder<CollectionRoute?>(
              stream: routeStream,
              builder: (context, snapshot) {
                final route = snapshot.data;
                final subtitle = route == null
                    ? 'No driver is collecting right now'
                    : '${route.driverName} · ${route.isStale ? 'signal lost' : route.status.label}';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live routes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
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
                    _AssignButton(onTap: onAssign),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignButton extends StatelessWidget {
  const _AssignButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Assign runs',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.creamBright,
          ),
        ),
      ),
    );
  }
}

/// Stylised map tile behind the live-route summary.
class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _MapPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  static const _ground = Color(0xFFE9F3DD);
  static const _dash = Color(0xFFCBD9BC);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = _ground);

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Main avenue across the tile.
    road.strokeWidth = 15;
    canvas.drawLine(Offset(-4, h * 0.34), Offset(w + 4, h * 0.58), road);

    // Cross street.
    road.strokeWidth = 11;
    canvas.drawLine(Offset(w * 0.3, -4), Offset(w * 0.36, h + 4), road);

    // Side street near the bottom.
    road.strokeWidth = 7;
    canvas.drawLine(Offset(-4, h * 0.9), Offset(w + 4, h * 0.78), road);

    final dash = Paint()
      ..color = _dash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    _dashed(canvas, Offset(-4, h * 0.34), Offset(w + 4, h * 0.58), dash);
    _dashed(canvas, Offset(w * 0.3, -4), Offset(w * 0.36, h + 4), dash);

    // Location pin.
    final centre = Offset(w * 0.55, h * 0.46);
    canvas.drawCircle(
      centre,
      13,
      Paint()..color = AppColors.forest.withValues(alpha: 0.16),
    );
    canvas.drawCircle(centre, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      centre,
      7.5,
      Paint()
        ..color = AppColors.forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(centre, 2.4, Paint()..color = AppColors.forest);
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 6.0;
    const gap = 6.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final step = (to - from) / total;

    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + dash).clamp(0.0, total);
      canvas.drawLine(
        from + step * travelled,
        from + step * end,
        paint,
      );
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
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

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.count,
    required this.loading,
    required this.onTap,
  });

  final int count;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = loading
        ? 'Loading accounts…'
        : count.toString() +
            (count == 1
                ? ' account awaiting approval'
                : ' accounts awaiting approval');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.forest.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending accounts',
                    style: TextStyle(
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
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                height: 22,
                width: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.moss,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.incidentBadge,
    required this.onIncidents,
    required this.onRequests,
    required this.onRoutes,
    required this.onVerification,
    required this.onWaste,
    required this.onPoints,
    required this.onAnnouncements,
    required this.onEvents,
    required this.onParticipation,
    required this.onRecycling,
    required this.onUsers,
    required this.onTickets,
    required this.onDelays,
    required this.onWave2,
  });

  final int incidentBadge;
  final VoidCallback onIncidents;
  final VoidCallback onRequests;
  final VoidCallback onRoutes;
  final VoidCallback onVerification;
  final VoidCallback onWaste;
  final VoidCallback onPoints;
  final VoidCallback onAnnouncements;
  final VoidCallback onEvents;
  final VoidCallback onRecycling;
  final VoidCallback onUsers;
  final VoidCallback onParticipation;
  final VoidCallback onTickets;
  final VoidCallback onDelays;
  final VoidCallback onWave2;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _QuickTile(
        icon: Icons.confirmation_number_outlined,
        label: 'Trip tickets',
        onTap: onTickets,
      ),
      _QuickTile(
        icon: Icons.layers_outlined,
        label: 'Wave 2',
        onTap: onWave2,
      ),
      _QuickTile(
        icon: Icons.error_outline_rounded,
        label: 'Incidents',
        badge: incidentBadge,
        onTap: onIncidents,
      ),
      _QuickTile(
        icon: Icons.assignment_outlined,
        label: 'Requests',
        onTap: onRequests,
      ),
      _QuickTile(
        icon: Icons.route_rounded,
        label: 'Routes',
        onTap: onRoutes,
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
      _QuickTile(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Users',
        onTap: onUsers,
      ),
      // Delays City Hall sends down, to announce to residents.
      _QuickTile(
        icon: Icons.schedule_rounded,
        label: 'Delays',
        onTap: onDelays,
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
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

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
                    if (badge > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          height: 14,
                          constraints: const BoxConstraints(minWidth: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badge > 9 ? '9+' : badge.toString(),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
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
            .where((r) =>
                r.status == RequestStatus.pending ||
                r.status == RequestStatus.underReview ||
                r.status == RequestStatus.approved)
            .toList(growable: false);
        final pending =
            open.where((r) => r.status == RequestStatus.pending).length;

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
                      child: const Icon(Icons.assignment_outlined,
                          size: 17, color: AppColors.forest),
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
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.moss),
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

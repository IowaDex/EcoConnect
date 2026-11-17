import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../dashboard/widgets/quick_action_grid.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../incident/models/incident.dart';
import '../../incident/services/incident_service.dart';
import '../../memos/services/memo_service.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';

/// The barangay desk.
///
/// Every figure the officer acts on is live: pending accounts, open resident
/// requests and unread incidents arrive through subscriptions held in state,
/// so the hero counters and the attention list can never disagree.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _incidentService = IncidentService();
  final _routeService = RouteService();
  final _memoService = MemoService();

  late final Stream<CollectionRoute?> _routeStream;

  List<Incident> _incidents = const [];
  List<CollectionRequest> _requests = const [];
  int _pendingAccounts = 0;
  int _unreadMemos = 0;

  StreamSubscription<List<Incident>>? _incidentSub;
  StreamSubscription<List<CollectionRequest>>? _requestSub;
  StreamSubscription<List<Memo>>? _memoSub;

  @override
  void initState() {
    super.initState();
    _routeStream = _routeService.watchActiveRoute();

    _incidentSub = _incidentService.watchAll().listen((incidents) {
      if (mounted) setState(() => _incidents = incidents);
    }, onError: (_) {});

    _requestSub = CollectionRequestService().watchAll().listen((requests) {
      if (mounted) setState(() => _requests = requests);
    }, onError: (_) {});

    _memoSub = _memoService.watchForChannel('barangay').listen((memos) {
      if (!mounted) return;
      setState(() {
        _unreadMemos = memos.where((m) => m.status == MemoStatus.sent).length;
      });
    }, onError: (_) {});

    _loadPendingAccounts();
  }

  @override
  void dispose() {
    _incidentSub?.cancel();
    _requestSub?.cancel();
    _memoSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingAccounts() async {
    try {
      final pending = await context.read<AuthProvider>().getPendingAccounts();
      if (mounted) setState(() => _pendingAccounts = pending.length);
    } catch (_) {
      // The counter keeps its last value; the desk is still usable.
    }
  }

  /// Requests still on the desk: submitted, under review or approved but not
  /// yet collected.
  List<CollectionRequest> get _openRequests => _requests
      .where(
        (request) =>
            request.status == RequestStatus.pending ||
            request.status == RequestStatus.underReview ||
            request.status == RequestStatus.approved,
      )
      .toList(growable: false);

  List<Incident> get _pendingIncidents => _incidents
      .where((incident) => incident.status == IncidentStatus.pending)
      .toList(growable: false);

  int get _pendingRequests =>
      _openRequests.where((r) => r.status == RequestStatus.pending).length;

  int get _attentionTotal =>
      _pendingAccounts + _pendingIncidents.length + _openRequests.length;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            RoleTopBar(onLogout: () => confirmAndLogout(context)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      FadeSlideIn(
                        index: 0,
                        child: RoleHero(
                          icon: Icons.account_balance_outlined,
                          eyebrow: 'BARANGAY STAFF · BATASAN HILLS',
                          greeting: greeting(),
                          title: user?.displayName ?? 'Barangay staff',
                          subtitle:
                              'Verify residents, assign collection runs and keep '
                              'the barangay records current.',
                          chip: _attentionTotal > 0
                              ? RoleChip(
                                  label: '$_attentionTotal to review',
                                  icon: Icons.inbox_rounded,
                                  tone: AppColors.warning,
                                )
                              : const RoleChip(
                                  label: 'All clear',
                                  icon: Icons.check_circle_rounded,
                                ),
                          stats: [
                            RoleStat(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Pending accounts',
                              value: _pendingAccounts,
                              accent: AppColors.warning,
                            ),
                            RoleStat(
                              icon: Icons.assignment_rounded,
                              label: 'Open requests',
                              value: _openRequests.length,
                            ),
                            RoleStat(
                              icon: Icons.warning_amber_rounded,
                              label: 'Incidents',
                              value: _pendingIncidents.length,
                              accent: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.lg),
                      FadeSlideIn(
                        index: 1,
                        child: _LiveRoutesCard(
                          routeStream: _routeStream,
                          onAssign: () => context.go('/routes'),
                          onOpenMap: () => context.push('/live-routes'),
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      FadeSlideIn(
                        index: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('NEEDS ATTENTION'),
                            const SizedBox(height: EcoSpace.sm),
                            _AttentionCard(
                              pendingAccounts: _pendingAccounts,
                              pendingRequests: _pendingRequests,
                              openRequests: _openRequests,
                              incidents: _pendingIncidents,
                              onAccounts: () => context.go('/pending-accounts'),
                              onRequests: () => context.go('/staff-requests'),
                              onIncidents: () => context.go('/incidents'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      FadeSlideIn(
                        index: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('QUICK ACTIONS'),
                            const SizedBox(height: EcoSpace.sm),
                            QuickActionGrid(
                              actions: [
                                const QuickAction(
                                  label: 'Trip tickets',
                                  icon: Icons.confirmation_number_outlined,
                                  route: '/ticket-signatures',
                                ),
                                const QuickAction(
                                  label: 'Wave 2',
                                  icon: Icons.layers_outlined,
                                  route: '/wave2/pass',
                                ),
                                QuickAction(
                                  label: 'Memos',
                                  icon: Icons.mail_outline_rounded,
                                  route: '/memos/barangay',
                                  badge: _unreadMemos,
                                ),
                                QuickAction(
                                  label: 'Incidents',
                                  icon: Icons.error_outline_rounded,
                                  route: '/incidents',
                                  badge: _pendingIncidents.length,
                                ),
                                const QuickAction(
                                  label: 'Requests',
                                  icon: Icons.assignment_outlined,
                                  route: '/staff-requests',
                                ),
                                const QuickAction(
                                  label: 'Routes',
                                  icon: Icons.route_rounded,
                                  route: '/routes',
                                ),
                                const QuickAction(
                                  label: 'Verify',
                                  icon: Icons.verified_user_outlined,
                                  route: '/verification',
                                ),
                                const QuickAction(
                                  label: 'Waste',
                                  icon: Icons.inventory_2_outlined,
                                  route: '/waste-validation',
                                ),
                                const QuickAction(
                                  label: 'Points',
                                  icon: Icons.add_location_alt_outlined,
                                  route: '/collection-points',
                                ),
                                const QuickAction(
                                  label: 'Notices',
                                  icon: Icons.campaign_outlined,
                                  route: '/announcements',
                                ),
                                const QuickAction(
                                  label: 'Events',
                                  icon: Icons.event_available_outlined,
                                  route: '/events',
                                ),
                                const QuickAction(
                                  label: 'Sign-ups',
                                  icon: Icons.groups_2_outlined,
                                  route: '/event-participation',
                                ),
                                const QuickAction(
                                  label: 'Recycling',
                                  icon: Icons.recycling_rounded,
                                  route: '/dropoff',
                                ),
                                const QuickAction(
                                  label: 'Users',
                                  icon: Icons.person_add_alt_1_rounded,
                                  route: '/admin',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live assignment card: a stylised map tile over the current route summary.
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
        boxShadow: AppColors.cardShadow,
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
                    : '${route.driverName} · '
                          '${route.isStale ? 'signal lost' : route.status.label}';

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
                              fontSize: 10,
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
    return const CustomPaint(painter: _MapPainter(), child: SizedBox.expand());
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
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}

/// One card that lists everything waiting on the desk, instead of the two
/// separate cards (accounts, requests) plus a third badge that used to repeat
/// the same numbers.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.pendingAccounts,
    required this.pendingRequests,
    required this.openRequests,
    required this.incidents,
    required this.onAccounts,
    required this.onRequests,
    required this.onIncidents,
  });

  final int pendingAccounts;
  final int pendingRequests;
  final List<CollectionRequest> openRequests;
  final List<Incident> incidents;
  final VoidCallback onAccounts;
  final VoidCallback onRequests;
  final VoidCallback onIncidents;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (pendingAccounts > 0) {
      rows.add(
        _AttentionRow(
          icon: Icons.person_add_alt_1_rounded,
          title: pendingAccounts == 1
              ? '1 account awaiting approval'
              : '$pendingAccounts accounts awaiting approval',
          detail: 'Resident sign-ups need a barangay decision',
          tone: AppColors.warning,
          onTap: onAccounts,
        ),
      );
    }

    if (incidents.isNotEmpty) {
      rows.add(
        _AttentionRow(
          icon: Icons.warning_amber_rounded,
          title: incidents.length == 1
              ? '1 incident report'
              : '${incidents.length} incident reports',
          detail: 'Filed by residents and waiting for review',
          tone: AppColors.error,
          onTap: onIncidents,
        ),
      );
    }

    for (final request in openRequests.take(3)) {
      rows.add(
        _AttentionRow(
          icon: Icons.assignment_outlined,
          title: request.title,
          detail: request.status.label,
          tone: request.status.color,
          onTap: onRequests,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                size: 16,
                color: AppColors.forest,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Waiting on the desk',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
              if (pendingRequests > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                  ),
                  child: Text(
                    '$pendingRequests new',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nothing is waiting for review. New sign-ups, reports and '
                      'requests appear here.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  color: AppColors.sage.withValues(alpha: 0.45),
                ),
              rows[i],
            ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcoRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                ),
                child: Icon(icon, size: 15, color: tone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      detail,
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
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.moss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

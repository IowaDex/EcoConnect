import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../dashboard/widgets/quick_action_grid.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../incident/models/incident.dart';
import '../../incident/services/incident_service.dart';
import '../../manuals/widgets/approved_manuals_section.dart';
import '../../memos/services/memo_service.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';

/// The barangay desk.
///
/// Every figure the officer acts on is live: residents waiting for an ID
/// check, open collection requests, unhandled incidents and unread memos
/// arrive through subscriptions held in state, so the hero counters, the
/// attention list and the shortcut badges can never disagree.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _incidentService = IncidentService();
  final _memoService = MemoService();

  List<Incident> _incidents = const [];
  List<CollectionRequest> _requests = const [];
  List<Map<String, dynamic>> _residents = const [];
  int _unreadMemos = 0;

  StreamSubscription<List<Incident>>? _incidentSub;
  StreamSubscription<List<CollectionRequest>>? _requestSub;
  StreamSubscription<List<Memo>>? _memoSub;
  StreamSubscription<List<Map<String, dynamic>>>? _residentSub;

  @override
  void initState() {
    super.initState();

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

    // The same live list the validation desk reads, so the "to review" figure
    // and the queue behind it always agree.
    _residentSub = context.read<AuthProvider>().watchResidents().listen((
      residents,
    ) {
      if (mounted) setState(() => _residents = residents);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _incidentSub?.cancel();
    _requestSub?.cancel();
    _memoSub?.cancel();
    _residentSub?.cancel();
    super.dispose();
  }

  /// Residents whose ID is still in the validation queue.
  List<Map<String, dynamic>> get _pendingResidents {
    final list = _residents
        .where(
          (resident) =>
              VerificationStatusX.fromName(
                resident['verificationStatus'] as String?,
              ) ==
              VerificationStatus.pending,
        )
        .toList();
    // Oldest first: the queue is worked from the front.
    list.sort((a, b) {
      final aDate = _asDate(a['createdAt']);
      final bDate = _asDate(b['createdAt']);
      if (aDate == null || bDate == null) return 0;
      return aDate.compareTo(bDate);
    });
    return list;
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

  List<Incident> get _pendingIncidents {
    final list = _incidents
        .where((incident) => incident.status == IncidentStatus.pending)
        .toList();
    list.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return list;
  }

  /// Groups the pending work for the attention card. The lists are passed in
  /// so one build reads each source once and every figure agrees.
  List<_AttentionGroup> _attentionFor({
    required List<Map<String, dynamic>> residents,
    required List<Incident> incidents,
    required List<CollectionRequest> requests,
  }) {
    final groups = <_AttentionGroup>[];

    if (residents.isNotEmpty) {
      groups.add(
        _AttentionGroup(
          icon: Icons.person_search_rounded,
          label: 'Accounts to validate',
          route: '/verification',
          color: AppColors.warning,
          total: residents.length,
          rows: [
            for (final resident in residents.take(2))
              _AttentionRow(
                title: '${resident['name'] ?? 'Resident'}',
                subtitle:
                    'ID waiting · ${timeAgo(_asDate(resident['createdAt']))}',
              ),
          ],
        ),
      );
    }

    if (incidents.isNotEmpty) {
      groups.add(
        _AttentionGroup(
          icon: Icons.report_gmailerrorred_rounded,
          label: 'Incidents to resolve',
          route: '/incidents',
          color: AppColors.error,
          total: incidents.length,
          rows: [
            for (final incident in incidents.take(2))
              _AttentionRow(
                title: incident.category.label,
                subtitle:
                    '${incident.residentName} · ${timeAgo(incident.createdAt)}',
              ),
          ],
        ),
      );
    }

    if (requests.isNotEmpty) {
      groups.add(
        _AttentionGroup(
          icon: Icons.assignment_outlined,
          label: 'Collection requests',
          route: '/staff-requests',
          color: AppColors.primary,
          total: requests.length,
          rows: [
            for (final request in requests.take(2))
              _AttentionRow(
                title: request.title,
                subtitle: '${request.requesterName} · ${request.status.label}',
              ),
          ],
        ),
      );
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final pendingResidents = _pendingResidents;
    final incidents = _pendingIncidents;
    final requests = _openRequests;
    final pendingAccounts = pendingResidents.length;
    final attentionTotal = pendingAccounts + incidents.length + requests.length;
    final attention = _attentionFor(
      residents: pendingResidents,
      incidents: incidents,
      requests: requests,
    );

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
                              'Verify residents, clear incidents and keep the '
                              'collection desk moving.',
                          chip: attentionTotal > 0
                              ? RoleChip(
                                  label: '$attentionTotal to review',
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
                              label: 'Accounts',
                              value: pendingAccounts,
                              accent: AppColors.warning,
                            ),
                            RoleStat(
                              icon: Icons.assignment_rounded,
                              label: 'Requests',
                              value: requests.length,
                            ),
                            RoleStat(
                              icon: Icons.report_gmailerrorred_rounded,
                              label: 'Incidents',
                              value: incidents.length,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      FadeSlideIn(
                        index: 1,
                        child: _AttentionSection(
                          groups: attention,
                          total: attentionTotal,
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      const FadeSlideIn(
                        index: 2,
                        child: ApprovedManualsSection(),
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
                                QuickAction(
                                  label: 'Verify',
                                  icon: Icons.verified_user_outlined,
                                  route: '/verification',
                                  badge: pendingAccounts,
                                ),
                                QuickAction(
                                  label: 'Requests',
                                  icon: Icons.assignment_outlined,
                                  route: '/staff-requests',
                                  badge: requests.length,
                                ),
                                QuickAction(
                                  label: 'Incidents',
                                  icon: Icons.report_gmailerrorred_outlined,
                                  route: '/incidents',
                                  badge: incidents.length,
                                ),
                                const QuickAction(
                                  label: 'Waste',
                                  icon: Icons.inventory_2_outlined,
                                  route: '/waste-validation',
                                ),
                                QuickAction(
                                  label: 'Memos',
                                  icon: Icons.mail_outline_rounded,
                                  route: '/memos/barangay',
                                  badge: _unreadMemos,
                                ),
                                const QuickAction(
                                  label: 'Trip tickets',
                                  icon: Icons.confirmation_number_outlined,
                                  route: '/ticket-signatures',
                                ),
                                const QuickAction(
                                  label: 'Schedules',
                                  icon: Icons.calendar_month_outlined,
                                  route: '/assignments',
                                ),
                                const QuickAction(
                                  label: 'Wave 2',
                                  icon: Icons.layers_outlined,
                                  route: '/wave2/pass',
                                ),
                                const QuickAction(
                                  label: 'Stops',
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

DateTime? _asDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// One row in the attention card: a single thing the desk still has to do.
class _AttentionRow {
  const _AttentionRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// One source of pending work, with its own shortcut.
class _AttentionGroup {
  const _AttentionGroup({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    required this.total,
    required this.rows,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final int total;
  final List<_AttentionRow> rows;
}

/// The "what needs me now" card.
///
/// Groups are ordered by how directly they block a resident (an unvalidated
/// account cannot use the app at all), and each header opens the desk that
/// clears it. Empty groups disappear, and an empty desk gets a calm
/// confirmation instead of an empty box.
class _AttentionSection extends StatelessWidget {
  const _AttentionSection({required this.groups, required this.total});

  final List<_AttentionGroup> groups;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('NEEDS ATTENTION'),
        const SizedBox(height: EcoSpace.sm),
        EcoCard(
          padding: EdgeInsets.zero,
          child: total == 0 ? const _DeskClear() : _groups(),
        ),
      ],
    );
  }

  Widget _groups() {
    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.sage.withValues(alpha: 0.35),
            ),
          _GroupBlock(group: groups[i]),
        ],
      ],
    );
  }
}

class _GroupBlock extends StatefulWidget {
  const _GroupBlock({required this.group});

  final _AttentionGroup group;

  @override
  State<_GroupBlock> createState() => _GroupBlockState();
}

class _GroupBlockState extends State<_GroupBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(group.route),
            child: AnimatedContainer(
              duration: EcoMotion.fast,
              curve: EcoMotion.enter,
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.lightGreen.withValues(alpha: 0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(EcoRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(group.icon, size: 13, color: group.color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      group.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: group.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(EcoRadius.pill),
                    ),
                    child: Text(
                      '${group.total}',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: group.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  AnimatedSlide(
                    duration: EcoMotion.fast,
                    curve: EcoMotion.enter,
                    offset: Offset(_hovered ? 0.25 : 0, 0),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final row in group.rows)
          _AttentionRowTile(row: row, onTap: () => context.push(group.route)),
        if (group.total > group.rows.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 0, 14, 9),
            child: Text(
              '+${group.total - group.rows.length} more waiting',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }
}

class _AttentionRowTile extends StatefulWidget {
  const _AttentionRowTile({required this.row, required this.onTap});

  final _AttentionRow row;
  final VoidCallback onTap;

  @override
  State<_AttentionRowTile> createState() => _AttentionRowTileState();
}

class _AttentionRowTileState extends State<_AttentionRowTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.lightGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(EcoRadius.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                duration: EcoMotion.fast,
                curve: EcoMotion.enter,
                offset: Offset(_hovered ? 0.3 : 0, 0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: _hovered ? AppColors.primary : AppColors.sage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing is waiting: the desk says so plainly instead of showing an empty
/// list with a spinner that never stops.
class _DeskClear extends StatelessWidget {
  const _DeskClear();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The desk is clear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No account, incident or request is waiting for you.',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

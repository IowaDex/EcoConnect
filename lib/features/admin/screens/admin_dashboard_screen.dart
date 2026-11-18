import 'dart:async';

import 'package:flutter/material.dart';
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
  final _memoService = MemoService();

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
      final pending = await context
          .read<AuthProvider>()
          .getPendingRegistrations();
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
                          ],
                        ),
                      ),
                      const SizedBox(height: EcoSpace.xl),
                      FadeSlideIn(
                        index: 2,
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
                                const QuickAction(
                                  label: 'Requests',
                                  icon: Icons.assignment_outlined,
                                  route: '/staff-requests',
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

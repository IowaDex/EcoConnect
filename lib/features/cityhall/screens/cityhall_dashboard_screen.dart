import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../../tickets/widgets/ticket_card.dart';

/// City Hall — the DSQC and the super admin.
///
/// Holds the last signature on every ticket, receives complaints straight from
/// residents, approves wave 2, and pushes delay reports to the district
/// officer.
class CityHallDashboardScreen extends StatefulWidget {
  const CityHallDashboardScreen({super.key});

  @override
  State<CityHallDashboardScreen> createState() => _CityHallDashboardScreenState();
}

class _CityHallDashboardScreenState extends State<CityHallDashboardScreen> {
  int _tab = 0;

  Future<void> _logout() async {
    final confirmed = await confirmLogout(context);
    if (!confirmed || !mounted) return;
    final auth = context.read<AuthProvider>();
    await context.read<LocationProvider>().endSession();
    await auth.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/memos/new'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded, size: 18),
        label: const Text(
          'Memo',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  const NotificationBell(
                    iconSize: 19,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 2),
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
            ),
            Expanded(
              child: StreamBuilder<List<TripTicket>>(
                stream: TicketService().watchAll(),
                builder: (context, snapshot) {
                  final tickets = snapshot.data ?? const <TripTicket>[];
                  final forSignature = tickets
                      .where((t) => t.status == TicketStatus.iswimSigned)
                      .toList(growable: false);
                  final received = tickets
                      .where((t) => t.status == TicketStatus.completed)
                      .toList(growable: false);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 96),
                    children: [
                      const Text(
                        'City Hall · DSQC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.moss,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.displayName ?? 'City Hall',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ActionGrid(
                        pendingSignatures: forSignature.length,
                        received: received.length,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _tabButton(0, 'For signature', forSignature.length),
                          const SizedBox(width: 8),
                          _tabButton(1, 'Received', received.length),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_tab == 0)
                        ..._cards(
                          context,
                          forSignature,
                          'Pirma mo',
                          empty: 'Wala pang ticket na dumarating dito. Dadaan '
                              'muna ito sa Barangay at Iswim.',
                        )
                      else
                        ..._cards(
                          context,
                          received,
                          null,
                          empty: 'Wala pang kumpletong ticket.',
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

  Widget _tabButton(int item, String label, int count) {
    final selected = item == _tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = item),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.sage,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(
    BuildContext context,
    List<TripTicket> tickets,
    String? trailing, {
    required String empty,
  }) {
    if (tickets.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.6,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ];
    }
    return [
      for (final ticket in tickets) ...[
        TicketCard(
          ticket: ticket,
          trailingLabel: trailing,
          onTap: () => context.push('/tickets/${ticket.id}'),
        ),
        const SizedBox(height: 9),
      ],
    ];
  }
}

/// The DSQC desk, in one glance.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.pendingSignatures, required this.received});

  final int pendingSignatures;
  final int received;

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, String detail, IconData icon, String route})>[
      (
        label: 'Delay reports',
        detail: 'Push sa district officer',
        icon: Icons.timer_outlined,
        route: '/delays',
      ),
      (
        label: 'Incidents',
        detail: 'Deretso galing resident',
        icon: Icons.report_outlined,
        route: '/incidents',
      ),
      (
        label: 'Wave 2',
        detail: 'Approval ng barangay',
        icon: Icons.layers_outlined,
        route: '/wave2',
      ),
      (
        label: 'Memos',
        detail: 'Endorsements at memo',
        icon: Icons.mail_outline_rounded,
        route: '/memos/cityHall',
      ),
      (
        label: 'Email log',
        detail: 'Auto-email sa officer',
        icon: Icons.outgoing_mail,
        route: '/email-log',
      ),
      (
        label: 'Accounts',
        detail: 'Gawa ng login ng crew',
        icon: Icons.badge_outlined,
        route: '/accounts',
      ),
      (
        label: 'Fleet',
        detail: 'Truck at driver',
        icon: Icons.local_shipping_outlined,
        route: '/fleet',
      ),
      (
        label: 'Mga pirma',
        detail: '$pendingSignatures pending',
        icon: Icons.draw_outlined,
        route: '/cityhall',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          SizedBox(
            width: 132,
            child: GestureDetector(
              onTap: () {
                if (action.route == '/cityhall') return;
                context.push(action.route);
              },
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(action.icon, size: 16, color: AppColors.forest),
                    const SizedBox(height: 6),
                    Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    Text(
                      action.detail,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1.3,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

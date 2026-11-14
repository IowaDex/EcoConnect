import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../../tickets/widgets/ticket_card.dart';

/// Iswim's console: issues the tickets, signs them, and keeps the per-truck
/// history the barangay and City Hall both read.
class IswimDashboardScreen extends StatefulWidget {
  const IswimDashboardScreen({super.key});

  @override
  State<IswimDashboardScreen> createState() => _IswimDashboardScreenState();
}

class _IswimDashboardScreenState extends State<IswimDashboardScreen> {
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
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/iswim/new-ticket'),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Trip ticket',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
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
              child: _tab == 0
                  ? _TicketFeed(userName: user?.displayName ?? 'Iswim')
                  : const _FleetList(),
            ),
            _BottomBar(
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketFeed extends StatelessWidget {
  const _TicketFeed({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripTicket>>(
      stream: TicketService().watchAll(),
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? const <TripTicket>[];
        final waiting = tickets.where((t) => t.needsDriver).length;
        final running = tickets.where((t) => t.canStartTrip).length;
        final toSign =
            tickets.where((t) => t.status == TicketStatus.barangaySigned).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 96),
          children: [
            const Text(
              'Iswim',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.moss,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'Total', value: '${tickets.length}'),
                const SizedBox(width: 8),
                _Stat(label: 'Waiting driver', value: '$waiting'),
                const SizedBox(width: 8),
                _Stat(label: 'Running', value: '$running'),
                const SizedBox(width: 8),
                _Stat(label: 'Pirma mo', value: '$toSign', highlight: true),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _quickAction(
                  context,
                  Icons.timer_outlined,
                  'Delay report',
                  '/delays/new',
                ),
                const SizedBox(width: 8),
                _quickAction(
                  context,
                  Icons.mail_outline_rounded,
                  'Memo sa City Hall',
                  '/memos/new',
                ),
                const SizedBox(width: 8),
                _quickAction(
                  context,
                  Icons.receipt_long_outlined,
                  'Delay list',
                  '/delays',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Wala pang ticket. Pindutin ang "Trip ticket" para gumawa — '
                  'pipili ka ng truck at automatic na kasama ang driver niya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.6,
                    color: AppColors.inkMuted,
                  ),
                ),
              )
            else
              for (final ticket in tickets) ...[
                TicketCard(
                  ticket: ticket,
                  onTap: () => context.push('/tickets/${ticket.id}'),
                ),
                const SizedBox(height: 9),
              ],
          ],
        );
      },
    );
  }
}

Widget _quickAction(
  BuildContext context,
  IconData icon,
  String label,
  String route,
) {
  return Expanded(
    child: GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sage),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: AppColors.forest),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FleetList extends StatelessWidget {
  const _FleetList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GarbageTruck>>(
      stream: FleetService().watchTrucks(),
      builder: (context, snapshot) {
        final trucks = snapshot.data ?? const <GarbageTruck>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            const Text(
              'Fleet · history per truck',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bawat truck may permanenteng driver. Pindutin ang plate para sa '
              'lahat ng trip ticket niya.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/fleet'),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text(
                  'I-manage ang fleet (dagdag / edit ng truck)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.sage),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final GarbageTruck truck in trucks) ...[
              _TruckRow(truck: truck),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _TruckRow extends StatelessWidget {
  const _TruckRow({required this.truck});

  final GarbageTruck truck;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/trucks/${truck.id}/history'),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    size: 17, color: AppColors.forest),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.plateNumber,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    Text(
                      '${truck.wheelerLabel} · ${truck.driverName}',
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
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? AppColors.mint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? AppColors.primary : AppColors.sage,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primary : AppColors.forest,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                height: 1.3,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(29),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            _tabItem(0, Icons.confirmation_number_outlined, 'Tickets'),
            _tabItem(1, Icons.local_shipping_outlined, 'Fleet'),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int item, IconData icon, String label) {
    final selected = item == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(item),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.forest : AppColors.inkMuted,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.forest : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

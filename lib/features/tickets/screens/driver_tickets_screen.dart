import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/widgets/driver_nav_bar.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// The driver's ticket inbox, and the second tab of the driver app.
///
/// A ticket has to be accepted here before the trip can start, so this screen
/// is the gate between "Iswim issued it" and "the truck moves". The ticket that
/// is running right now is lifted out of the list and pinned on top, so the
/// way back into a live trip is always the first thing on the screen.
class DriverTicketsScreen extends StatefulWidget {
  const DriverTicketsScreen({super.key});

  @override
  State<DriverTicketsScreen> createState() => _DriverTicketsScreenState();
}

class _DriverTicketsScreenState extends State<DriverTicketsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Tickets matching the search box.
  List<TripTicket> _visible(List<TripTicket> tickets) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return tickets;
    return tickets
        .where((ticket) =>
            ticket.code.toLowerCase().contains(query) ||
            ticket.plateNumber.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Row(
                children: [
                  BrandWordmark(fontSize: 10.5),
                  Spacer(),
                  NotificationBell(iconSize: 19, color: AppColors.inkMuted),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trip tickets',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ),
            Expanded(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<TripTicket>>(
                      stream: TicketService().watchForDriver(uid),
                      builder: (context, snapshot) {
                        final tickets =
                            snapshot.data ?? const <TripTicket>[];
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            tickets.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (tickets.isEmpty) {
                          return const _EmptyInbox();
                        }
                        return _Inbox(
                          search: _search,
                          visible: _visible(tickets),
                          onSearchChanged: () => setState(() {}),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverNavBar(currentIndex: 1),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({
    required this.search,
    required this.visible,
    required this.onSearchChanged,
  });

  final TextEditingController search;
  final List<TripTicket> visible;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    // The running trip is the one the driver is most likely to come back for,
    // so it leads the list instead of sitting somewhere in it.
    TripTicket? live;
    for (final ticket in visible) {
      if (ticket.status == TicketStatus.running) {
        live = ticket;
        break;
      }
    }

    final waiting = visible
        .where((t) => t.needsDriver && t.id != live?.id)
        .toList(growable: false);
    final others = visible
        .where((t) => !t.needsDriver && t.id != live?.id)
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SearchField(
            controller: search,
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No tickets match',
                  message: 'Try another ticket number or plate.',
                  compact: true,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  children: [
                    if (live != null) ...[
                      _LiveTicketCard(ticket: live),
                      const SizedBox(height: 16),
                    ],
                    if (waiting.isNotEmpty) ...[
                      Text(
                        'Kailangan ng aksyon (${waiting.length})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final ticket in waiting) ...[
                        TicketCard(
                          ticket: ticket,
                          trailingLabel: 'Accept',
                          onTap: () => context.push('/tickets/${ticket.id}'),
                        ),
                        const SizedBox(height: 9),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (others.isNotEmpty) ...[
                      if (live != null || waiting.isNotEmpty) ...[
                        const Text(
                          'Other tickets',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final ticket in others) ...[
                        TicketCard(
                          ticket: ticket,
                          onTap: () => context.push('/tickets/${ticket.id}'),
                        ),
                        const SizedBox(height: 9),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// The running ticket, lifted to the top of the inbox.
class _LiveTicketCard extends StatelessWidget {
  const _LiveTicketCard({required this.ticket});

  final TripTicket ticket;

  /// The route as Iswim typed it, split into the two lines the card shows:
  /// the first street, then the rest of the run followed by its zone.
  List<String> get _routeLines {
    final parts = ticket.route
        .split(RegExp(r'[\n,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return ticket.zone.isEmpty ? const [] : [ticket.zone];
    }
    final rest = [
      if (parts.length > 1) parts.skip(1).join(', '),
      if (ticket.zone.isNotEmpty) ticket.zone,
    ].join(' · ');
    return [parts.first, if (rest.isNotEmpty) rest];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F2E7), Color(0xFFF8FBF8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        ticket.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Chip(label: ticket.waveLabel),
                  ],
                ),
              ),
              const _RunningPill(),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded,
                  size: 14, color: AppColors.forest),
              const SizedBox(width: 6),
              Text(
                ticket.plateNumber,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '· ${ticket.wheelers}-wheeler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  ticket.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          if (_routeLines.isNotEmpty) ...[
            const SizedBox(height: 7),
            for (final line in _routeLines)
              Text(
                line,
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.55,
                  color: AppColors.inkMuted,
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: () => context.go('/driver'),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Continue trip'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grey pill for the ticket code's wave.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: AppColors.inkMuted),
      ),
    );
  }
}

/// Green "● In progress" badge.
class _RunningPill extends StatelessWidget {
  const _RunningPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(),
          SizedBox(width: 5),
          Text(
            'In progress',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      width: 5,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 11.5, color: AppColors.textDark),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search ticket number',
        hintStyle: TextStyle(
          fontSize: 11.5,
          color: AppColors.inkMuted.withValues(alpha: 0.8),
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.inkMuted,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: AppColors.inkMuted,
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined,
                size: 42, color: AppColors.sage),
            SizedBox(height: 12),
            Text(
              'No trip tickets yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Iswim creates the ticket. When a new one arrives, a notification '
              'appears here and you cannot start the trip until you accept it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

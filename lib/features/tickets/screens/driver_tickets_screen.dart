import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// The driver's ticket inbox.
///
/// A ticket has to be accepted here before the trip can start, so this screen
/// is the gate between "Iswim issued it" and "the truck moves".
class DriverTicketsScreen extends StatefulWidget {
  const DriverTicketsScreen({super.key});

  @override
  State<DriverTicketsScreen> createState() => _DriverTicketsScreenState();
}

class _DriverTicketsScreenState extends State<DriverTicketsScreen> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TripTicket> _filter(List<TripTicket> tickets) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return tickets;
    return tickets.where((t) {
      return t.code.toLowerCase().contains(q) ||
          t.plateNumber.toLowerCase().contains(q) ||
          t.zone.toLowerCase().contains(q) ||
          t.route.toLowerCase().contains(q) ||
          t.date.toLowerCase().contains(q) ||
          t.status.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver');
            }
          },
        ),
        title: const Text(
          'Trip tickets',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<TripTicket>>(
              stream: TicketService().watchForDriver(uid),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const <TripTicket>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    all.isEmpty) {
                  return const SkeletonList();
                }
                if (all.isEmpty) {
                  return const _EmptyInbox();
                }

                final tickets = _filter(all);
                final page = clampPage(_page, tickets.length, _pageSize);
                final visible = pageSlice(tickets, page, _pageSize);
                final waiting = visible
                    .where((t) => t.needsDriver)
                    .toList(growable: false);
                final others = visible
                    .where((t) => !t.needsDriver)
                    .toList(growable: false);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                      child: EcoSearchField(
                        controller: _search,
                        hint: 'Search code, plate, zone, status',
                        onChanged: (value) => setState(() {
                          _query = value;
                          _page = 0;
                        }),
                      ),
                    ),
                    Expanded(
                      child: tickets.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'No tickets match your search.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                              children: [
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
                                      onTap: () =>
                                          context.push('/tickets/${ticket.id}'),
                                    ),
                                    const SizedBox(height: 9),
                                  ],
                                  const SizedBox(height: 8),
                                ],
                                if (others.isNotEmpty) ...[
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
                                  for (final ticket in others) ...[
                                    TicketCard(
                                      ticket: ticket,
                                      onTap: () =>
                                          context.push('/tickets/${ticket.id}'),
                                    ),
                                    const SizedBox(height: 9),
                                  ],
                                ],
                              ],
                            ),
                    ),
                    if (tickets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: EcoPaginationBar(
                          page: page,
                          pageSize: _pageSize,
                          total: tickets.length,
                          onPageChanged: (next) => setState(() => _page = next),
                          onPageSizeChanged: (size) => setState(() {
                            _pageSize = size;
                            _page = 0;
                          }),
                        ),
                      ),
                  ],
                );
              },
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
            Icon(
              Icons.confirmation_number_outlined,
              size: 42,
              color: AppColors.sage,
            ),
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

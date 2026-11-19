import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// The signature queue for one signer.
///
/// Barangay, Iswim and City Hall all see the same screen — only the tickets
/// that are actually waiting on them appear, so nobody signs out of order.
class TicketQueueScreen extends StatefulWidget {
  const TicketQueueScreen({
    super.key,
    required this.signer,
    required this.title,
    this.subtitle,
  });

  final TicketStatusSigner signer;
  final String title;
  final String? subtitle;

  @override
  State<TicketQueueScreen> createState() => _TicketQueueScreenState();
}

class _TicketQueueScreenState extends State<TicketQueueScreen> {
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
          t.driverName.toLowerCase().contains(q) ||
          t.plateNumber.toLowerCase().contains(q) ||
          t.zone.toLowerCase().contains(q) ||
          t.route.toLowerCase().contains(q) ||
          t.date.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'SIGNATURE QUEUE',
      title: widget.title,
      subtitle: widget.subtitle,
      onBack: () => ecoBack(context, '/driver'),
      body: StreamBuilder<List<TripTicket>>(
        stream: TicketService().watchSignerQueue(widget.signer),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <TripTicket>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              all.isEmpty) {
            return const SkeletonList();
          }
          if (all.isEmpty) {
            return _EmptyQueue(
              signer: widget.signer,
              subtitle: widget.subtitle,
            );
          }

          final tickets = _filter(all);
          final page = clampPage(_page, tickets.length, _pageSize);
          final visible = pageSlice(tickets, page, _pageSize);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: EcoSearchField(
                  controller: _search,
                  hint: 'Search code, driver, plate, zone',
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
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          Text(
                            '${tickets.length} ticket'
                            '${tickets.length == 1 ? '' : 's'} waiting for '
                            'your signature',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final ticket in visible) ...[
                            TicketCard(
                              ticket: ticket,
                              trailingLabel: 'Your signature',
                              onTap: () =>
                                  context.push('/tickets/${ticket.id}'),
                            ),
                            const SizedBox(height: 9),
                          ],
                        ],
                      ),
              ),
              if (tickets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.signer, this.subtitle});

  final TicketStatusSigner signer;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.draw_outlined,
      title: 'Nothing to sign yet',
      message:
          subtitle ??
          'Tickets arrive here automatically once the previous signature is '
              'done.',
    );
  }
}

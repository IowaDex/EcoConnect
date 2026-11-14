import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// The driver's ticket inbox.
///
/// A ticket has to be accepted here before the trip can start, so this screen
/// is the gate between "Iswim issued it" and "the truck moves".
class DriverTicketsScreen extends StatelessWidget {
  const DriverTicketsScreen({super.key});

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
                final tickets = snapshot.data ?? const <TripTicket>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    tickets.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tickets.isEmpty) {
                  return const _EmptyInbox();
                }
                final waiting =
                    tickets.where((t) => t.needsDriver).toList(growable: false);
                final others = tickets
                    .where((t) => !t.needsDriver)
                    .toList(growable: false);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
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
                          onTap: () => context.push('/tickets/${ticket.id}'),
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
                          onTap: () => context.push('/tickets/${ticket.id}'),
                        ),
                        const SizedBox(height: 9),
                      ],
                    ],
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

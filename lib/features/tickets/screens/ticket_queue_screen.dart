import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/trip_ticket.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_card.dart';

/// The signature queue for one signer.
///
/// Barangay, Iswim and City Hall all see the same screen — only the tickets
/// that are actually waiting on them appear, so nobody signs out of order.
class TicketQueueScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<TripTicket>>(
        stream: TicketService().watchSignerQueue(signer),
        builder: (context, snapshot) {
          final tickets = snapshot.data ?? const <TripTicket>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tickets.isEmpty) {
            return _EmptyQueue(signer: signer, subtitle: subtitle);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              Text(
                '${tickets.length} ticket na naghihintay ng pirma mo',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 10),
              for (final ticket in tickets) ...[
                TicketCard(
                  ticket: ticket,
                  trailingLabel: 'Pirma mo',
                  onTap: () => context.push('/tickets/${ticket.id}'),
                ),
                const SizedBox(height: 9),
              ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_outlined, size: 42, color: AppColors.sage),
            const SizedBox(height: 12),
            const Text(
              'Wala pang pirma na kailangan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle ??
                  'Automatic na darating dito ang ticket pag tapos na ang '
                      'naunang pirma.',
              textAlign: TextAlign.center,
              style: const TextStyle(
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

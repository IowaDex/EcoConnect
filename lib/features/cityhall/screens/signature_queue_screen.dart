import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../memos/services/memo_service.dart';
import '../../memos/widgets/memo_widgets.dart';
import '../../tickets/models/trip_ticket.dart';
import '../../tickets/services/ticket_service.dart';
import '../../tickets/widgets/ticket_card.dart';

/// Everything waiting for City Hall's signature, in one queue.
///
/// The desk signs two kinds of record: memos addressed to City Hall, and trip
/// tickets Iswim has already verified. Both are opened in place so the
/// signature is applied to the real document, not to this list.
class SignatureQueueScreen extends StatelessWidget {
  const SignatureQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Signatures',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Memos for City Hall',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          _MemoQueue(),
          const SizedBox(height: 20),
          const Text(
            'Trip tickets for final signature',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 8),
          _TicketQueue(),
        ],
      ),
    );
  }
}

class _MemoQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Memo>>(
      stream: MemoService().watchForChannel('cityHall'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }
        if (snapshot.hasError) {
          return _error(snapshot.error!);
        }
        final pending = (snapshot.data ?? const <Memo>[])
            .where((m) => !m.isSigned)
            .toList(growable: false);
        if (pending.isEmpty) {
          return const _EmptyLine('No memo is waiting for a signature.');
        }
        return Column(
          children: [
            for (final memo in pending) ...[
              MemoCard(memo: memo),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    );
  }
}

class _TicketQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripTicket>>(
      stream: TicketService().watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }
        if (snapshot.hasError) {
          return _error(snapshot.error!);
        }
        final pending = (snapshot.data ?? const <TripTicket>[])
            .where((t) => t.status == TicketStatus.iswimSigned)
            .toList(growable: false);
        if (pending.isEmpty) {
          return const _EmptyLine('No ticket is waiting for a signature.');
        }
        return Column(
          children: [
            for (final ticket in pending) ...[
              TicketCard(
                ticket: ticket,
                trailingLabel: 'Your signature',
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

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 10,
          height: 1.5,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

Widget _error(Object error) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        AppFeedback.describe(error),
        style: const TextStyle(fontSize: 10, color: AppColors.error),
      ),
    );

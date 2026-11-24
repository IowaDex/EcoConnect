import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
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
    return EcoPageScaffold(
      title: 'Signature queue',
      eyebrow: 'CITY HALL · DOCUMENT DESK',
      subtitle: 'The last step before a record is closed at City Hall.',
      icon: Icons.draw_rounded,
      onBack: () => context.pop(),
      children: const [
        _SigningNote(),
        SizedBox(height: EcoSpace.lg),
        FadeSlideIn(index: 0, child: _MemoQueue()),
        SizedBox(height: EcoSpace.xl),
        FadeSlideIn(index: 1, child: _TicketQueue()),
      ],
    );
  }
}

/// Reminds the officer that this page only routes them to the document.
class _SigningNote extends StatelessWidget {
  const _SigningNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.draw_rounded, size: 16, color: AppColors.forest),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Signing happens on the document itself — open a record to '
              'review it before you sign.',
              style: EcoType.bodySmall(context, color: AppColors.forest),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoQueue extends StatelessWidget {
  const _MemoQueue();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Memo>>(
      stream: MemoService().watchForChannel('cityHall'),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final pending = (snapshot.data ?? const <Memo>[])
            .where((memo) => !memo.isSigned)
            .toList(growable: false);

        return _QueueSection(
          icon: Icons.mail_outline_rounded,
          title: 'Memos for City Hall',
          subtitle:
              'Endorsements and memos the barangay and ISWIM sent for acknowledgement.',
          count: loading ? null : pending.length,
          loading: loading,
          error: snapshot.error,
          emptyTitle: 'No memo is waiting for a signature',
          emptyMessage:
              'Memos addressed to City Hall stay in this queue until they are '
              'acknowledged.',
          children: [for (final memo in pending) MemoCard(memo: memo)],
        );
      },
    );
  }
}

class _TicketQueue extends StatelessWidget {
  const _TicketQueue();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripTicket>>(
      stream: TicketService().watchAll(),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final pending = (snapshot.data ?? const <TripTicket>[])
            .where(
              (ticket) =>
                  ticket.status == TicketStatus.iswimSigned ||
                  ticket.approvalPending,
            )
            .toList(growable: false);

        return _QueueSection(
          icon: Icons.local_shipping_outlined,
          title: 'Trip tickets for final signature',
          subtitle: 'Tickets ISWIM has verified and the fleet has completed.',
          count: loading ? null : pending.length,
          loading: loading,
          error: snapshot.error,
          emptyTitle: 'No ticket is waiting for a signature',
          emptyMessage:
              'Tickets arrive here once ISWIM signs them and the crew closes '
              'the trip.',
          children: [
            for (final ticket in pending)
              TicketCard(
                ticket: ticket,
                trailingLabel: 'Your signature',
                onTap: () => context.push('/tickets/${ticket.id}'),
              ),
          ],
        );
      },
    );
  }
}

/// One half of the queue: a titled header with a live count, then the cards,
/// a skeleton while the stream warms up, or an explanation when it is empty.
class _QueueSection extends StatelessWidget {
  const _QueueSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.loading,
    required this.error,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? count;
  final bool loading;
  final Object? error;
  final String emptyTitle;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeskSectionHeader(
          icon: icon,
          title: title,
          subtitle: subtitle,
          count: count != null && count! > 0 ? count : null,
        ),
        const SizedBox(height: EcoSpace.sm),
        if (error != null)
          EcoBanner(
            message: AppFeedback.describe(error!),
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
          )
        else if (loading)
          const _QueueSkeleton()
        else if (children.isEmpty)
          EmptyState(
            icon: icon,
            title: emptyTitle,
            message: emptyMessage,
            compact: true,
          )
        else
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 58, height: 15, radius: 7),
                    SizedBox(width: 8),
                    SkeletonBox(width: 44, height: 15, radius: 7),
                  ],
                ),
                SizedBox(height: 11),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 132, height: 10, radius: 5),
              ],
            ),
          ),
          if (i == 0) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

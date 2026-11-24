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
import '../models/ticket_queue.dart';

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
        final entries = groupTicketsByManual(pending);

        return _QueueSection(
          icon: Icons.local_shipping_outlined,
          title: 'Trip tickets for final signature',
          subtitle:
              'Verified tickets. A collection manual appears once, and one '
              'signature covers every driver on it.',
          count: loading ? null : entries.length,
          loading: loading,
          error: snapshot.error,
          emptyTitle: 'No ticket is waiting for a signature',
          emptyMessage:
              'Tickets arrive here once ISWIM signs them and the crew closes '
              'the trip.',
          children: [
            for (final entry in entries)
              if (entry.isManual)
                _ManualSignatureCard(
                  entry: entry,
                  onTap: () => context.push('/tickets/${entry.lead.id}'),
                )
              else
                TicketCard(
                  ticket: entry.lead,
                  trailingLabel: 'Your signature',
                  onTap: () => context.push('/tickets/${entry.lead.id}'),
                ),
          ],
        );
      },
    );
  }
}

/// One card for a whole bulk manual.
///
/// The officer signs the manual, not each driver's page, so the card names the
/// roster instead of repeating the first driver's ticket: the plates, the
/// drivers it covers, and a reminder that one signature closes all of them.
class _ManualSignatureCard extends StatelessWidget {
  const _ManualSignatureCard({required this.entry, this.onTap});

  final TicketQueueEntry entry;
  final VoidCallback? onTap;

  String _join(List<String> values, {int limit = 3}) {
    final unique = <String>[];
    for (final value in values) {
      if (value.isEmpty || unique.contains(value)) continue;
      unique.add(value);
    }
    if (unique.length <= limit) return unique.join(', ');
    return '${unique.take(limit).join(', ')} +${unique.length - limit} more';
  }

  @override
  Widget build(BuildContext context) {
    final rows = entry.tickets;
    final lead = entry.lead;
    final plates = _join([
      for (final row in rows) row.plateNumber.trim(),
    ], limit: 2);
    final drivers = _join([
      for (final row in rows) row.driverName.trim(),
    ]);

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 13,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      'COLLECTION MANUAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${rows.length} drivers',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Your signature',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    size: 13,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      plates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${lead.routesLabel} · ${lead.scheduleLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                drivers,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.moss,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'One signature approves all ${rows.length} trip tickets.',
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.moss,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return HoverLift(child: card);
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

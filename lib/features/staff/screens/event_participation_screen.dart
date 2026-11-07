import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../events/models/community_event.dart';
import '../../events/models/event_participant.dart';
import '../../events/services/event_service.dart';

/// Staff view of event sign-ups.
///
/// Two questions this answers: who is coming to each event, and which street
/// turns up the most — the street ranking doubles as the point system, since a
/// street's score is simply its total attendance across every event.
class EventParticipationScreen extends StatefulWidget {
  const EventParticipationScreen({super.key});

  @override
  State<EventParticipationScreen> createState() =>
      _EventParticipationScreenState();
}

class _EventParticipationScreenState extends State<EventParticipationScreen> {
  final _service = EventService();
  late Future<ParticipationOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.loadParticipationOverview();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.loadParticipationOverview());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Event participation',
              subtitle: 'Who is coming, and which street shows up most.',
              onBack: () => context.go('/admin-dashboard'),
              actions: [
                IconButton(
                  onPressed: _reload,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<ParticipationOverview>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(label: 'Counting sign-ups');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: AppFeedback.describe(snapshot.error!),
                    );
                  }
                  final data = snapshot.data;
                  if (data == null || data.totalSignUps == 0) {
                    return const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No sign-ups yet',
                      message:
                          'When residents tap "Join this event", their street '
                          'shows up here and starts earning points.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                    children: [
                      _StreetRanking(standings: data.standings),
                      const SizedBox(height: 22),
                      const _SectionLabel('PER EVENT'),
                      const SizedBox(height: 10),
                      for (final event in data.events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EventRow(
                            event: event,
                            count: data.countFor(event.id),
                            onTap: () => _openRoster(event),
                          ),
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

  Future<void> _openRoster(CommunityEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventRosterSheet(event: event),
    );
    if (mounted) await _reload();
  }
}

/// Leaderboard of streets, best first.
class _StreetRanking extends StatelessWidget {
  const _StreetRanking({required this.standings});

  final List<StreetStanding> standings;

  @override
  Widget build(BuildContext context) {
    final top = standings.take(8).toList();
    final maxPoints = top.isEmpty ? 1 : top.first.points;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('STREET RANKING'),
        const SizedBox(height: 10),
        EcoCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Points come from event attendance — every sign-up is worth '
                '10 points for that street.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < top.length; i++)
                _StandingRow(
                  rank: i + 1,
                  standing: top[i],
                  maxPoints: maxPoints,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.standing,
    required this.maxPoints,
  });

  final int rank;
  final StreetStanding standing;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final leading = rank == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: leading ? AppColors.primary : AppColors.sage,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: leading ? Colors.white : AppColors.darkGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${standing.residents} '
                  '${standing.residents == 1 ? 'resident' : 'residents'} · '
                  '${standing.events} '
                  '${standing.events == 1 ? 'event' : 'events'}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: standing.points / maxPoints,
                    minHeight: 5,
                    backgroundColor: AppColors.sage,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      leading ? AppColors.primary : AppColors.lightGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${standing.points}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
              const Text(
                'pts',
                style: TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.count,
    required this.onTap,
  });

  final CommunityEvent event;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: event.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(event.category.icon,
                size: 18, color: event.category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateTimeLabel(event.startAt),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: count == 0 ? 'No one yet' : '$count going',
            color: count == 0 ? AppColors.inkMuted : AppColors.primary,
            icon: Icons.groups_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}

/// Full roster for one event, grouped by street.
class _EventRosterSheet extends StatelessWidget {
  const _EventRosterSheet({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => StreamBuilder<List<EventParticipant>>(
        stream: EventService().watchParticipants(event.id),
        builder: (context, snapshot) {
          final list = snapshot.data ?? const <EventParticipant>[];
          final grouped = <String, List<EventParticipant>>{};
          for (final person in list) {
            final key = person.streetKey.isEmpty ? '_none' : person.streetKey;
            grouped.putIfAbsent(key, () => []).add(person);
          }
          final streets = grouped.keys.toList()
            ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));

          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${list.length} '
                '${list.length == 1 ? 'resident signed up' : 'residents signed up'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              if (list.isEmpty)
                const Text(
                  'Nobody has signed up yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
              for (final key in streets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          key == '_none'
                              ? 'Street not set'
                              : grouped[key]!.first.streetLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ),
                      Text(
                        '${grouped[key]!.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final person in grouped[key]!)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 6),
                    child: Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w800,
        color: AppColors.inkMuted,
      ),
    );
  }
}

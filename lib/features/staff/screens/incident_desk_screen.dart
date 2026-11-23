import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../incident/models/incident.dart';
import '../../incident/services/incident_service.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class IncidentDeskScreen extends StatefulWidget {
  const IncidentDeskScreen({super.key});

  @override
  State<IncidentDeskScreen> createState() => _IncidentDeskScreenState();
}

class _IncidentDeskScreenState extends State<IncidentDeskScreen> {
  final _service = IncidentService();
  final _search = TextEditingController();
  late final Stream<List<Incident>> _stream;
  String _query = '';
  IncidentStatus? _status;
  int _page = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Incident> _filter(List<Incident> incidents) {
    final q = _query.trim().toLowerCase();
    return incidents.where((i) {
      if (_status != null && i.status != _status) return false;
      if (q.isEmpty) return true;
      return i.category.label.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.residentName.toLowerCase().contains(q) ||
          i.status.label.toLowerCase().contains(q);
    }).toList();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _status = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role;
    final isCityHall = role == UserRole.cityHall;
    final home = isCityHall ? '/cityhall' : '/admin-dashboard';

    return EcoPageScaffold(
      eyebrow: isCityHall
          ? 'CITY HALL · INCIDENT DESK'
          : 'BARANGAY STAFF · INCIDENT DESK',
      title: 'Incident desk',
      subtitle:
          'Reports submitted by residents, newest first. Resolve one and the '
          'resident sees the change on their own report.',
      onBack: () => ecoBack(context, home),
      body: StreamBuilder<List<Incident>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load reports',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading reports');
          }

          final all = snapshot.data!;
          final incidents = _filter(all);
          final page = clampPage(_page, incidents.length, _pageSize);
          final visible = pageSlice(incidents, page, _pageSize);
          final pending = all
              .where((i) => i.status == IncidentStatus.pending)
              .length;
          final resolved = all.length - pending;
          final filtered = _query.trim().isNotEmpty || _status != null;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: Icons.warning_amber_rounded,
                label: 'Pending',
                value: '$pending',
                accent: AppColors.warning,
                highlight: pending > 0,
              ),
              DeskMetric(
                icon: Icons.check_circle_outline_rounded,
                label: 'Resolved',
                value: '$resolved',
              ),
              DeskMetric(
                icon: Icons.report_outlined,
                label: 'Total',
                value: '${all.length}',
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search type, place or reporter',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<IncidentStatus?>(
              value: _status,
              onChanged: (value) => setState(() {
                _status = value;
                _page = 0;
              }),
              segments: [
                DeskSegment(value: null, label: 'All', count: all.length),
                DeskSegment(
                  value: IncidentStatus.pending,
                  label: 'Pending',
                  count: pending,
                ),
                DeskSegment(
                  value: IncidentStatus.resolved,
                  label: 'Resolved',
                  count: resolved,
                ),
              ],
            ),
            resultLine: DeskResultLine(
              label: filtered
                  ? 'Showing ${incidents.length} of ${all.length} reports'
                  : '${all.length} '
                        '${all.length == 1 ? 'report' : 'reports'}',
              onClear: filtered ? _clear : null,
            ),
            empty: all.isEmpty
                ? const DeskEmptyQueue(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No reports yet',
                    message:
                        'Resident reports appear here in real time. An '
                        'empty desk means nothing has been filed.',
                    steps: [
                      'Resident submits a report',
                      'The desk reviews it',
                      'Resolving it closes the report',
                    ],
                  )
                : DeskEmptyQueue(
                    icon: Icons.search_off_rounded,
                    title: 'No report matches',
                    message:
                        'Try another type, place or reporter, or clear the '
                        'status filter.',
                    actionLabel: 'Clear filters',
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: _clear,
                  ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _IncidentTile(
              incident: visible[i],
              onResolve: () => _resolve(visible[i]),
            ),
            pagination: incidents.isEmpty
                ? null
                : EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: incidents.length,
                    onPageChanged: (next) => setState(() => _page = next),
                    onPageSizeChanged: (size) => setState(() {
                      _pageSize = size;
                      _page = 0;
                    }),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _resolve(Incident incident) async {
    await _service.updateStatus(incident.id, IncidentStatus.resolved);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Report marked as resolved')),
      );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident, required this.onResolve});

  final Incident incident;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final pending = incident.status == IncidentStatus.pending;
    final accent = pending ? AppColors.warning : AppColors.primary;

    return DeskRailCard(
      railColor: accent,
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                incident.category.icon,
                size: 13,
                color: pending ? const Color(0xFFB26A00) : accent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  incident.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.eyebrow(
                    context,
                    color: pending ? const Color(0xFFB26A00) : AppColors.moss,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: incident.status.label,
                color: incident.status.color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          // The report itself is the headline: it is what the desk reads and
          // acts on, not the category the resident picked.
          Text(
            incident.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DeskInitialAvatar(name: incident.residentName, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${incident.residentName} · '
                  '${timeAgo(incident.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              if (incident.latitude != null && incident.longitude != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                    border: Border.all(
                      color: AppColors.sage.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 10,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${incident.latitude!.toStringAsFixed(4)}, '
                        '${incident.longitude!.toStringAsFixed(4)}',
                        style: EcoType.meta(
                          context,
                          color: AppColors.inkMuted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: EcoSpace.sm),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.task_alt_rounded, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EcoRadius.sm),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                label: const Text('Mark as resolved'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

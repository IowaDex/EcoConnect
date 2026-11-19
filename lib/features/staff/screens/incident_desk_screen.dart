import 'package:flutter/material.dart';

import '../../incident/models/incident.dart';
import '../../incident/services/incident_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';

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
    if (q.isEmpty) return incidents;
    return incidents.where((i) {
      return i.category.label.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.residentName.toLowerCase().contains(q) ||
          i.status.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return EcoPageScaffold(
      eyebrow: 'BARANGAY STAFF · INCIDENT DESK',
      title: 'Incident desk',
      subtitle: 'Reports submitted by residents, newest first.',
      onBack: () => ecoBack(context, '/admin-dashboard'),
      body: StreamBuilder<List<Incident>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load reports: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.danger),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const EcoLoadingView(label: 'Loading reports');
          }
          final all = snapshot.data!;
          if (all.isEmpty) {
            return const _EmptyState();
          }
          final incidents = _filter(all);
          final page = clampPage(_page, incidents.length, _pageSize);
          final visible = pageSlice(incidents, page, _pageSize);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: EcoSearchField(
                  controller: _search,
                  hint: 'Search type, place or reporter',
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 0;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: EcoResultCount(
                  shown: incidents.length,
                  total: all.length,
                  singular: 'report',
                  plural: 'reports',
                ),
              ),
              Expanded(
                child: incidents.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No report matches your search.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _IncidentTile(
                          incident: visible[i],
                          onResolve: () => _resolve(visible[i]),
                        ),
                      ),
              ),
              if (incidents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: EcoPaginationBar(
                    page: page,
                    pageSize: _pageSize,
                    total: incidents.length,
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
    return EcoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  incident.category.icon,
                  size: 16,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.residentName} · ${_ago(incident.createdAt)}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: incident.status.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: incident.status.color.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  incident.status.label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: incident.status.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            incident.description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.forest,
            ),
          ),
          if (incident.latitude != null && incident.longitude != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 12,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${incident.latitude!.toStringAsFixed(5)}, '
                  '${incident.longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ],
          if (incident.status == IncidentStatus.pending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: onResolve,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.forest),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Mark as resolved'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime? time) {
    if (time == null) return 'just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.inbox_rounded,
      title: 'No reports yet',
      message: 'Resident reports will appear here in real time.',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/incident.dart';
import '../../../core/services/incident_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';

class IncidentDeskScreen extends StatefulWidget {
  const IncidentDeskScreen({super.key});

  @override
  State<IncidentDeskScreen> createState() => _IncidentDeskScreenState();
}

class _IncidentDeskScreenState extends State<IncidentDeskScreen> {
  final _service = IncidentService();
  late final Stream<List<Incident>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.forest),
                    onPressed: () => context.go('/admin-dashboard'),
                  ),
                  const SizedBox(width: 10),
                  const BrandWordmark(fontSize: 10.5),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 0),
              child: Text(
                'Incident desk',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 14),
              child: Text(
                'Reports submitted by residents, newest first.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Incident>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load reports: ' + snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.danger),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final incidents = snapshot.data!;
                  if (incidents.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _IncidentTile(
                      incident: incidents[i],
                      onResolve: () => _resolve(incidents[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(Incident incident) async {
    await _service.updateStatus(incident.id, IncidentStatus.resolved);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Report marked as resolved')));
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident, required this.onResolve});

  final Incident incident;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
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
                child: Icon(incident.category.icon,
                    size: 16, color: AppColors.forest),
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
                      incident.residentName + ' · ' + _ago(incident.createdAt),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: incident.status.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: incident.status.color.withValues(alpha: 0.6)),
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
          if (incident.latitude != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text(
                  incident.latitude!.toStringAsFixed(5) +
                      ', ' +
                      incident.longitude!.toStringAsFixed(5),
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.inkMuted),
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
                      fontSize: 11, fontWeight: FontWeight.w600),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 44, color: AppColors.sage),
            SizedBox(height: 12),
            Text(
              'No reports yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Resident reports will appear here in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

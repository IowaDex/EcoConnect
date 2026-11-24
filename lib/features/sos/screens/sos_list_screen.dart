import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sos_incident.dart';
import '../services/sos_service.dart';

/// The SOS board. City Hall sees every incident it sent; a District Officer
/// sees only the incidents for their district; the barangay sees its own.
class SosListScreen extends StatefulWidget {
  const SosListScreen({super.key});

  @override
  State<SosListScreen> createState() => _SosListScreenState();
}

enum _SosFilter { all, open, resolved }

class _SosListScreenState extends State<SosListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _SosFilter _filter = _SosFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<List<SosIncident>> _streamFor(UserRole role, AppUser? user) {
    final service = SosService();
    return switch (role) {
      UserRole.cityHall => service.watchAll(),
      UserRole.districtOfficer => service.watchForOfficer(
        uid: user?.uid ?? '',
        district: user?.district,
      ),
      UserRole.admin => (user?.barangay ?? '').trim().isEmpty
          ? service.watchAll()
          : service.watchForBarangay((user?.barangay ?? '').trim()),
      _ => const Stream<List<SosIncident>>.empty(),
    };
  }

  List<SosIncident> _filtered(List<SosIncident> items) {
    final query = _query.trim().toLowerCase();
    return items.where((incident) {
      if (_filter == _SosFilter.open && !incident.isOpen) return false;
      if (_filter == _SosFilter.resolved && incident.isOpen) return false;
      if (query.isEmpty) return true;
      return incident.code.toLowerCase().contains(query) ||
          incident.description.toLowerCase().contains(query) ||
          incident.reason.toLowerCase().contains(query) ||
          incident.barangay.toLowerCase().contains(query) ||
          incident.district.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final role = user?.role ?? UserRole.user;
    final cityHall = role == UserRole.cityHall;
    final officer = role == UserRole.districtOfficer;

    return EcoPageScaffold(
      eyebrow: cityHall
          ? 'CITY HALL · SOS INCIDENTS'
          : officer
          ? 'DISTRICT OFFICER · SOS'
          : 'BARANGAY · SOS',
      title: 'SOS incidents',
      subtitle: cityHall
          ? 'Every garbage-truck incident DSQC has sent, with the coordination '
                'status the District Officer records.'
          : officer
          ? 'Incidents for ${user?.district ?? 'your district'}. Open one to '
                'coordinate with the affected barangay.'
          : 'Incidents reported for this barangay.',
      icon: Icons.sos_rounded,
      onBack: () => ecoBack(
        context,
        cityHall
            ? '/cityhall'
            : officer
            ? '/district-officer'
            : '/admin-dashboard',
      ),
      fab: cityHall
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/sos/new'),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert_rounded, size: 19),
              label: const Text(
                'New SOS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: StreamBuilder<List<SosIncident>>(
        stream: _streamFor(role, user),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load the SOS board.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forest,
                strokeWidth: 2,
              ),
            );
          }
          final all = snapshot.data ?? const <SosIncident>[];
          final items = _filtered(all);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              _Metrics(items: all),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search code, reason, barangay',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                children: [
                  _Chip(
                    label: 'All',
                    count: all.length,
                    selected: _filter == _SosFilter.all,
                    onTap: () => setState(() => _filter = _SosFilter.all),
                  ),
                  _Chip(
                    label: 'Open',
                    count: all.where((i) => i.isOpen).length,
                    selected: _filter == _SosFilter.open,
                    onTap: () => setState(() => _filter = _SosFilter.open),
                  ),
                  _Chip(
                    label: 'Resolved',
                    count: all.where((i) => !i.isOpen).length,
                    selected: _filter == _SosFilter.resolved,
                    onTap: () => setState(() => _filter = _SosFilter.resolved),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (all.isEmpty)
                _Message(
                  icon: Icons.sos_outlined,
                  text: cityHall
                      ? 'No SOS has been sent yet.\nTap "New SOS" when ISWIM '
                            'reports a truck problem.'
                      : 'No SOS incident is on your desk.',
                )
              else if (items.isEmpty)
                const _Message(
                  icon: Icons.search_off_rounded,
                  text: 'No incident matches this search or filter.',
                )
              else
                for (final incident in items) ...[
                  _SosTile(incident: incident),
                  const SizedBox(height: 9),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.items});

  final List<SosIncident> items;

  @override
  Widget build(BuildContext context) {
    final open = items.where((i) => i.isOpen).length;
    final waiting = items
        .where(
          (i) =>
              i.status == SosStatus.newAlert ||
              i.status == SosStatus.acknowledged,
        )
        .length;
    final resolved = items.where((i) => !i.isOpen).length;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Open',
            value: '$open',
            icon: Icons.sos_rounded,
            tone: AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'Awaiting ack',
            value: '$waiting',
            icon: Icons.hourglass_top_rounded,
            tone: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Metric(
            label: 'Resolved',
            value: '$resolved',
            icon: Icons.task_alt_rounded,
            tone: AppColors.forest,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sage,
          ),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _SosTile extends StatelessWidget {
  const _SosTile({required this.incident});

  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final status = incident.status;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/sos/${incident.id}'),
        borderRadius: BorderRadius.circular(EcoRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EcoRadius.md),
            border: Border.all(
              color: incident.isOpen
                  ? status.color.withValues(alpha: 0.55)
                  : AppColors.sage,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(status.icon, size: 11, color: status.color),
                        const SizedBox(width: 4),
                        Text(
                          incident.code,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo(incident.createdAt),
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                incident.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 12,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incident.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  if (incident.isUnassigned)
                    const Text(
                      'NO OFFICER',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Container(
                    height: 7,
                    width: 7,
                    decoration: BoxDecoration(
                      color: status.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: status.color,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.inkMuted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

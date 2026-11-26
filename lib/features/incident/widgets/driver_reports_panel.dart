import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/driver_incident.dart';
import '../services/driver_incident_service.dart';

/// The reports crews filed from the truck, shown on the Iswim delay desk.
///
/// Iswim is the only desk that acts on them: acknowledge the report, then file
/// the formal delay report if the round really is late. The strip disappears
/// when nothing is waiting.
class DriverReportsPanel extends StatefulWidget {
  const DriverReportsPanel({super.key});

  @override
  State<DriverReportsPanel> createState() => _DriverReportsPanelState();
}

class _DriverReportsPanelState extends State<DriverReportsPanel> {
  /// Built once: this panel sits inside a page that rebuilds on every delay
  /// snapshot, and a stream created in `build` would reopen the listener each
  /// time.
  late final Stream<List<DriverIncident>> _stream = DriverIncidentService()
      .watchOpen();

  String? _busyId;

  Future<void> _acknowledge(DriverIncident incident) async {
    final user = context.read<AuthProvider>().currentUser;
    setState(() => _busyId = incident.id);
    try {
      await DriverIncidentService().acknowledge(
        incident.id,
        byName: user?.displayName ?? 'Iswim',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not acknowledge the report.'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverIncident>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <DriverIncident>[];
        if (items.isEmpty) return const SizedBox.shrink();

        final shown = items.take(3).toList(growable: false);
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF4E4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'DRIVER REPORTS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length} waiting',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final incident in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        incident.kind.icon,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${incident.kind.label} · '
                              '${incident.plateNumber.isEmpty ? 'No plate' : incident.plateNumber}'
                              '${incident.createdAt == null ? '' : ' · ${timeAgo(incident.createdAt)}'}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${incident.driverName}: ${incident.description}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                height: 1.4,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _busyId == incident.id
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              onPressed: () => _acknowledge(incident),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              color: AppColors.forest,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minHeight: 28,
                                minWidth: 28,
                              ),
                              tooltip: 'Mark as seen',
                            ),
                    ],
                  ),
                ),
              if (items.length > shown.length)
                Text(
                  'and ${items.length - shown.length} more on the crew reports',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

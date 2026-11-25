import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../tickets/models/trip_ticket.dart';
import '../data/manual_areas.dart';
import '../models/manual_assignment.dart';
import 'manual_route_map.dart';

/// A read-only look at a collection manual.
///
/// The same sheet is opened while the manual is being built and again after it
/// has been submitted, so the officer can check the roster, the week and the
/// streets without reopening the editor.
class ManualPreviewSheet extends StatelessWidget {
  const ManualPreviewSheet({
    super.key,
    required this.title,
    required this.assignments,
    this.statusLabel,
    this.statusColor,
    this.reason,
    this.note,
  });

  final String title;
  final List<ManualAssignment> assignments;
  final String? statusLabel;
  final Color? statusColor;

  /// City Hall's rejection reason, when the manual came back.
  final String? reason;

  /// A quiet line under the title, e.g. "Resubmitted after rejection".
  final String? note;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<ManualAssignment> assignments,
    String? statusLabel,
    Color? statusColor,
    String? reason,
    String? note,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualPreviewSheet(
        title: title,
        assignments: assignments,
        statusLabel: statusLabel,
        statusColor: statusColor,
        reason: reason,
        note: note,
      ),
    );
  }

  static const _letterColors = <Color>[
    Color(0xFF2E7D32),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
    Color(0xFFF9A825),
    Color(0xFF6D4C41),
  ];

  static Color _letterColor(int index) =>
      _letterColors[index % _letterColors.length];

  static String _letter(int index) =>
      String.fromCharCode('A'.codeUnitAt(0) + (index % 26));

  static String _clockLabel(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} '
        '${hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.trim().isEmpty ? 'Collection manual' : title;
    final accent = statusColor ?? AppColors.warning;
    final rejection = (reason ?? '').trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANUAL PREVIEW',
                        style: EcoType.eyebrow(
                          context,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cleanTitle,
                        style: EcoType.panelTitle(
                          context,
                          color: AppColors.forest,
                        ),
                      ),
                      if ((note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note!.trim(),
                          style: EcoType.meta(
                            context,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusLabel!,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (rejection.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Rejected by City Hall: $rejection',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _SectionLabel('ASSIGNMENTS (${assignments.length})'),
                const SizedBox(height: 7),
                if (assignments.isEmpty)
                  const Text(
                    'No driver has been added yet.',
                    style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                  )
                else
                  for (var i = 0; i < assignments.length; i++) ...[
                    _PreviewRow(index: i, assignment: assignments[i]),
                    if (i < assignments.length - 1) const SizedBox(height: 7),
                  ],
                const SizedBox(height: 16),
                const _SectionLabel('WEEK AT A GLANCE'),
                const SizedBox(height: 7),
                _PreviewWeek(assignments: assignments),
                if (assignments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionLabel('ROUTE MAP'),
                  const SizedBox(height: 7),
                  ManualRouteMap(
                    height: 200,
                    groups: [
                      for (var i = 0; i < assignments.length; i++)
                        ManualRouteGroup(
                          areas: manualAreasFor(assignments[i].routes),
                          color: _letterColor(i),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.index, required this.assignment});

  final int index;
  final ManualAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final days = [...assignment.days]..sort();
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ManualPreviewSheet._letterColor(index),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  ManualPreviewSheet._letter(index),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  assignment.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Text(
                  assignment.plateNumber,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${days.map(manualDayLabel).join(' · ')} · '
            '${assignment.startTime} · ${assignment.recurrence.label}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            assignment.hasDayRoutes
                ? assignment.dayRoutesLabel
                : (assignment.routesLabel.isEmpty
                      ? 'No area picked'
                      : assignment.routesLabel),
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Valid until '
            '${dateLabel(
              manualValidUntil(
                recurrence: assignment.recurrence,
                from: DateTime.now(),
              ),
            )}',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.moss,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact Mon–Sun grid: one row per start time, a letter per driver.
class _PreviewWeek extends StatelessWidget {
  const _PreviewWeek({required this.assignments});

  final List<ManualAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final times = <String>{for (final row in assignments) row.startTime};
    final rows = times.isEmpty ? const ['08:00'] : (times.toList()..sort());
    final cells = <String, List<int>>{};
    for (var i = 0; i < assignments.length; i++) {
      for (final day in assignments[i].days) {
        (cells['$day-${assignments[i].startTime}'] ??= <int>[]).add(i);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 40),
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Center(
                    child: Text(
                      manualDayLabel(day),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final time in rows) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    ManualPreviewSheet._clockLabel(time),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: Center(
                      child: _marks(cells['$day-$time'] ?? const []),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _marks(List<int> indexes) {
    if (indexes.isEmpty) {
      return Container(
        height: 16,
        width: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sage),
        ),
      );
    }
    final shown = indexes.length <= 3 ? indexes : indexes.take(2).toList();
    final hidden = indexes.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final index in shown)
          Container(
            height: 16,
            width: 16,
            margin: const EdgeInsets.only(right: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ManualPreviewSheet._letterColor(index),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              ManualPreviewSheet._letter(index),
              style: const TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        if (hidden > 0)
          Text(
            '+$hidden',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.moss,
            ),
          ),
      ],
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
      style: EcoType.eyebrow(context, color: AppColors.inkMuted),
    );
  }
}

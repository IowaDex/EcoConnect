import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_header.dart';
import '../models/assignment_manual.dart';
import '../services/assignment_manual_service.dart';

/// The barangay's copy of the schedules City Hall has approved.
///
/// Only approved manuals are read here, so the desk never sees a draft. Each
/// tile is the paperwork the barangay needs: driver, plate, streets, days and
/// the start time. Nothing on it is a button — it is a copy to read.
class ApprovedManualsSection extends StatelessWidget {
  const ApprovedManualsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AssignmentManual>>(
      stream: AssignmentManualService().watchApproved(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AssignmentManual>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              'COLLECTION MANUALS',
              action: 'Schedules',
              onAction: () => context.push('/assignments'),
            ),
            const SizedBox(height: EcoSpace.xs),
            const Text(
              'Approved by City Hall — the barangay copy of the roster.',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: EcoSpace.sm),
            if (snapshot.connectionState == ConnectionState.waiting &&
                items.isEmpty)
              const LinearProgressIndicator(minHeight: 2)
            else if (items.isEmpty)
              const Text(
                'No approved schedule yet. City Hall signs the manual Iswim '
                'submits, and it appears here.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                _ApprovedManualTile(manual: items[i]),
                if (i < items.length - 1) const SizedBox(height: EcoSpace.sm),
              ],
          ],
        );
      },
    );
  }
}

class _ApprovedManualTile extends StatelessWidget {
  const _ApprovedManualTile({required this.manual});

  final AssignmentManual manual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                size: 15,
                color: AppColors.forest,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  manual.driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
              Text(
                manual.plateNumber,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            manual.routesLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${manual.scheduleLabel} · approved '
            '${timeAgo(manual.approvedAt ?? manual.updatedAt)}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

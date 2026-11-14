import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/trip_ticket.dart';
import '../../../core/widgets/motion.dart';

/// Compact row for ticket lists: code, plate, driver, route and where it is.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    this.onTap,
    this.trailingLabel,
  });

  final TripTicket ticket;
  final VoidCallback? onTap;

  /// Overrides the status text, e.g. "Action needed".
  final String? trailingLabel;

  Color get _statusColor => switch (ticket.status) {
        TicketStatus.completed => AppColors.primary,
        TicketStatus.missed || TicketStatus.cancelled => AppColors.error,
        TicketStatus.declined => AppColors.warning,
        TicketStatus.issued => AppColors.warning,
        TicketStatus.accepted || TicketStatus.running => AppColors.moss,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final label = trailingLabel ?? ticket.status.label;
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
                  Text(
                    ticket.code,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ticket.waveLabel,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      size: 13, color: AppColors.forest),
                  const SizedBox(width: 4),
                  Text(
                    ticket.plateNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '· ${ticket.wheelers}-wheeler',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ticket.driverName,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.moss,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${ticket.route} · ${ticket.zone}',
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
      ),
    );

    return HoverLift(child: card);
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../route/models/collection_route.dart';
import '../models/garbage_truck.dart';
import '../models/truck_crew_role.dart';
import '../models/truck_status.dart';
import '../services/trip_guard_service.dart';

/// The card the crew sees first: which truck they are on, who is riding with
/// them, whether the trip is running, and the trip controls.
///
/// It also carries the trip guard read-out, so the 100 m radius and the
/// connection state are visible without scrolling.
class TruckTripHeader extends StatelessWidget {
  const TruckTripHeader({
    super.key,
    required this.truck,
    required this.role,
    required this.status,
    required this.startedAt,
    required this.busy,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
    this.canStart = true,
    this.metresFromCenter,
    this.connectionLost = false,
  });

  final GarbageTruck truck;
  final TruckCrewRole role;
  final RouteStatus status;
  final DateTime? startedAt;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  /// False until a trip ticket exists: without one there is no trip to start,
  /// so the button stays inert instead of failing on tap.
  final bool canStart;

  /// Distance from the zone centre while the trip is running.
  final double? metresFromCenter;

  /// True while the phone has no wifi/data during a running trip.
  final bool connectionLost;

  bool get _isLive =>
      status == RouteStatus.inTransit || status == RouteStatus.delayed;

  bool get _isPaused => status == RouteStatus.paused;

  bool get _isRunning => _isLive || _isPaused;

  bool get _outsideRadius => metresFromCenter != null &&
      TripGuardService.isOutsideRadius(metresFromCenter!);

  String get _elapsed {
    final started = startedAt;
    if (started == null) return '';
    final duration = DateTime.now().difference(started);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '$minutes min' : '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    // Without a ticket the truck is not ready, whatever the route says.
    final badge = _isRunning
        ? (
            label: status.label,
            color: _isPaused || status == RouteStatus.delayed
                ? AppColors.warning
                : AppColors.forest,
            background: _isPaused || status == RouteStatus.delayed
                ? const Color(0xFFFDF4E4)
                : const Color(0xFFE8F3E7),
            icon: Icons.navigation_rounded,
          )
        : canStart
            ? (
                label: TruckStatus.ticketReady.label,
                color: TruckStatus.ticketReady.color,
                background: TruckStatus.ticketReady.background,
                icon: null,
              )
            : (
                label: TruckStatus.noTicket.label,
                color: TruckStatus.noTicket.color,
                background: TruckStatus.noTicket.background,
                icon: Icons.confirmation_number_outlined,
              );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EDE4)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(
                label: badge.label,
                color: badge.color,
                background: badge.background,
                icon: badge.icon,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned truck',
                      style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      truck.plateNumber,
                      style: const TextStyle(
                        fontSize: 27,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${truck.description} · ${truck.zone}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 26,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2ED)),
          const SizedBox(height: 13),
          const Text(
            'CREW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 11),
          _CrewRow(
            name: truck.hasDriver ? truck.driverName : 'No driver assigned',
            role: 'Driver',
            icon: Icons.person_rounded,
            trailing: _isRunning ? status.label : 'Trip not started',
            muted: true,
          ),
          const SizedBox(height: 11),
          _CrewRow(
            name: 'You',
            role: role.shortLabel,
            icon: role.icon,
            trailing: _isRunning ? 'On board' : 'Waiting',
            muted: true,
          ),
          if (_isRunning) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _isPaused ? 'Paused' : 'Running',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                if (startedAt != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    _elapsed,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  metresFromCenter == null
                      ? 'Locating…'
                      : '${metresFromCenter!.round()} m from centre',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _outsideRadius
                        ? AppColors.warning
                        : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _GuardLine(
              connectionLost: connectionLost,
              outsideRadius: _outsideRadius,
              metres: metresFromCenter,
            ),
          ],
          const SizedBox(height: 16),
          if (_isRunning)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: busy ? null : (_isPaused ? onResume : onPause),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isPaused
                            ? AppColors.forest
                            : const Color(0xFFF1F5F1),
                        foregroundColor: _isPaused
                            ? Colors.white
                            : AppColors.forest,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          Text(_isPaused ? 'Resume trip' : 'Pause trip'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: busy ? null : onEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        side: const BorderSide(color: AppColors.sage),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('End trip'),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 48,
              child: FilledButton(
                // Tappable even without a ticket: the tap is what explains the
                // gate. It just paints itself as inert.
                onPressed: busy ? null : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: canStart
                      ? AppColors.forest
                      : const Color(0xFFE8EEE8),
                  foregroundColor: canStart ? Colors.white : const Color(0xFF9AA79D),
                  disabledBackgroundColor: const Color(0xFFE8EEE8),
                  disabledForegroundColor: const Color(0xFF9AA79D),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.forest,
                        ),
                      )
                    else
                      Icon(
                        canStart ? Icons.play_arrow_rounded : Icons.lock_rounded,
                        size: 18,
                      ),
                    const SizedBox(width: 7),
                    Text(busy ? 'Starting…' : 'Start trip'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The status chip at the top of the card: a dot or an icon, then the label.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else
            Container(
              height: 7,
              width: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the crew list: who it is, what they do, and where they are at.
class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.name,
    required this.role,
    required this.icon,
    required this.trailing,
    this.muted = false,
  });

  final String name;
  final String role;
  final IconData icon;
  final String trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: const BoxDecoration(
            color: AppColors.forest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                role,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            trailing,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.inkMuted : AppColors.forest,
            ),
          ),
        ),
      ],
    );
  }
}

/// One line that says whether the trip is inside both rules right now.
class _GuardLine extends StatelessWidget {
  const _GuardLine({
    required this.connectionLost,
    required this.outsideRadius,
    required this.metres,
  });

  final bool connectionLost;
  final bool outsideRadius;
  final double? metres;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch ((connectionLost, outsideRadius)) {
      (true, true) => (
          AppColors.error,
          Icons.wifi_off_rounded,
          'Offline and outside the radius — barangay has been alerted.',
        ),
      (true, false) => (
          AppColors.error,
          Icons.wifi_off_rounded,
          'No wifi/data — the truck is off the live map.',
        ),
      (false, true) => (
          AppColors.warning,
          Icons.wrong_location_rounded,
          '${metres?.round() ?? ''} m from the zone centre — past the '
              '${TripGuardService.radiusMeters.round()} m limit.',
        ),
      (false, false) => (
          AppColors.forest,
          Icons.verified_rounded,
          'Online and inside the ${TripGuardService.radiusMeters.round()} m '
              'radius.',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

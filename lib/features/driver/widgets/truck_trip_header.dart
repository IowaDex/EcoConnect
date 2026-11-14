import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../route/models/collection_route.dart';
import '../models/garbage_truck.dart';
import '../models/truck_crew_role.dart';
import '../services/trip_guard_service.dart';

/// The card the crew sees first: which truck they are on, whether the trip is
/// running, and the two trip controls (start / pause).
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
    required this.onChangeTruck,
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
  final VoidCallback onChangeTruck;

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
    final statusLabel = _isRunning ? status.label : 'Trip not started';
    final statusColor = _isRunning ? status.color : const Color(0xCCFFFFFF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.7)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(role.icon, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      role.label,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your truck',
                      style: TextStyle(fontSize: 9, color: Color(0xB3FFFFFF)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      truck.plateNumber,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${truck.description} · ${truck.zone}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xD9FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.local_shipping_rounded,
                size: 30,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                icon: Icons.settings_input_component_rounded,
                label: truck.wheelerLabel,
              ),
              const SizedBox(width: 14),
              _Metric(
                icon: Icons.my_location_rounded,
                label: _isRunning
                    ? (metresFromCenter == null
                        ? 'Locating…'
                        : '${metresFromCenter!.round()} m from centre')
                    : '${TripGuardService.radiusMeters.round()} m radius',
                alert: _isRunning && _outsideRadius,
              ),
              const Spacer(),
              if (_isRunning && startedAt != null)
                Text(
                  _isPaused ? 'Paused · $_elapsed' : 'Running $_elapsed',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _isPaused ? AppColors.warning : AppColors.lime,
                  ),
                ),
            ],
          ),
          if (_isRunning) ...[
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
                    height: 44,
                    child: FilledButton(
                      onPressed: busy ? null : (_isPaused ? onResume : onPause),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isPaused
                            ? AppColors.lime
                            : Colors.white.withValues(alpha: 0.16),
                        foregroundColor:
                            _isPaused ? AppColors.darkGreen : Colors.white,
                        side: _isPaused
                            ? null
                            : BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: busy ? null : onEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
              height: 46,
              child: FilledButton.icon(
                onPressed: busy ? null : onStart,
                icon: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.forest,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(busy ? 'Starting…' : 'Start trip'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isRunning ? null : onChangeTruck,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.85),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 26),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isRunning
                    ? 'End the trip to switch trucks'
                    : 'Switch truck',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.warning : const Color(0xCCFFFFFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: color,
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
          AppColors.lime,
          Icons.verified_rounded,
          'Online and inside the ${TripGuardService.radiusMeters.round()} m '
              'radius.',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
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

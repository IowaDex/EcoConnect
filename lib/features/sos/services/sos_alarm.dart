import '../../../core/audio/device_alarm.dart';

/// The emergency alert that rings a District Officer's device when a new SOS
/// lands: a hi-lo siren that repeats and a vibration that keeps going until
/// the alert is opened, acknowledged or resolved.
///
/// This is deliberately separate from the incoming-call ringtone — an SOS is
/// not a call, and it must never be silenced by one.
class SosAlarm {
  SosAlarm._();

  static final SosAlarm instance = SosAlarm._();

  static const String _owner = 'sos-alert';

  /// Three long buzzes separated by short pauses, then a pause before the
  /// siren cycle repeats.
  static const List<int> _pattern = <int>[0, 900, 250, 900, 250, 900, 1200];

  bool get isRinging => DeviceAlarm.instance.isRingingFor(_owner);

  Future<void> start() => DeviceAlarm.instance.start(
    owner: _owner,
    asset: 'audio/sos_alert.wav',
    vibrationPattern: _pattern,
    priority: DeviceAlarm.sosPriority,
    emergency: true,
  );

  Future<void> stop() => DeviceAlarm.instance.stop(owner: _owner);
}

import '../../../core/audio/device_alarm.dart';

/// The incoming-call ring: a repeating ringtone and a repeating vibration that
/// keeps going until the call is answered, declined, cancelled or expires.
///
/// All of the device work lives in [DeviceAlarm] so the SOS alarm and a call
/// can never play two loops at once. This class only names the call alarm.
class CallRinger {
  CallRinger._();

  static final CallRinger instance = CallRinger._();

  static const String _owner = 'incoming-call';

  /// Wait, buzz, pause, buzz, long pause. Android reads the first value as a
  /// delay and loops from index 0 until cancelled.
  static const List<int> _pattern = <int>[0, 700, 350, 700, 1600];

  bool get isRinging => DeviceAlarm.instance.isRingingFor(_owner);

  Future<void> start() => DeviceAlarm.instance.start(
    owner: _owner,
    asset: 'audio/incoming_call.wav',
    vibrationPattern: _pattern,
    priority: DeviceAlarm.callPriority,
  );

  Future<void> stop() => DeviceAlarm.instance.stop(owner: _owner);
}

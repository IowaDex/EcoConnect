import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../utils/app_logger.dart';

/// The one looping sound-and-vibration pair in the app.
///
/// SOS and incoming calls both need the same device behaviour: a sound that
/// repeats and a vibration that keeps going until somebody acts. Running them
/// through a single owner means a second alert can never stack a second loop
/// on top of the first, and [stop] can always silence everything.
///
/// On Android the loop is owned by native `MediaPlayer` and `Vibrator` (see
/// `DeviceAlertPlayer.kt`), so it survives the app being backgrounded or the
/// screen being locked and never depends on a Flutter timer. iOS and the web
/// fall back to the audio and vibration plugins.
class DeviceAlarm {
  DeviceAlarm._();

  static final DeviceAlarm instance = DeviceAlarm._();

  /// The native player registered by `MainActivity`.
  static const MethodChannel _channel = MethodChannel('ecoconnect/alert');

  /// SOS outranks a call: an emergency alert is never silenced by a ringtone.
  static const int callPriority = 1;
  static const int sosPriority = 2;

  AudioPlayer? _player;
  String? _owner;
  int _priority = 0;
  bool _ringing = false;

  /// Bumped on every start and stop. A slow `await` compares it so an alarm
  /// that was already stopped cannot turn itself back on.
  int _generation = 0;

  bool get isRinging => _ringing;

  bool isRingingFor(String owner) => _ringing && _owner == owner;

  /// Android runs the loop natively; every other platform uses the plugins.
  static bool get _usesNativePlayer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the loop for [owner]. Calling it again for the same owner while it
  /// is already ringing does nothing.
  Future<void> start({
    required String owner,
    required String asset,
    required List<int> vibrationPattern,
    int priority = callPriority,
    bool emergency = false,
  }) async {
    if (_ringing && _owner == owner) return;
    // A lower-priority alert may not interrupt a higher-priority one.
    if (_ringing && _priority > priority) return;
    if (_ringing) await stop();

    _owner = owner;
    _priority = priority;
    _ringing = true;
    final generation = ++_generation;

    if (_usesNativePlayer &&
        await _startNative(asset, vibrationPattern, emergency)) {
      // A stop that landed while the platform call was in flight must win.
      if (!_ringing || generation != _generation) {
        await _stopNative();
      }
      return;
    }

    // Vibration needs no setup, so it starts first: the phone reacts even if
    // the sound asset is still being prepared.
    unawaited(_startVibration(vibrationPattern, generation));
    await _startAudio(asset, emergency, generation);
  }

  /// Stops the loop. With an [owner], it only stops that owner's alarm.
  Future<void> stop({String? owner}) async {
    if (owner != null && _owner != owner) return;
    _generation++;
    _ringing = false;
    _owner = null;
    _priority = 0;
    await _stopNative();
    try {
      await Vibration.cancel();
    } catch (error) {
      AppLogger.error('Could not stop the alert vibration', error);
    }
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (error) {
      AppLogger.error('Could not stop the alert sound', error);
    }
  }

  /// Hands the loop to the Android player. Returns false when the platform
  /// side is unavailable, so the caller falls back to the plugins.
  Future<bool> _startNative(
    String asset,
    List<int> pattern,
    bool emergency,
  ) async {
    try {
      await _channel.invokeMethod<void>('start', {
        'asset': 'assets/$asset',
        'pattern': pattern,
        'emergency': emergency,
      });
      return true;
    } catch (error) {
      AppLogger.error('Native alert player unavailable', error);
      return false;
    }
  }

  Future<void> _stopNative() async {
    if (!_usesNativePlayer) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (error) {
      AppLogger.error('Could not stop the native alert player', error);
    }
  }

  Future<void> _startVibration(List<int> pattern, int generation) async {
    if (kIsWeb) return;
    try {
      if (!await Vibration.hasVibrator()) return;
      // The alert may have been dismissed while the plugin was queried.
      if (!_ringing || generation != _generation) return;
      // `repeat: 0` restarts the pattern from its first entry forever.
      await Vibration.vibrate(pattern: pattern, repeat: 0);
      // A stop that landed during the call above must win.
      if (!_ringing || generation != _generation) {
        await Vibration.cancel();
      }
    } catch (error) {
      // A device without a vibrator still gets the sound.
      AppLogger.error('Alert vibration failed', error);
    }
  }

  Future<void> _startAudio(String asset, bool emergency, int generation) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setAudioContext(_audioContext(emergency));
      await player.setVolume(1);
      await player.setSource(AssetSource(asset));
      if (!_ringing || generation != _generation) {
        await player.stop();
        return;
      }
      await player.resume();
    } catch (error) {
      // The vibration still alerts the device; a missing or unsupported audio
      // route must not throw out of the alert path.
      AppLogger.error('Alert sound failed', error);
    }
  }

  /// An alarm/ringtone route, not a media route: it plays on the alert stream,
  /// keeps the CPU awake, and ducks other audio instead of taking the audio
  /// focus a voice call needs a moment later.
  AudioContext _audioContext(bool emergency) {
    return AudioContext(
      android: AudioContextAndroid(
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: emergency
            ? AndroidUsageType.alarm
            : AndroidUsageType.notificationRingtone,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.duckOthers},
      ),
    );
  }
}

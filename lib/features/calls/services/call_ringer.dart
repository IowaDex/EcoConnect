import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../../../core/utils/app_logger.dart';

/// Rings the phone for an incoming EcoConnect call.
///
/// The ringtone loops and the vibration repeats for as long as the call is
/// ringing. Both are stopped together by [stop], so answering, declining,
/// cancelling or a timeout can never leave a background loop behind.
///
/// One instance is shared by the whole app: [start] is idempotent, which is
/// what keeps repeated Firestore snapshots from stacking a second ringtone on
/// top of the first.
class CallRinger {
  CallRinger._();

  static final CallRinger instance = CallRinger._();

  static const String _asset = 'audio/incoming_call.wav';

  /// Wait, buzz, pause, buzz, long pause. Android reads the first value as a
  /// delay and loops from index 0, so the pattern repeats until cancelled.
  static const List<int> _pattern = <int>[0, 700, 350, 700, 1600];

  AudioPlayer? _player;
  bool _ringing = false;

  /// Bumped on every start and stop. An `await` that finishes late compares
  /// this value so a ring that was already stopped cannot turn itself back on.
  int _generation = 0;

  bool get isRinging => _ringing;

  /// Starts the loop. Calling it again while already ringing does nothing.
  Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    final generation = ++_generation;
    // Vibration has no setup to wait for; letting it start now means the phone
    // buzzes even if the ringtone asset is slow to load.
    unawaited(_startVibration(generation));
    await _startAudio(generation);
  }

  /// Stops both loops. Safe to call when nothing is ringing.
  Future<void> stop() async {
    _generation++;
    _ringing = false;
    try {
      await Vibration.cancel();
    } catch (error) {
      AppLogger.error('Could not stop the call vibration', error);
    }
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (error) {
      AppLogger.error('Could not stop the call ringtone', error);
    }
  }

  Future<void> _startVibration(int generation) async {
    if (kIsWeb) return;
    try {
      if (!await Vibration.hasVibrator()) return;
      // The call may have been answered or cancelled while the plugin was
      // being queried.
      if (!_ringing || generation != _generation) return;
      // `repeat: 0` restarts the pattern from its first entry forever.
      await Vibration.vibrate(pattern: _pattern, repeat: 0);
      // If a stop landed in the middle of that call, cancel it again so no
      // loop is left running.
      if (!_ringing || generation != _generation) {
        await Vibration.cancel();
      }
    } catch (error) {
      // A device without a vibrator, or a vendor build that refuses the
      // pattern, still gets the ringtone.
      AppLogger.error('Incoming call vibration failed', error);
    }
  }

  Future<void> _startAudio(int generation) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setAudioContext(_audioContext());
      await player.setVolume(1);
      await player.setSource(AssetSource(_asset));
      // The call may have ended while the asset was loading.
      if (!_ringing || generation != _generation) {
        await player.stop();
        return;
      }
      await player.resume();
    } catch (error) {
      // The vibration still alerts the desk; a missing or unsupported audio
      // route must not throw out of the incoming-call path.
      AppLogger.error('Incoming call ringtone failed', error);
    }
  }

  /// A ringtone route, not a media route: it is audible on the ringer stream,
  /// it keeps the CPU awake while it plays, and it ducks other audio instead
  /// of taking the audio focus the voice call needs a moment later.
  AudioContext _audioContext() {
    return AudioContext(
      android: const AudioContextAndroid(
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationRingtone,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.duckOthers},
      ),
    );
  }
}

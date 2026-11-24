import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/utils/app_logger.dart';
import '../../auth/models/user.dart';
import '../models/call_log.dart';
import '../models/call_session.dart';
import '../services/call_service.dart';

/// The app-wide voice-call state.
///
/// One CallProvider lives above the router. CallHost feeds it the signed-in
/// account, so a call can ring on any screen without each dashboard having to
/// listen for itself. The provider owns the WebRTC peer connection and writes
/// the durable [CallLog] when the call finishes.
class CallProvider extends ChangeNotifier {
  CallProvider({CallService? service}) : _service = service ?? CallService();

  final CallService _service;

  String? _uid;
  String _name = '';
  UserRole? _role;
  String? _district;

  CallSession? _incoming;
  CallSession? _call;
  bool _isCaller = false;
  bool _peerReady = false;
  bool _muted = false;
  bool _speaker = false;
  bool _offerApplied = false;
  bool _answerApplied = false;
  String? _error;
  String? _notice;
  int _elapsedSeconds = 0;
  RTCPeerConnectionState _connection =
      RTCPeerConnectionState.RTCPeerConnectionStateNew;

  /// True once inbound audio packets are actually arriving. A peer connection
  /// that says "connected" but has received nothing is not a working call, so
  /// the screen reports audio from this flag, not from the ICE state.
  bool _audioFlowing = false;
  bool _statsUnavailable = false;

  StreamSubscription<List<CallSession>>? _ringingSub;
  StreamSubscription<CallSession?>? _callSub;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _remoteRenderer;
  final Set<String> _remoteCandidates = <String>{};

  /// Signalling writes run one at a time; see [_applySignals].
  Future<void> _signalQueue = Future<void>.value();

  Timer? _ringTimer;
  Timer? _ringTimeout;
  Timer? _elapsedTimer;
  Timer? _statsTimer;
  Timer? _ringRetry;
  int _ringRetries = 0;
  Timer? _disconnectGrace;
  Timer? _answerTimeout;

  CallSession? get incoming => _incoming;
  CallSession? get call => _call;
  bool get isCaller => _isCaller;
  bool get muted => _muted;
  bool get speaker => _speaker;
  bool get busy => _incoming != null || _call != null;
  String? get error => _error;
  int get elapsedSeconds => _elapsedSeconds;
  String? get uid => _uid;

  /// True only after ICE reports a live path between the two phones. On its
  /// own this proves the signalling worked, not that anybody can hear.
  bool get peerConnected =>
      _connection == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// The remote audio track arrived and inbound audio packets are being
  /// counted. This is what "connected" means to the user.
  bool get audioFlowing => _audioFlowing;

  /// A call is only reported as connected when audio is actually arriving.
  bool get connected => peerConnected && _audioFlowing;

  bool get reconnecting =>
      _connection == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected;

  String get connectionLabel {
    if (connected) return 'Connected';
    if (reconnecting) return 'Reconnecting…';
    return 'Connecting audio…';
  }

  /// Renders the remote audio. On the web the remote stream is silent unless
  /// it is attached to a media element, so the call screen keeps this alive
  /// for the whole call even though there is no video to look at.
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  /// A background problem (for example the incoming-call listener losing its
  /// permission). Shown as a dismissible banner, never as a blocking dialog.
  String? get notice => _notice;

  /// Only the desks that can send or receive an operational call listen for
  /// one. Residents and drivers never subscribe, which also keeps the
  /// Firestore rules for `calls` small.
  static bool canUseCalls(UserRole role) =>
      role == UserRole.cityHall ||
      role == UserRole.districtOfficer ||
      role == UserRole.admin;

  /// Called by CallHost whenever the signed-in account changes.
  void attach({
    required String uid,
    required String name,
    required UserRole role,
    String? district,
  }) {
    if (_uid == uid) return;
    detach();
    _uid = uid;
    _name = name.trim().isEmpty ? 'EcoConnect user' : name.trim();
    _role = role;
    _district = district;
    if (!canUseCalls(role)) return;
    _ringRetries = 0;
    _listenForRinging();
  }

  /// Watches for a ringing call addressed to this desk.
  ///
  /// A failure here must never take over the screen: the desk keeps working
  /// and the banner explains what is wrong. `permission-denied` usually means
  /// the account signed in somewhere else and its token is now stale, so the
  /// listener is retried once after a short pause.
  void _listenForRinging() {
    _ringingSub?.cancel();
    _ringingSub = _service.watchRinging().listen(
      (calls) {
        _ringRetries = 0;
        if (_notice != null) {
          _notice = null;
          notifyListeners();
        }
        _onRinging(calls);
      },
      onError: (Object error) {
        _notice = 'Incoming calls are not arriving: $error';
        notifyListeners();
        // A stale session or a missing rule does not heal in a loop, so the
        // listener is retried a couple of times and then left alone.
        if (_ringRetries >= 3) return;
        _ringRetries++;
        _ringRetry?.cancel();
        _ringRetry = Timer(const Duration(seconds: 4), () {
          if (_uid == null) return;
          _listenForRinging();
        });
      },
    );
  }

  void detach() {
    _ringingSub?.cancel();
    _ringingSub = null;
    _ringRetry?.cancel();
    _ringRetry = null;
    _clearCall(notify: false);
    _incoming = null;
    _uid = null;
    _name = '';
    _role = null;
    _district = null;
    // A failure belongs to the account that hit it. Leaving it set covers the
    // next screen — including the sign-in page — with a dialog nobody can
    // dismiss by signing out.
    _error = null;
    _notice = null;
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Incoming
  // ---------------------------------------------------------------------------

  void _onRinging(List<CallSession> calls) {
    if (_uid == null || _call != null || _incoming != null) return;
    for (final call in calls) {
      if (call.fromUid == _uid) continue;
      if (!_isAddressedToMe(call)) continue;
      _incoming = call;
      _startRinging();
      notifyListeners();
      return;
    }
  }

  bool _isAddressedToMe(CallSession call) {
    final uid = _uid;
    if (uid == null) return false;
    if (call.calleeId != null && call.calleeId!.isNotEmpty) {
      return call.calleeId == uid;
    }
    if (call.toUid != null && call.toUid!.isNotEmpty) {
      return call.toUid == uid;
    }
    return call.toRole == _role?.name;
  }

  void _startRinging() {
    _stopRinging(silent: false);
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    });
    // A ring that nobody answers stops on its own and leaves a missed-call log.
    _ringTimeout = Timer(const Duration(seconds: 35), _missIncoming);
  }

  void _stopRinging({bool silent = false}) {
    _ringTimer?.cancel();
    _ringTimer = null;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    if (!silent) HapticFeedback.lightImpact();
  }

  Future<void> acceptIncoming() async {
    final incoming = _incoming;
    final uid = _uid;
    if (incoming == null || uid == null) return;
    _stopRinging();
    try {
      final accepted = await _service.accept(
        incoming.id,
        uid: uid,
        name: _name,
      );
      if (accepted == null || accepted.status != CallStatus.active) {
        _incoming = null;
        notifyListeners();
        return;
      }
      _incoming = null;
      _call = accepted;
      _isCaller = false;
      _error = null;
      _listenToCall(accepted.id);
      notifyListeners();
      await _preparePeer(accepted, caller: false);
    } catch (error) {
      _incoming = null;
      _fail('Could not answer the call. $error');
    }
  }

  Future<void> declineIncoming() async {
    final incoming = _incoming;
    final uid = _uid;
    if (incoming == null || uid == null) return;
    _stopRinging();
    _incoming = null;
    notifyListeners();
    try {
      await _service.decline(incoming.id, uid: uid, name: _name);
    } catch (error) {
      _error = 'Could not decline the call. $error';
      notifyListeners();
    }
  }

  Future<void> _missIncoming() async {
    final incoming = _incoming;
    final uid = _uid;
    if (incoming == null) return;
    _stopRinging(silent: true);
    _incoming = null;
    notifyListeners();
    try {
      await _service.markMissed(incoming.id, uid: uid, name: _name);
    } catch (_) {
      // The caller's own timeout also closes the call; a failed write here
      // must not leave the phone ringing.
    }
  }

  // ---------------------------------------------------------------------------
  // Outgoing
  // ---------------------------------------------------------------------------

  /// Rings the other desk. [toUid] targets one person (DSQC tapping a named
  /// officer); leaving it empty rings everyone active on [toRole].
  Future<void> startCall({
    required String toRole,
    String? toUid,
    String context = 'general',
    String? reference,
    String? delayId,
    String? barangay,
    String? incidentId,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) {
      _error = 'Sign in first to make a call.';
      notifyListeners();
      return;
    }
    if (busy) return;
    _error = null;
    try {
      final id = await _service.create(
        fromUid: uid,
        fromName: _name,
        fromRole: _role?.name ?? 'user',
        toRole: toRole,
        toUid: toUid,
        context: context,
        reference: reference,
        delayId: delayId,
        barangay: barangay,
        district: _district,
        incidentId: incidentId,
        note: note,
      );
      _call = CallSession(
        id: id,
        fromUid: uid,
        fromName: _name,
        fromRole: _role?.name ?? 'user',
        toRole: toRole,
        toUid: toUid,
        status: CallStatus.ringing,
        context: context,
        reference: reference,
        delayId: delayId,
        barangay: barangay,
        district: _district,
        incidentId: incidentId,
        note: note,
        createdAt: DateTime.now(),
      );
      _isCaller = true;
      _elapsedSeconds = 0;
      _listenToCall(id);
      notifyListeners();
      // Nobody may be listening on the other desk (its app can be closed), so
      // the caller closes the invitation itself. Without this the attempt
      // would leave no history at all.
      _answerTimeout?.cancel();
      _answerTimeout = Timer(const Duration(seconds: 45), () {
        final current = _call;
        if (current == null || current.id != id) return;
        if (current.status != CallStatus.ringing) return;
        _notice = 'No answer. The call was saved as missed.';
        hangUp();
      });
      await _preparePeer(_call!, caller: true);
    } catch (error) {
      _fail('Could not start the call. $error');
    }
  }

  Future<void> hangUp() async {
    final call = _call;
    final uid = _uid;
    if (call == null || uid == null) return;
    try {
      if (call.status == CallStatus.ringing) {
        await _service.markMissed(
          call.id,
          outcome: CallOutcome.cancelled,
        );
      } else {
        await _service.end(call.id, viewerUid: uid);
      }
    } catch (error) {
      _error = 'The call ended, but its log could not be saved. $error';
    }
    _clearCall();
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      track.enabled = !_muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speaker = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(_speaker);
    } catch (_) {
      // Desktop and web builds route audio through the system default.
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Signalling
  // ---------------------------------------------------------------------------

  void _listenToCall(String id) {
    _callSub?.cancel();
    _callSub = _service.watchCall(id).listen(
      _onCallUpdate,
      onError: (Object error) {
        _fail('The call connection was lost. $error');
      },
    );
  }

  Future<void> _onCallUpdate(CallSession? updated) async {
    if (updated == null) {
      _clearCall();
      return;
    }

    // The invitation was accepted by somebody else, declined, or cancelled.
    if (_incoming != null && _incoming!.id == updated.id) {
      if (updated.status != CallStatus.ringing &&
          updated.calleeId != _uid) {
        _stopRinging(silent: true);
        _incoming = null;
        notifyListeners();
      }
      return;
    }

    final current = _call;
    if (current == null || current.id != updated.id) return;
    _call = updated;

    if (updated.status == CallStatus.active) {
      _answerTimeout?.cancel();
      _answerTimeout = null;
      if (_elapsedTimer == null) {
        _startElapsedTimer(updated.acceptedAt);
      }
      await _applySignals(updated);
      notifyListeners();
      return;
    }

    if (updated.status == CallStatus.ended ||
        updated.status == CallStatus.declined ||
        updated.status == CallStatus.missed ||
        updated.status == CallStatus.failed) {
      // The side that tapped End already writes the log. This upsert covers
      // the other phone, which saw the document close while still on screen.
      await _service.writeLog(
        updated,
        outcome: switch (updated.status) {
          CallStatus.declined => CallOutcome.declined,
          CallStatus.missed => CallOutcome.missed,
          CallStatus.failed => CallOutcome.failed,
          _ => CallOutcome.completed,
        },
        viewerUid: _uid,
        durationSeconds: updated.durationSeconds,
      ).catchError((Object _) {});
      _clearCall();
      return;
    }

    notifyListeners();
  }

  Future<void> _preparePeer(CallSession call, {required bool caller}) async {
    if (_peerReady) {
      await _applySignals(call);
      return;
    }
    try {
      // Put the phone into a voice-call audio session before the microphone
      // opens. Without it Android stays in media mode and iOS never activates
      // the record route, which is a call that "connects" in silence.
      await _configureAudioSession();
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      _localStream = stream;
      final pc = await createPeerConnection({
        'iceServers': _iceServers(),
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;
      for (final track in stream.getAudioTracks()) {
        await pc.addTrack(track, stream);
      }
      // The remote audio only becomes audible once its track is attached to a
      // media element. Mobile plays it natively too, but the web build stays
      // silent without this.
      pc.onTrack = (RTCTrackEvent event) {
        final remote = event.streams.isNotEmpty
            ? event.streams.first
            : null;
        if (remote != null) _attachRemoteStream(remote);
      };
      pc.onIceCandidate = (candidate) {
        final value = candidate.candidate;
        if (value == null || value.isEmpty) return;
        _service
            .addCandidates(
              call.id,
              fromCaller: caller,
              candidates: [
                {
                  'candidate': value,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                },
              ],
            )
            .catchError((Object _) {});
      };
      // The connection state says a path exists; [_startAudioProbe] checks
      // that audio is really arriving over it.
      pc.onConnectionState = (state) {
        _connection = state;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _disconnectGrace?.cancel();
          _disconnectGrace = null;
          _startAudioProbe();
        }
        if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          // A drop can be a tunnel or a handover. Give it a window to come
          // back, then close the call so the history is not left open.
          _disconnectGrace?.cancel();
          _disconnectGrace = Timer(const Duration(seconds: 20), () {
            if (_connection !=
                RTCPeerConnectionState
                    .RTCPeerConnectionStateDisconnected) {
              return;
            }
            final current = _call;
            final uid = _uid;
            if (current != null && uid != null) {
              _service
                  .markFailed(
                    current.id,
                    viewerUid: uid,
                    reason: 'The call was interrupted.',
                  )
                  .catchError((Object _) {});
            }
            _fail('The call was interrupted and could not recover.');
          });
        }
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          final current = _call;
          final uid = _uid;
          if (current != null && uid != null) {
            _service
                .markFailed(
                  current.id,
                  viewerUid: uid,
                  reason: 'The voice connection failed.',
                )
                .catchError((Object _) {});
          }
          _fail(
            "The voice connection failed. Check both phones' network and "
            'try the call again.',
          );
          return;
        }
        notifyListeners();
      };
      _peerReady = true;
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {
        // Not available on every platform; the default route is fine.
      }
      if (caller) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        await _service.sendOffer(call.id, {
          'sdp': offer.sdp,
          'type': offer.type,
        });
      }
      await _applySignals(call);
    } catch (error) {
      await _cancelAfterMediaFailure(call, error);
    }
  }

  /// Puts the device into a voice-call audio session.
  ///
  /// Each call is a no-op on the platform it does not belong to, so both are
  /// issued and the unsupported one is ignored.
  Future<void> _configureAudioSession() async {
    try {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    } catch (_) {
      // Web and iOS ignore this.
    }
    try {
      await Helper.setAppleAudioConfiguration(
        AppleAudioConfiguration(
          appleAudioCategory: AppleAudioCategory.playAndRecord,
          appleAudioCategoryOptions: {
            AppleAudioCategoryOption.allowBluetooth,
            AppleAudioCategoryOption.defaultToSpeaker,
          },
          appleAudioMode: AppleAudioMode.voiceChat,
        ),
      );
    } catch (_) {
      // Android, web and desktop ignore this.
    }
  }

  Future<void> _attachRemoteStream(MediaStream stream) async {
    _remoteStream = stream;
    try {
      var renderer = _remoteRenderer;
      if (renderer == null) {
        renderer = RTCVideoRenderer();
        await renderer.initialize();
        _remoteRenderer = renderer;
      }
      renderer.srcObject = stream;
    } catch (_) {
      // The native layer still plays the audio on mobile.
    }
    notifyListeners();
  }

  /// Polls the peer connection until inbound audio packets appear.
  ///
  /// This is the only honest proof that the other side can be heard: a
  /// connected peer connection with zero received packets is a silent call.
  void _startAudioProbe() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final pc = _pc;
      if (pc == null) return;
      try {
        final report = await pc.getStats();
        var packets = 0;
        for (final entry in report) {
          if (entry.type != 'inbound-rtp') continue;
          final kind = entry.values['kind'] ?? entry.values['mediaType'];
          if (kind != 'audio') continue;
          final received = entry.values['packetsReceived'];
          if (received is num) packets += received.toInt();
        }
        if (packets > 0 && !_audioFlowing) {
          _audioFlowing = true;
          _statsTimer?.cancel();
          _statsTimer = null;
          notifyListeners();
        }
      } catch (_) {
        // Some platforms do not expose inbound-rtp. Fall back to the presence
        // of the remote track rather than leaving the call "connecting"
        // forever.
        if (!_statsUnavailable) {
          _statsUnavailable = true;
          if (_remoteStream != null && !_audioFlowing) {
            _audioFlowing = true;
            notifyListeners();
          }
        }
      }
    });
  }

  /// Serialises every signalling write.
  ///
  /// Firestore emits a snapshot for the answer and then one for each ICE
  /// candidate. Those callbacks can overlap, and two `setRemoteDescription`
  /// calls on the same answer leave the peer connection in `stable` — the
  /// browser then rejects the second one with "called in wrong state". Queuing
  /// them means one description is applied at a time.
  Future<void> _applySignals(CallSession call) {
    final next = _signalQueue.then((_) => _applySignalsNow(call));
    _signalQueue = next.catchError((Object _) {});
    return _signalQueue;
  }

  Future<void> _applySignalsNow(CallSession call) async {
    final pc = _pc;
    // `_pc` is assigned before the microphone track is added, so a snapshot
    // that lands mid-build would answer with no audio or hand a candidate to a
    // connection that has no description yet. `_preparePeer` replays the latest
    // snapshot once it is finished, so nothing is lost by waiting.
    if (pc == null || !_peerReady) return;
    // The caller of this method may be holding a snapshot from before the
    // peer connection existed, so the live session is the better source: an
    // answer that arrived while the microphone was still opening would
    // otherwise be dropped and the call would stay silent.
    final live = _call;
    final session = live != null && live.id == call.id ? live : call;
    try {
      // The offer is only valid on a fresh connection, and the answer only
      // after our own offer. Checking the real state stops a replayed
      // description from tearing the call down.
      if (!_isCaller &&
          !_offerApplied &&
          session.offer != null &&
          pc.signalingState ==
              RTCSignalingState.RTCSignalingStateStable) {
        final offer = session.offer!;
        final sdp = offer['sdp'] as String?;
        final type = offer['type'] as String?;
        if (sdp != null && sdp.isNotEmpty) {
          await pc.setRemoteDescription(
            RTCSessionDescription(sdp, type ?? 'offer'),
          );
          // Only a description that the browser accepted counts as applied; a
          // failure here must leave the flag down so the next snapshot retries.
          _offerApplied = true;
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await _service.sendAnswer(session.id, {
            'sdp': answer.sdp,
            'type': answer.type,
          });
        }
      }

      if (_isCaller &&
          !_answerApplied &&
          session.answer != null &&
          pc.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        final answer = session.answer!;
        final sdp = answer['sdp'] as String?;
        final type = answer['type'] as String?;
        if (sdp != null && sdp.isNotEmpty) {
          await pc.setRemoteDescription(
            RTCSessionDescription(sdp, type ?? 'answer'),
          );
          _answerApplied = true;
        }
      }

      // A candidate only means something once the description it belongs to is
      // in place. The caller starts publishing ICE candidates while it is still
      // writing the offer, so the callee can see a candidate before the offer;
      // handing that to the browser throws "The remote description was null",
      // and the catch below then killed the whole call. Early candidates stay
      // in the document, and the snapshot that carries the description applies
      // them in the same pass.
      final remoteReady = _isCaller ? _answerApplied : _offerApplied;
      if (remoteReady) {
        final candidates = _isCaller
            ? session.calleeCandidates
            : session.callerCandidates;
        for (final candidate in candidates) {
          final value = candidate['candidate'] as String?;
          if (value == null || value.isEmpty) continue;
          final key =
              '$value|${candidate['sdpMid']}|${candidate['sdpMLineIndex']}';
          if (!_remoteCandidates.add(key)) continue;
          try {
            await pc.addCandidate(
              RTCIceCandidate(
                value,
                candidate['sdpMid'] as String?,
                (candidate['sdpMLineIndex'] as num?)?.toInt(),
              ),
            );
          } catch (error) {
            // ICE is best effort: one candidate the browser refuses must not
            // end a call the other candidates can still carry.
            AppLogger.info('Dropped an ICE candidate: $error');
          }
        }
      }
    } catch (error) {
      final current = _call;
      final uid = _uid;
      AppLogger.error('Call signalling failed', error);
      if (current != null && uid != null) {
        // The history carries the reason, so a call that dies here explains
        // itself instead of only showing the generic alert.
        _service
            .markFailed(
              current.id,
              viewerUid: uid,
              reason: 'The signalling exchange failed. $error',
            )
            .catchError((Object _) {});
      }
      _fail('The call could not connect. Please try again.');
    }
  }

  Future<void> _cancelAfterMediaFailure(
    CallSession call,
    Object error,
  ) async {
    AppLogger.error('Call media failed', error);
    _error =
        'Microphone unavailable. Allow microphone access for EcoConnect and '
        'try the call again.';
    try {
      await _service.markFailed(
        call.id,
        viewerUid: _uid ?? call.fromUid,
        reason: 'Microphone unavailable. $error',
      );
    } catch (_) {
      // The alert is more useful than a secondary write failure.
    }
    _clearCall();
  }

  // ---------------------------------------------------------------------------
  // Timers and teardown
  // ---------------------------------------------------------------------------

  /// STUN finds the public address; TURN relays the audio when both phones sit
  /// behind a strict NAT. TURN is optional and read from `.env`, so the app
  /// still works with STUN alone during development.
  static List<Map<String, dynamic>> _iceServers() {
    final servers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ];
    final url = dotenv.env['TURN_URL']?.trim() ?? '';
    if (url.isEmpty) return servers;
    final username = dotenv.env['TURN_USERNAME']?.trim() ?? '';
    final credential = dotenv.env['TURN_CREDENTIAL']?.trim() ?? '';
    servers.add({
      'urls': url
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      if (username.isNotEmpty) 'username': username,
      if (credential.isNotEmpty) 'credential': credential,
    });
    return servers;
  }

  void _startElapsedTimer(DateTime? acceptedAt) {
    final start = acceptedAt ?? DateTime.now();
    _elapsedSeconds = DateTime.now().difference(start).inSeconds;
    if (_elapsedSeconds < 0) _elapsedSeconds = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds = DateTime.now().difference(start).inSeconds;
      if (_elapsedSeconds < 0) _elapsedSeconds = 0;
      notifyListeners();
    });
  }

  Future<void> _clearCall({bool notify = true}) async {
    _callSub?.cancel();
    _callSub = null;
    _stopRinging(silent: true);
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    _answerTimeout?.cancel();
    _answerTimeout = null;
    _disconnectGrace?.cancel();
    _disconnectGrace = null;
    _elapsedSeconds = 0;
    _call = null;
    _isCaller = false;
    _peerReady = false;
    _offerApplied = false;
    _answerApplied = false;
    _muted = false;
    _speaker = false;
    _audioFlowing = false;
    _statsUnavailable = false;
    _connection = RTCPeerConnectionState.RTCPeerConnectionStateNew;
    _remoteCandidates.clear();
    _signalQueue = Future<void>.value();
    final pc = _pc;
    _pc = null;
    try {
      await pc?.close();
    } catch (_) {}
    final local = _localStream;
    _localStream = null;
    try {
      for (final track in local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await track.stop();
      }
      await local?.dispose();
    } catch (_) {}
    _remoteStream = null;
    final renderer = _remoteRenderer;
    _remoteRenderer = null;
    try {
      renderer?.srcObject = null;
      await renderer?.dispose();
    } catch (_) {}
    if (notify) notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    final call = _call;
    if (call != null && call.status != CallStatus.ended) {
      _clearCall(notify: false);
    }
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ringingSub?.cancel();
    _ringRetry?.cancel();
    _statsTimer?.cancel();
    _answerTimeout?.cancel();
    _disconnectGrace?.cancel();
    _clearCall(notify: false);
    super.dispose();
  }
}

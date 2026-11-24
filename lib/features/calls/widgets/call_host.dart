import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/call_session.dart';
import '../providers/call_provider.dart';

/// Keeps the call provider tied to the signed-in account and paints the call
/// surface above every route.
///
/// It sits just inside `MaterialApp.builder`, like the notification banner, so
/// an incoming delay call rings on whichever desk screen is open.
class CallHost extends StatefulWidget {
  const CallHost({super.key, required this.child});

  final Widget child;

  @override
  State<CallHost> createState() => _CallHostState();
}

class _CallHostState extends State<CallHost> with WidgetsBindingObserver {
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A long spell in the background can let Android stop the ringtone. When
  /// the desk comes back, a still-pending invitation rings again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    context.read<CallProvider>().resumeRingingIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    final calls = context.read<CallProvider>();
    if (user == null) {
      calls.detach();
    } else {
      calls.attach(
        uid: user.uid,
        name: user.displayName ?? user.email ?? 'EcoConnect user',
        role: user.role,
        district: user.district,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final calls = context.watch<CallProvider>();
    final incoming = calls.incoming;
    final active = calls.call;

    return Stack(
      children: [
        widget.child,
        if (incoming != null)
          Positioned.fill(
            child: _IncomingCall(
              call: incoming,
              onAnswer: calls.acceptIncoming,
              onDecline: calls.declineIncoming,
            ),
          )
        else if (active != null) ...[
          Positioned.fill(child: _ActiveCall(calls: calls)),
          // The remote audio lives here for the whole call. The web build is
          // silent unless the received stream is attached to a media element,
          // and a 2×2 invisible one is enough to hear the other side.
          Positioned(
            left: 0,
            top: 0,
            width: 2,
            height: 2,
            child: _RemoteAudio(renderer: calls.remoteRenderer),
          ),
        ]
        // A failure only takes over the screen while somebody is signed in and
        // no call is on it. Signing out clears it, so the next person never
        // meets a dialog left behind by an earlier account.
        else if (calls.error != null && calls.uid != null)
          Positioned.fill(
            child: _CallError(
              message: calls.error!,
              onClose: calls.clearError,
            ),
          ),
        if (calls.notice != null && incoming == null)
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: _CallNotice(
              message: calls.notice!,
              onClose: calls.clearNotice,
            ),
          ),
      ],
    );
  }
}

/// A background problem with the call channel. It sits above the desk so the
/// work can continue, unlike the blocking error shown for a broken call.
class _CallNotice extends StatelessWidget {
  const _CallNotice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.phone_disabled_rounded,
              size: 18,
              color: AppColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.forest,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingCall extends StatelessWidget {
  const _IncomingCall({
    required this.call,
    required this.onAnswer,
    required this.onDecline,
  });

  final CallSession call;
  final Future<void> Function() onAnswer;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final isDelay = call.context == 'delay';
    final isSos = call.context == 'sos';
    return Material(
      color: AppColors.forestDeep,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.forestGradient),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 86,
                width: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  isSos
                      ? Icons.sos_rounded
                      : isDelay
                      ? Icons.campaign_rounded
                      : Icons.phone_in_talk_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSos
                    ? 'SOS INCIDENT · INCOMING CALL'
                    : isDelay
                    ? 'DELAY ALERT · INCOMING CALL'
                    : 'INCOMING CALL',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  call.fromName.trim().isEmpty
                      ? _roleLabel(call.fromRole)
                      : call.fromName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _roleLabel(call.fromRole),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              if (call.reference != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    call.reference!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (call.note?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    call.note!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Voice call through EcoConnect',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundAction(
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    color: AppColors.error,
                    onTap: onDecline,
                  ),
                  _RoundAction(
                    icon: Icons.call_rounded,
                    label: 'Answer',
                    color: AppColors.primary,
                    filled: true,
                    onTap: onAnswer,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCall extends StatelessWidget {
  const _ActiveCall({required this.calls});

  final CallProvider calls;

  @override
  Widget build(BuildContext context) {
    final call = calls.call!;
    final ringing = call.status == CallStatus.ringing;
    final counterpart = call.otherName(calls.uid ?? '');
    final role = call.otherRole(calls.uid ?? '');
    final connected = calls.connected;
    final statusText = ringing
        ? 'Ringing…'
        : connected
        ? _duration(calls.elapsedSeconds)
        : calls.connectionLabel;

    return Material(
      color: AppColors.forestDeep,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.forestGradient),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                child: Icon(
                  ringing
                      ? Icons.phone_forwarded_rounded
                      : Icons.phone_in_talk_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  counterpart,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _roleLabel(role),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: ringing || !connected ? 12 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: ringing || !connected ? 0.3 : 0.6,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              if (!ringing && connected) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Audio connected',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
              if (call.reference != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    call.reference!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (call.note?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    call.note!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!ringing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      icon: calls.muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: calls.muted ? 'Unmute' : 'Mute',
                      color: calls.muted
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      foreground: calls.muted
                          ? AppColors.forest
                          : Colors.white,
                      onTap: calls.toggleMute,
                    ),
                    const SizedBox(width: 34),
                    _RoundAction(
                      icon: calls.speaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: calls.speaker ? 'Speaker on' : 'Speaker',
                      color: calls.speaker
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      foreground: calls.speaker
                          ? AppColors.forest
                          : Colors.white,
                      onTap: calls.toggleSpeaker,
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              _RoundAction(
                icon: Icons.call_end_rounded,
                label: 'End call',
                color: AppColors.error,
                filled: true,
                onTap: calls.hangUp,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallError extends StatelessWidget {
  const _CallError({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.creamBright,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic_off_rounded,
                size: 30,
                color: AppColors.error,
              ),
              const SizedBox(height: 10),
              const Text(
                'Call problem',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: onClose,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays the audio received from the other phone.
///
/// On the web the peer connection delivers the remote track but nothing is
/// audible until it is attached to a media element, so this stays mounted for
/// the whole call. Mobile also renders it; the native layer plays the same
/// stream, so the two do not fight over the output.
class _RemoteAudio extends StatelessWidget {
  const _RemoteAudio({required this.renderer});

  final RTCVideoRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    final renderer = this.renderer;
    if (renderer == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: 0.01,
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.foreground = Colors.white,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final bool filled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 40,
          child: Container(
            height: filled ? 68 : 58,
            width: filled ? 68 : 58,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: filled ? 0 : 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: filled ? 28 : 24, color: foreground),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'cityHall' => 'City Hall · DSQC',
  'districtOfficer' => 'District Officer',
  'admin' => 'Barangay staff',
  'iswim' => 'Iswim',
  _ => 'EcoConnect',
};

String _duration(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

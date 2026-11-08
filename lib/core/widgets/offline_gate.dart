import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../network/network_status.dart';
import 'eco_loading.dart';

/// Matches the entry screen's sky so the offline card reads as the same app.
const Color _sky = Color(0xFFE9F4E1);
const Color _ink = Color(0xFF1C4A24);
const Color _inkMuted = Color(0xFF5B7A5F);

/// Puts the truck loading screen in front of every route while the device has
/// no network.
///
/// The truck is the app's one "waiting" language, so losing the wifi mid-app
/// gets the same moving truck the entry screen uses instead of a spinner or a
/// red toast. It sits above the router's child but below nothing else, so it
/// covers the notification banners too — there is no point announcing an event
/// over a screen that is saying the phone is offline.
class OfflineGate extends StatefulWidget {
  const OfflineGate({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// False keeps the app usable offline (e.g. a driver mid-run, whose queued
  /// location history and cached routes still work without a connection).
  final bool enabled;

  @override
  State<OfflineGate> createState() => _OfflineGateState();
}

class _OfflineGateState extends State<OfflineGate> {
  /// The user chose to keep using saved data for this outage.
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    // Nullable lookup: widget tests build screens without the provider, and a
    // missing provider must mean "online", never a crash.
    final status = context.watch<NetworkStatus?>();
    final isOffline = status?.isOffline ?? false;
    // Back online: the next outage shows the card again.
    if (!isOffline) _dismissed = false;
    final offline = widget.enabled && isOffline && !_dismissed;
    final child = widget.child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: offline
                ? EcoOfflineScreen(
                    key: const ValueKey('offline'),
                    onRetry: status?.refresh,
                    onContinue: () => setState(() => _dismissed = true),
                  )
                : const SizedBox.shrink(key: ValueKey('online')),
          ),
        ),
      ],
    );
  }
}

/// Full-screen "no internet" state, built from the same truck as the loader.
class EcoOfflineScreen extends StatefulWidget {
  const EcoOfflineScreen({super.key, this.onRetry, this.onContinue});

  final Future<void> Function()? onRetry;

  /// Lets the user carry on with saved data; the offline card comes back on
  /// the next outage.
  final VoidCallback? onContinue;

  @override
  State<EcoOfflineScreen> createState() => _EcoOfflineScreenState();
}

class _EcoOfflineScreenState extends State<EcoOfflineScreen> {
  /// The retry button waits a beat — offering it instantly reads like an error
  /// dialog rather than a screen that is still trying on its own.
  Timer? _reveal;
  bool _showRetry = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _reveal = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _showRetry = true);
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    final onRetry = widget.onRetry;
    if (onRetry == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      await onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _sky,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Same proportion as the entry screen: a small truck, centred,
            // with its note directly underneath.
            final truckWidth = (constraints.maxWidth * 0.24).clamp(80.0, 200.0);
            final compact = constraints.maxHeight < 420;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EcoTruckArt(width: truckWidth),
                    SizedBox(height: compact ? 8 : 14),
                    Text(
                      'No internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reconnecting automatically. Your saved data is still here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: _inkMuted,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: _showRetry
                          ? Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 178,
                                    child: _RetryButton(
                                      busy: _retrying,
                                      onPressed: _retry,
                                    ),
                                  ),
                                  if (widget.onContinue != null)
                                    TextButton(
                                      onPressed: widget.onContinue,
                                      style: TextButton.styleFrom(
                                        foregroundColor: _inkMuted,
                                      ),
                                      child: const Text(
                                        'Keep using saved data',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: BorderSide(color: _ink.withValues(alpha: 0.30)),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        shape: const StadiumBorder(),
      ),
      child: busy
          ? const SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: _ink),
            )
          : const Text(
              'Try again',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
    );
  }
}

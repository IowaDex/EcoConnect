import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has a network link.
///
/// `connectivity_plus` reports the *link* (wifi / mobile / none) rather than
/// whether the internet is actually reachable, which is exactly the signal the
/// truck loading screen needs: the moment the phone drops off the barangay
/// wifi, the truck takes over the screen and says so.
///
/// Going offline is debounced by [grace] so a two-second dead spot does not
/// throw a full-screen takeover over whatever the resident is doing. Coming
/// back online is applied immediately, so the app never feels stuck behind a
/// stale "no internet" card.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus({
    this.changes,
    this.check,
    this.grace = const Duration(milliseconds: 1400),
  });

  /// Injection points for tests; the app uses the plugin defaults.
  final Stream<Object?>? changes;
  final Future<Object?> Function()? check;

  /// How long the link must stay down before the offline screen appears.
  final Duration grace;

  Connectivity? _connectivity;
  StreamSubscription<Object?>? _sub;
  Timer? _timer;
  bool _offline = false;
  bool _started = false;
  bool _disposed = false;

  Connectivity get _link => _connectivity ??= Connectivity();

  /// True once the link has been confirmed down for [grace].
  bool get isOffline => _offline;

  /// False until the first reading lands, so nothing flashes during startup.
  bool get isKnown => _started;

  /// Begins watching. Safe to call more than once.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    try {
      _sub = (changes ?? _link.onConnectivityChanged)
          .listen(_apply, onError: (Object _) {});
    } catch (_) {
      // Platforms without a connectivity plugin simply never report a change.
    }

    try {
      _apply(await (check ?? _link.checkConnectivity)());
    } catch (_) {
      // An unsupported platform is treated as online rather than offline.
    }
  }

  /// Re-reads the link right now — the "Try again" button calls this.
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      _apply(await (check ?? _link.checkConnectivity)(), immediate: true);
    } catch (_) {
      // Leave the current state alone if the platform cannot answer.
    }
  }

  void _apply(Object? value, {bool immediate = false}) {
    if (_disposed) return;

    if (!isOfflineResult(value)) {
      _timer?.cancel();
      _timer = null;
      if (_offline) {
        _offline = false;
        notifyListeners();
      }
      return;
    }

    if (immediate) {
      _timer?.cancel();
      _timer = null;
      _markOffline();
      return;
    }

    _timer ??= Timer(grace, _markOffline);
  }

  void _markOffline() {
    _timer = null;
    if (_disposed || _offline) return;
    _offline = true;
    notifyListeners();
  }

  /// Normalises whatever the plugin hands back into a single verdict.
  ///
  /// connectivity_plus 6.x emits a `List<ConnectivityResult>`; older builds and
  /// test fakes emit a single value. An empty list means "unknown", which is
  /// treated as online so a plugin hiccup can never fake an outage.
  static bool isOfflineResult(Object? value) {
    if (value == null) return false;
    final results = value is Iterable ? value.toList() : <Object?>[value];
    if (results.isEmpty) return false;
    return results.every((result) => result == ConnectivityResult.none);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

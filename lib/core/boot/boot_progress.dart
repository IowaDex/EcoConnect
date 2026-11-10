import 'package:flutter/foundation.dart';

/// The boot step that is running right now, in plain English.
///
/// `main()` reports each step as it starts, before the first frame is drawn, and
/// the entry screen renders whatever is current. That way the loading copy
/// always names the work actually in flight instead of a fixed string that
/// lies when startup is slow or instant.
///
/// Kept as a static notifier rather than a provider because the earliest steps
/// happen before the widget tree — and therefore before any provider — exists.
abstract final class BootProgress {
  /// Human-readable description of the current step.
  static final ValueNotifier<String> message =
      ValueNotifier<String>('Starting up');

  /// Records the step that just started.
  static void report(String step) => message.value = step;
}

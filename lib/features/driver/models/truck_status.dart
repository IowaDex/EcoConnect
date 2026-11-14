import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/garbage_truck.dart';

/// What the guide sees on each truck in the fleet list.
///
/// The order is the precedence: a truck on the move outranks its paperwork, a
/// ticket outranks an idle crew, and a plate nobody drives is simply inactive.
enum TruckStatus { inTransit, ticketReady, noTicket, inactive }

extension TruckStatusX on TruckStatus {
  String get label => switch (this) {
        TruckStatus.inTransit => 'In transit',
        TruckStatus.ticketReady => 'Trip ticket ready',
        TruckStatus.noTicket => 'No trip ticket',
        TruckStatus.inactive => 'Inactive',
      };

  Color get color => switch (this) {
        TruckStatus.inTransit => const Color(0xFF1D4ED8),
        TruckStatus.ticketReady => AppColors.forest,
        TruckStatus.noTicket => const Color(0xFFB06A12),
        TruckStatus.inactive => const Color(0xFF6B7A6E),
      };

  Color get background => switch (this) {
        TruckStatus.inTransit => const Color(0xFFE8F0FE),
        TruckStatus.ticketReady => const Color(0xFFE8F3E7),
        TruckStatus.noTicket => const Color(0xFFFDF2E1),
        TruckStatus.inactive => const Color(0xFFF0F3F0),
      };

  /// `null` draws a small dot instead of an icon — the mock uses a filled dot
  /// for a ready ticket and a hollow one for a truck that is not running.
  IconData? get icon => switch (this) {
        TruckStatus.inTransit => Icons.navigation_rounded,
        TruckStatus.ticketReady => null,
        TruckStatus.noTicket => Icons.confirmation_number_outlined,
        TruckStatus.inactive => null,
      };

  bool get dotFilled => this == TruckStatus.ticketReady;

  /// The truck is reporting a live position right now.
  static TruckStatus resolve({
    required GarbageTruck truck,
    required bool inTransit,
    required bool hasTicket,
  }) {
    if (inTransit) return TruckStatus.inTransit;
    if (hasTicket) return TruckStatus.ticketReady;
    if (truck.hasDriver) return TruckStatus.noTicket;
    return TruckStatus.inactive;
  }
}

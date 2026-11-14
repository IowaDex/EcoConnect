import 'package:flutter/material.dart';

/// Who is holding the device for this truck.
///
/// Both crew roles run the exact same dashboard — the guide is the
/// alternative for a driver without a phone, so they log in to the same
/// screens and drive the same trip. The role only changes the labels and who
/// the barangay is told is on duty.
enum TruckCrewRole { driver, guide }

extension TruckCrewRoleX on TruckCrewRole {
  String get wireName => switch (this) {
        TruckCrewRole.driver => 'driver',
        TruckCrewRole.guide => 'guide',
      };

  String get label => switch (this) {
        TruckCrewRole.driver => 'Truck Driver',
        TruckCrewRole.guide => 'Truck Guide',
      };

  String get shortLabel => switch (this) {
        TruckCrewRole.driver => 'Driver',
        TruckCrewRole.guide => 'Guide',
      };

  String get blurb => switch (this) {
        TruckCrewRole.driver =>
          'You drive the truck. Start and pause the trip from here.',
        TruckCrewRole.guide =>
          'You ride with the driver and hold the device. Same trip controls.',
      };

  IconData get icon => switch (this) {
        TruckCrewRole.driver => Icons.local_shipping_rounded,
        TruckCrewRole.guide => Icons.badge_outlined,
      };

  static TruckCrewRole fromName(String? value) =>
      value == 'guide' ? TruckCrewRole.guide : TruckCrewRole.driver;
}

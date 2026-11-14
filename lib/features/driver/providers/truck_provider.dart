import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_trucks.dart';
import '../models/garbage_truck.dart';
import '../models/truck_crew_role.dart';

/// Remembers which truck the signed-in crew picked, so a reload lands back on
/// the same dashboard instead of the truck list.
///
/// The choice is device-local on purpose: the truck assignment comes from the
/// barangay, and this only remembers the crew's own last selection on this
/// phone (the guide's phone and the driver's phone may hold different trucks).
class TruckProvider extends ChangeNotifier {
  static const _truckKey = 'driver.selectedTruck';
  static const _roleKey = 'driver.crewRoleOverride';

  GarbageTruck? _selectedTruck;
  TruckCrewRole? _roleOverride;
  bool _restored = false;

  GarbageTruck? get selectedTruck => _selectedTruck;
  bool get hasTruck => _selectedTruck != null;
  bool get isRestored => _restored;

  /// Demo-only override so both crew views can be previewed from one account.
  /// Null means "use the role on the account".
  TruckCrewRole? get roleOverride => _roleOverride;

  TruckCrewRole resolveRole(TruckCrewRole accountRole) =>
      _roleOverride ?? accountRole;

  /// Loads the saved selection. Safe to call more than once.
  Future<void> restore() async {
    if (_restored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_truckKey);
      if (raw != null) {
        _selectedTruck = GarbageTruck.fromMap(
          jsonDecode(raw) as Map<String, dynamic>?,
        );
      }
      _roleOverride = prefs.getString(_roleKey) == null
          ? null
          : TruckCrewRoleX.fromName(prefs.getString(_roleKey));
    } catch (e) {
      // A corrupt entry must never block the dashboard.
      debugPrint('Truck selection could not be restored: $e');
    }
    _restored = true;
    notifyListeners();
  }

  Future<void> select(GarbageTruck truck) async {
    _selectedTruck = truck;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_truckKey, jsonEncode(truck.toMap()));
    } catch (e) {
      debugPrint('Truck selection could not be saved: $e');
    }
  }

  /// Used when the crew switches trucks or signs out.
  Future<void> clear() async {
    _selectedTruck = null;
    _roleOverride = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_truckKey);
      await prefs.remove(_roleKey);
    } catch (e) {
      debugPrint('Truck selection could not be cleared: $e');
    }
  }

  Future<void> setRoleOverride(TruckCrewRole? role) async {
    _roleOverride = role;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role == null) {
        await prefs.remove(_roleKey);
      } else {
        await prefs.setString(_roleKey, role.wireName);
      }
    } catch (e) {
      debugPrint('Crew role preview could not be saved: $e');
    }
  }

  /// Convenience for screens that only need the fleet list.
  List<GarbageTruck> get trucks => kMockTrucks;
}

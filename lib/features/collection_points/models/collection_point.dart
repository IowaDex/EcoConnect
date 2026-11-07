import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';

enum CollectionPointStatus { active, inactive }

extension CollectionPointStatusX on CollectionPointStatus {
  String get label =>
      this == CollectionPointStatus.active ? 'Active' : 'Inactive';

  Color get color =>
      this == CollectionPointStatus.active ? AppColors.primary : AppColors.inkMuted;

  static CollectionPointStatus fromName(String? name) =>
      name == 'inactive'
          ? CollectionPointStatus.inactive
          : CollectionPointStatus.active;
}

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A designated garbage collection location on the barangay map.
class CollectionPoint {
  const CollectionPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.barangay,
    this.zone,
    this.driverId,
    this.driverName,
    this.scheduleDays = const [],
    this.scheduleTime,
    this.category,
    this.status = CollectionPointStatus.active,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? barangay;
  final String? zone;
  final String? driverId;
  final String? driverName;
  final List<String> scheduleDays;
  final String? scheduleTime;
  final WasteCategory? category;
  final CollectionPointStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isActive => status == CollectionPointStatus.active;

  bool get hasSchedule =>
      scheduleDays.isNotEmpty || (scheduleTime?.isNotEmpty ?? false);

  String get scheduleLabel {
    if (scheduleDays.isEmpty && (scheduleTime == null || scheduleTime!.isEmpty)) {
      return 'No schedule set';
    }
    final days = scheduleDays.isEmpty ? 'Any day' : scheduleDays.join(', ');
    final time = (scheduleTime == null || scheduleTime!.isEmpty)
        ? ''
        : ' · $scheduleTime';
    return '$days$time';
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'address': address.trim(),
        'lat': latitude,
        'lng': longitude,
        'barangay': barangay,
        'zone': zone,
        'driverId': driverId,
        'driverName': driverName,
        'scheduleDays': scheduleDays,
        'scheduleTime': scheduleTime,
        'category': category?.name,
        'status': status.name,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static CollectionPoint fromDoc(String id, Map<String, dynamic> data) {
    final rawDays = data['scheduleDays'];
    return CollectionPoint(
      id: id,
      name: (data['name'] as String?) ?? 'Collection point',
      address: (data['address'] as String?) ?? '',
      latitude: (data['lat'] as num?)?.toDouble() ?? 0,
      longitude: (data['lng'] as num?)?.toDouble() ?? 0,
      barangay: data['barangay'] as String?,
      zone: data['zone'] as String?,
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      scheduleDays: rawDays is List
          ? rawDays.map((e) => '$e').toList(growable: false)
          : const [],
      scheduleTime: data['scheduleTime'] as String?,
      category: data['category'] == null
          ? null
          : WasteCategoryX.fromName(data['category'] as String?),
      status: CollectionPointStatusX.fromName(data['status'] as String?),
      notes: data['notes'] as String?,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }
}

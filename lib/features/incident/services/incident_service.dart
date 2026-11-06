import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/incident.dart';

class IncidentService {
  static final IncidentService _instance = IncidentService._internal();
  factory IncidentService() => _instance;
  IncidentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _incidents =>
      _db.collection('incidents');

  Future<void> submit({
    required String residentId,
    required String residentName,
    required IncidentCategory category,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    await _incidents.add({
      'residentId': residentId,
      'residentName': residentName,
      'category': category.name,
      'description': description,
      'status': IncidentStatus.pending.name,
      'lat': latitude,
      'lng': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Incident>> watchAll() {
    return _incidents
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Incident.fromDoc(d.id, d.data()))
            .toList());
  }

  Future<void> updateStatus(String incidentId, IncidentStatus status) async {
    await _incidents.doc(incidentId).update({
      'status': status.name,
      'resolvedAt': status == IncidentStatus.resolved
          ? FieldValue.serverTimestamp()
          : null,
    });
  }
}

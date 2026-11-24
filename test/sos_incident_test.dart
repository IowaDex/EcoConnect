import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_connect/features/sos/models/sos_incident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SosStatus', () {
    test('parses the current names and the seven older ones', () {
      expect(SosStatusX.fromName('newAlert'), SosStatus.newAlert);
      expect(SosStatusX.fromName('acknowledged'), SosStatus.acknowledged);
      expect(SosStatusX.fromName('coordinating'), SosStatus.coordinating);
      expect(SosStatusX.fromName('resolved'), SosStatus.resolved);
      // Incidents written before the workflow was simplified keep their real
      // progress instead of falling back to a new alert.
      expect(SosStatusX.fromName('pending'), SosStatus.newAlert);
      expect(SosStatusX.fromName('received'), SosStatus.acknowledged);
      expect(SosStatusX.fromName('contactingBarangay'), SosStatus.coordinating);
      expect(SosStatusX.fromName('barangayNotified'), SosStatus.coordinating);
      expect(SosStatusX.fromName('coordinationCompleted'), SosStatus.coordinating);
      expect(SosStatusX.fromName('not-a-status'), SosStatus.newAlert);
      expect(SosStatusX.fromName(null), SosStatus.newAlert);
    });

    test('moves forward one step at a time', () {
      expect(SosStatus.newAlert.nextStep, SosStatus.acknowledged);
      expect(SosStatus.acknowledged.nextStep, SosStatus.coordinating);
      expect(SosStatus.coordinating.nextStep, SosStatus.resolved);
      expect(SosStatus.resolved.nextStep, isNull);
    });

    test('only resolved closes an incident', () {
      expect(SosStatus.newAlert.isOpen, isTrue);
      expect(SosStatus.acknowledged.isOpen, isTrue);
      expect(SosStatus.coordinating.isOpen, isTrue);
      expect(SosStatus.resolved.isOpen, isFalse);
    });
  });

  group('SosIncident', () {
    test('reads the full incident DSQC sent', () {
      final incident = SosIncident.fromDoc('sos-1', {
        'code': 'SOS-2026-0007',
        'description': 'Hydraulic line broke on Commonwealth Ave.',
        'reason': 'Garbage truck breakdown',
        'incidentAt': Timestamp.fromDate(DateTime(2026, 11, 24, 14, 30)),
        'district': 'District 2',
        'barangay': 'Batasan Hills',
        'status': 'acknowledged',
        'createdBy': 'dsqc-uid',
        'createdByName': 'DSQC Reyes',
        'officerUids': ['officer-1'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 24, 14, 40)),
        'acknowledgedAt': Timestamp.fromDate(DateTime(2026, 11, 24, 14, 42)),
      });

      expect(incident, isNotNull);
      expect(incident!.code, 'SOS-2026-0007');
      expect(incident.reason, 'Garbage truck breakdown');
      expect(incident.incidentAt, DateTime(2026, 11, 24, 14, 30));
      expect(incident.status, SosStatus.acknowledged);
      expect(incident.officerUids, ['officer-1']);
      expect(incident.isUnassigned, isFalse);
      expect(incident.isOpen, isTrue);
      expect(incident.location, 'Batasan Hills · District 2');
    });

    test('an incident without an officer is flagged', () {
      final incident = SosIncident.fromDoc('sos-2', {
        'code': 'SOS-2026-0008',
        'description': 'Missed collection on Filinvest 2.',
        'reason': 'Missed collection',
        'district': 'District 5',
        'barangay': 'Fairview',
        'status': 'pending',
        'createdBy': 'dsqc-uid',
        'createdByName': 'DSQC',
      });

      expect(incident, isNotNull);
      expect(incident!.officerUids, isEmpty);
      expect(incident.isUnassigned, isTrue);
      expect(incident.status, SosStatus.newAlert);
    });

    test('a document missing required fields is ignored', () {
      expect(SosIncident.fromDoc('x', {'code': 'SOS-1'}), isNull);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../announcements/models/announcement.dart';
import '../../announcements/services/announcement_service.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../models/delay_report.dart';

/// Delay reports: Iswim files, DSQC pushes to the district officer, barangay
/// keeps the copy.
class DelayService {
  DelayService._();
  static final DelayService instance = DelayService._();
  factory DelayService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('delay_reports');

  Stream<List<DelayReport>> watchAll() =>
      _col.orderBy('createdAt', descending: true).limit(60).snapshots().map(
            (snap) => snap.docs
                .map((doc) => DelayReport.fromDoc(doc.id, doc.data()))
                .whereType<DelayReport>()
                .toList(),
          );

  Future<DelayReport> file({
    required String plateNumber,
    required String driverName,
    required String reason,
    required int minutesLate,
    required String notes,
    required String filedBy,
    required String filedByName,
    String? ticketId,
    String? ticketCode,
  }) async {
    final code = await _nextCode();
    final report = DelayReport(
      id: '',
      code: code,
      plateNumber: plateNumber,
      driverName: driverName,
      reason: reason,
      minutesLate: minutesLate,
      notes: notes,
      stage: DelayStage.dsqc,
      filedBy: filedBy,
      filedByName: filedByName,
      ticketId: ticketId,
      ticketCode: ticketCode,
    );

    final ref = await _col.add(report.toMap());
    // DSQC receives the report first; the barangay copy is sent only after
    // DSQC forwards it to the district officer.
    await _notifications.notifyCityHall(
      title: 'Delay report · $code',
      body: '$plateNumber ($driverName) · $reason · $minutesLate min late.',
      type: AppNotificationType.route,
      data: {'delayId': ref.id, 'kind': 'delayFiled'},
    );

    final snap = await ref.get();
    return DelayReport.fromDoc(ref.id, snap.data()!)!;
  }

  Future<String> _nextCode() async {
    final year = DateTime.now().year;
    final ref = _db.collection('counters').doc('delay_reports_$year');
    final next = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final value = current + 1;
      tx.set(ref, {'value': value}, SetOptions(merge: true));
      return value;
    });
    return 'DR-$year-${next.toString().padLeft(4, '0')}';
  }

  /// DSQC pushes the report to the district officer. The officer has no login,
  /// so this is the moment the alarm has to fire on the DSQC device.
  Future<void> forwardToDistrictOfficer(DelayReport report) async {
    await _col.doc(report.id).update({
      'stage': DelayStage.districtOfficer.wireName,
      'forwardedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The barangay copy — written when the officer's copy goes out.
  Future<void> sendToBarangay(DelayReport report) async {
    await _col.doc(report.id).update({
      'stage': DelayStage.barangay.wireName,
      'barangayAt': FieldValue.serverTimestamp(),
    });
    await _notifications.notifyStaff(
      title: 'Delay report copy · ${report.code}',
      body: '${report.plateNumber} · ${report.reason} · '
          '${report.minutesLate} min late.',
      type: AppNotificationType.route,
      data: {'delayId': report.id, 'kind': 'delayBarangay'},
    );
  }

  /// The barangay tells residents: a published "Collection delay"
  /// announcement (which notifies every resident), then the report is closed.
  Future<void> announceToResidents(
    DelayReport report, {
    required String authorId,
    required String authorName,
  }) async {
    final minutes = report.minutesLate;
    final late = minutes >= 60
        ? '${minutes ~/ 60} hr${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}'
        : '$minutes min';
    final notes = report.notes.trim();
    final announcementId = await AnnouncementService().save(
      title: 'Garbage collection delayed (truck ${report.plateNumber})',
      body: 'Today\'s collection by truck ${report.plateNumber} is running '
          'about $late late: ${report.reason}.'
          '${notes.isEmpty ? '' : ' $notes'}'
          ' Please keep your garbage ready; the truck will still come.',
      category: AnnouncementCategory.delay,
      status: AnnouncementStatus.published,
      authorId: authorId,
      authorName: authorName,
    );
    await _col.doc(report.id).update({
      'announcementId': announcementId,
      'announcedAt': FieldValue.serverTimestamp(),
      'stage': DelayStage.closed.wireName,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> close(DelayReport report) async {
    await _col.doc(report.id).update({
      'stage': DelayStage.closed.wireName,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }
}

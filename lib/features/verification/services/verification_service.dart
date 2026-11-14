import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/verification_request.dart';
import '../../auth/models/account_type.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('verificationRequests');

  Stream<List<VerificationRequest>> watchAll() {
    return _col.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => VerificationRequest.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final aDate = a.submittedAt ?? DateTime(2000);
          final bDate = b.submittedAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  Stream<VerificationRequest?> watchMine(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return VerificationRequest.fromDoc(
        snap.docs.first.id,
        snap.docs.first.data(),
      );
    });
  }

  Future<void> approve({
    required VerificationRequest request,
    required String reviewerId,
    required String reviewerName,
  }) async {
    final batch = _db.batch();
    batch.update(_col.doc(request.id), {
      'status': VerificationStatus.verified.name,
      'reviewedBy': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
    batch.update(_db.collection('users').doc(request.userId), {
      'accountType': AccountType.government.name,
      'verificationStatus': VerificationStatus.verified.name,
      'verifiedBy': reviewerId,
      'verificationDate': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
    await batch.commit();

    await _notifications.push(
      userId: request.userId,
      title: 'Account verified',
      body:
          'Your government personnel account is verified. You can now submit special collection requests.',
      type: AppNotificationType.verification,
      data: {'verificationId': request.id},
    );
  }

  Future<void> reject({
    required VerificationRequest request,
    required String reviewerId,
    required String reviewerName,
    required String reason,
  }) async {
    final batch = _db.batch();
    batch.update(_col.doc(request.id), {
      'status': VerificationStatus.rejected.name,
      'reviewedBy': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason.trim(),
    });
    batch.update(_db.collection('users').doc(request.userId), {
      'verificationStatus': VerificationStatus.rejected.name,
      'rejectionReason': reason.trim(),
    });
    await batch.commit();

    await _notifications.push(
      userId: request.userId,
      title: 'Verification needs attention',
      body: reason.trim().isEmpty
          ? 'Your government ID could not be verified. Please upload a clearer document.'
          : reason.trim(),
      type: AppNotificationType.verification,
      data: {'verificationId': request.id},
    );
  }

  /// Marks a regular resident account verified (or rejected) without an ID.
  ///
  /// Verifying a resident is also the barangay's registration approval: the
  /// account moves to `approved` and the resident is asked to accept or
  /// decline. Accounts already answered (accepted / declined) keep their
  /// answer, so a later re-verification does not reopen the decision.
  Future<void> setUserVerification({
    required String userId,
    required VerificationStatus status,
    required String reviewerId,
    required String reviewerName,
    String? reason,
  }) async {
    final doc = await _db.collection('users').doc(userId).get();
    final current = doc.data()?['registrationStatus'] as String? ?? 'accepted';
    final openDecision = current == 'pending';
    final approved = status == VerificationStatus.verified;

    await _db.collection('users').doc(userId).update({
      'verificationStatus': status.name,
      'verifiedBy': reviewerId,
      'verificationDate': FieldValue.serverTimestamp(),
      'rejectionReason': status == VerificationStatus.rejected ? reason : null,
      if (approved && openDecision) ...{
        'registrationStatus': 'approved',
        'registrationApprovedAt': FieldValue.serverTimestamp(),
      },
      // A rejected registration stays open for correction and resubmission.
      if (!approved && current == 'approved')
        'registrationStatus': 'pending',
    });

    if (approved && openDecision) {
      await _notifications.push(
        userId: userId,
        title: 'Barangay approved your registration',
        body:
            'Open your dashboard to accept or decline the approval. Your answer is recorded with the date and time.',
        type: AppNotificationType.account,
      );
      return;
    }

    await _notifications.push(
      userId: userId,
      title: approved ? 'Account verified' : 'Verification rejected',
      body: approved
          ? 'Barangay staff verified your account.'
          : (reason?.trim().isNotEmpty == true
              ? reason!.trim()
              : 'Barangay staff could not verify your account.'),
      type: AppNotificationType.verification,
    );
  }
}

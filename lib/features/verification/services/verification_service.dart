import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_payload.dart';
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
      final items =
          snap.docs
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

  /// The ID a resident uploaded at sign-up (stored under their uid), if any.
  Future<VerificationRequest?> fetchForUser(String userId) async {
    final doc = await _col.doc(userId).get();
    final data = doc.data();
    return data == null ? null : VerificationRequest.fromDoc(doc.id, data);
  }

  Stream<VerificationRequest?> watchMine(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;
      return VerificationRequest.fromDoc(
        snap.docs.first.id,
        snap.docs.first.data(),
      );
    });
  }

  /// Uploads or replaces the signed-in resident's ID.
  ///
  /// The barangay desk reads the same document it reviewed at sign-up, so a
  /// rejected resident can correct the photo without creating a new account.
  Future<void> submitId({
    required String userId,
    required String name,
    required String email,
    required String? phone,
    required String? barangay,
    required UploadPayload document,
  }) async {
    final ref = _col.doc(userId);
    final existing = await ref.get();
    final payload = <String, dynamic>{
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'barangay': barangay,
      'accountType': AccountType.resident.name,
      'document': document.toMap(),
      'status': VerificationStatus.pending.name,
      'rejectionReason': null,
      'submittedAt': FieldValue.serverTimestamp(),
    };

    if (existing.exists) {
      await ref.update(payload);
    } else {
      await ref.set(payload);
    }

    // Best effort. A resident whose account is still pending may not be allowed
    // to post the staff alert yet (the rules reserve that for the sign-up
    // notice), but the ID itself is already saved and appears in the barangay
    // verification queue. A failed alert must not look like a failed upload.
    try {
      await _notifications.notifyStaff(
        title: 'Resident uploaded an ID',
        body: '$name submitted an ID for verification.',
        type: AppNotificationType.verification,
        data: {'uid': userId, 'kind': 'residentId'},
        dedupeKey:
            'resident_id_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      AppLogger.error('Could not alert staff about a new resident ID', e);
    }
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
    final data = doc.data() ?? const <String, dynamic>{};
    final current = data['registrationStatus'] as String? ?? 'accepted';
    final openDecision = current == 'pending';
    final approved = status == VerificationStatus.verified;
    // A resident whose registration was turned down (usually a blurry ID) can
    // be let back in when the desk accepts a corrected one. Without this the
    // account stays declined for good and the resident can never sign in.
    final reopening =
        approved &&
        (current == 'rejected' || data['accountStatus'] == 'declined');

    // A new sign-up cannot sign in until this decision: approving it activates
    // the account, rejecting it blocks sign-in and shows the reason at login.
    final rejected = status == VerificationStatus.rejected;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(userId), {
      'verificationStatus': status.name,
      'verifiedBy': reviewerId,
      'verificationDate': FieldValue.serverTimestamp(),
      'rejectionReason': rejected ? reason : null,
      if (approved && (openDecision || reopening)) ...{
        'registrationStatus': 'approved',
        'registrationApprovedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
      },
      if (rejected && openDecision) ...{
        'registrationStatus': 'rejected',
        'accountStatus': 'declined',
      },
      // A rejected registration stays open for correction and resubmission.
      if (!approved && current == 'approved') 'registrationStatus': 'pending',
    });
    // The uploaded ID gets the same decision.
    final idRef = _col.doc(userId);
    if ((await idRef.get()).exists && (approved || rejected)) {
      batch.update(idRef, {
        'status': status.name,
        'reviewedBy': reviewerName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': rejected ? reason : null,
      });
    }
    await batch.commit();

    if (approved && (openDecision || reopening)) {
      await _notifications.push(
        userId: userId,
        title: openDecision
            ? 'Barangay approved your registration'
            : 'Barangay reopened your account',
        body:
            'Your ID was checked and your account is active. Sign in, then accept or decline the approval on your dashboard.',
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

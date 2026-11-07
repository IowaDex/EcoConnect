import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/image_payload.dart';
import '../../auth/models/account_type.dart';

DateTime? _asDate(dynamic raw) => raw is Timestamp ? raw.toDate() : null;

/// A government personnel ID submitted for barangay review.
///
/// Stored separately from the user profile so the document is only readable
/// by its owner and by barangay staff, never by other residents.
class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.accountType,
    this.phone,
    this.barangay,
    this.document,
    this.status = VerificationStatus.pending,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final AccountType accountType;
  final String? phone;
  final String? barangay;
  final UploadPayload? document;
  final VerificationStatus status;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  static VerificationRequest fromDoc(String id, Map<String, dynamic> data) {
    return VerificationRequest(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Applicant',
      email: (data['email'] as String?) ?? '',
      accountType: AccountTypeX.fromName(data['accountType'] as String?),
      phone: data['phone'] as String?,
      barangay: data['barangay'] as String?,
      document: UploadPayload.fromMap(data['document']),
      status: VerificationStatusX.fromName(data['status'] as String?),
      submittedAt: _asDate(data['submittedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: _asDate(data['reviewedAt']),
      rejectionReason: data['rejectionReason'] as String?,
    );
  }
}

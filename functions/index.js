const {initializeApp} = require('firebase-admin/app');
const {FieldValue, Timestamp, getFirestore} =
  require('firebase-admin/firestore');
const {logger} = require('firebase-functions');
const {
  onDocumentWrittenWithAuthContext,
} = require('firebase-functions/v2/firestore');
const {
  auditableFields,
  changedFields,
  classifyChange,
} = require('./audit_helpers');

initializeApp();

async function writeAuditEntry(event) {
  const beforeSnapshot = event.data?.before;
  const afterSnapshot = event.data?.after;
  const before = beforeSnapshot?.exists ? beforeSnapshot.data() : null;
  const after = afterSnapshot?.exists ? afterSnapshot.data() : null;
  const action = classifyChange(Boolean(before), Boolean(after));
  const fields = auditableFields(
      event.document,
      changedFields(before, after),
  );

  if (action === 'update' && fields.length === 0) return;
  if (fields.length === 0) return;

  const pathSegments = event.document.split('/');
  const collectionPath = pathSegments
      .filter((_, index) => index % 2 === 0)
      .join('/');
  const occurredAt = event.time
    ? Timestamp.fromDate(new Date(event.time))
    : FieldValue.serverTimestamp();
  const auditRef = getFirestore()
      .collection('admin_audit')
      .doc(event.id);

  try {
    await auditRef.create({
      action,
      actorUid: event.authId ?? null,
      actorType: event.authType ?? 'unknown',
      collectionPath,
      documentId: pathSegments[pathSegments.length - 1],
      documentPath: event.document,
      changedFields: fields,
      eventId: event.id,
      outcome: 'committed',
      at: occurredAt,
      recordedAt: FieldValue.serverTimestamp(),
      source: 'firestore-trigger',
    });
  } catch (error) {
    if (error.code === 6 || error.code === '6' ||
        error.code === 'already-exists') {
      return;
    }
    logger.error('Could not write Firestore audit entry', {
      eventId: event.id,
      document: event.document,
      error,
    });
    throw error;
  }
}

const auditedDocuments = {
  auditUserProfiles: 'users/{userId}',
  auditVerificationRequests: 'verificationRequests/{requestId}',
  auditAnnouncements: 'announcements/{announcementId}',
  auditEvents: 'events/{eventId}',
  auditEventParticipants: 'events/{eventId}/participants/{participantId}',
  auditCollectionRequests: 'collectionRequests/{requestId}',
  auditWasteSubmissions: 'wasteSubmissions/{submissionId}',
  auditCollectionPoints: 'collectionPoints/{pointId}',
  auditRoutes: 'routes/{driverId}',
  auditRoutePlans: 'routePlans/{planId}',
  auditTickets: 'trip_tickets/{ticketId}',
  auditIncidents: 'incidents/{incidentId}',
  auditComplaints: 'complaints/{complaintId}',
  auditDropOffs: 'dropOffs/{dropOffId}',
  auditPointsTransactions: 'points_transactions/{entryId}',
  auditResidentPointsTransactions:
    'users/{userId}/points_transactions/{entryId}',
  auditCommunityPosts: 'communityPosts/{postId}',
  auditTrucks: 'trucks/{truckId}',
  auditDelayReports: 'delay_reports/{reportId}',
  auditMemos: 'memos/{memoId}',
  auditEmailLog: 'email_log/{entryId}',
  auditManuals: 'manuals/{manualId}',
  auditManualVersions: 'manuals/{manualId}/versions/{versionId}',
  auditManualRequests: 'manual_requests/{requestId}',
  auditSessions: 'sessions/{userId}',
  auditRemovedUsers: 'removed_users/{userId}',
  auditDistrictOfficerSettings: 'settings/districtOfficer',
};

for (const [name, document] of Object.entries(auditedDocuments)) {
  exports[name] = onDocumentWrittenWithAuthContext(
      {document, retry: true},
      writeAuditEntry,
  );
}

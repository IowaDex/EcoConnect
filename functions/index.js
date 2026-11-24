const {initializeApp} = require('firebase-admin/app');
const {FieldValue, Timestamp, getFirestore} =
  require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {logger} = require('firebase-functions');
const {
  onDocumentWrittenWithAuthContext,
  onDocumentCreated,
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

// --- Device push notifications -------------------------------------------------
// Every in-app notification is a Firestore document. This trigger turns it
// into a device push: a personal alert goes to that user's device tokens, a
// desk channel goes to every active account on that desk.

const DESK_ROLES = {
  staff: 'admin',
  cityHall: 'cityHall',
  iswim: 'iswim',
  districtOfficer: 'districtOfficer',
};

async function deviceTokensFor(uid) {
  const snap = await getFirestore()
      .collection('users')
      .doc(uid)
      .collection('devices')
      .get();
  return snap.docs
      .map((doc) => ({ref: doc.ref, token: doc.data().token}))
      .filter((entry) => typeof entry.token === 'string' && entry.token);
}

async function targetUids(userId) {
  const deskRole = DESK_ROLES[userId];
  if (!deskRole) return [userId];
  const users = await getFirestore()
      .collection('users')
      .where('role', '==', deskRole)
      .get();
  return users.docs
      .filter((doc) => (doc.data().accountStatus || 'active') === 'active')
      .map((doc) => doc.id);
}

exports.pushNotification = onDocumentCreated(
    {document: 'notifications/{notificationId}', retry: true},
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const notification = snapshot.data();
      const userId = notification.userId;
      if (typeof userId !== 'string' || !userId) return;

      const uids = await targetUids(userId);
      const entries = [];
      for (const uid of uids) {
        entries.push(...await deviceTokensFor(uid));
      }
      if (entries.length === 0) return;

      const tokens = [...new Set(entries.map((entry) => entry.token))];
      const data = {};
      for (const [key, value] of Object.entries(notification.data || {})) {
        if (value !== null && value !== undefined) data[key] = String(value);
      }
      data.notificationId = event.params.notificationId;
      data.type = notification.type || 'system';

      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: notification.title || 'EcoConnect',
          body: notification.body || '',
        },
        data,
        android: {priority: 'high'},
        apns: {payload: {aps: {sound: 'default'}}},
      });

      // Remove tokens FCM no longer recognises, so the list does not grow.
      const stale = new Set();
      response.responses.forEach((result, index) => {
        if (result.success) return;
        const code = result.error?.code || '';
        if (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-argument' ||
            code === 'messaging/invalid-registration-token') {
          stale.add(tokens[index]);
        }
      });
      if (stale.size > 0) {
        const batch = getFirestore().batch();
        for (const entry of entries) {
          if (stale.has(entry.token)) batch.delete(entry.ref);
        }
        await batch.commit();
      }

      logger.info('Push sent', {
        notificationId: event.params.notificationId,
        success: response.successCount,
        failure: response.failureCount,
      });
    },
);

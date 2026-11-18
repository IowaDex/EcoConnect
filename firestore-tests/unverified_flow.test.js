// End-to-end check of the unverified resident flow against the Firestore
// emulator and the real rules:
//
//   sign up (pending) -> track the truck + submit an ID
//                     -> request / waste / complaint / community are refused
//   barangay approves -> the same account may do all of them
//
// Run with:
//   firebase emulators:exec --only firestore --project demo-ecoconnect-unverified \
//     "node --test unverified_flow.test.js"
const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  doc,
  setDoc,
  updateDoc,
  getDoc,
} = require('firebase/firestore');

let env;

const as = (uid, emailVerified = true) =>
  env.authenticatedContext(uid, {email_verified: emailVerified}).firestore();

const asSignedInAt = (uid, authTime) =>
  env.authenticatedContext(uid, {
    email_verified: true,
    auth_time: authTime,
  }).firestore();

const pendingProfile = {
  name: 'Pending Resident',
  role: 'user',
  accountStatus: 'pending',
  registrationStatus: 'pending',
  accountType: 'resident',
  verificationStatus: 'pending',
  barangay: 'Batasan Hills',
  emailVerified: true,
};

const activeProfile = {
  ...pendingProfile,
  accountStatus: 'active',
  registrationStatus: 'accepted',
  verificationStatus: 'verified',
};

const idDocument = (uid, marker = 'AAAA') => ({
  userId: uid,
  name: 'Pending Resident',
  email: 'pending@example.com',
  phone: '+639000000000',
  barangay: 'Batasan Hills',
  accountType: 'resident',
  document: {dataUrl: `data:image/png;base64,${marker}`},
  status: 'pending',
  submittedAt: Timestamp.now(),
});

const collectionRequest = (uid) => ({
  requesterId: uid,
  status: 'pending',
  kind: 'resident',
  title: 'Extra pickup',
  description: 'Two sacks of residual waste.',
  estimatedQuantity: '2 sacks',
  location: 'Block 12, Batasan Hills',
  preferredDate: Timestamp.now(),
  images: [],
  createdAt: Timestamp.now(),
});

const wasteSubmission = (uid) => ({
  userId: uid,
  status: 'pending',
  description: 'Segregated recyclables.',
  images: [{dataUrl: 'data:image/png;base64,AAAA'}],
  createdAt: Timestamp.now(),
});

const complaint = (uid) => ({
  residentId: uid,
  status: 'pending',
  referenceNo: 'REF-UNVERIFIED-1',
  title: 'Truck skipped our street',
  description: 'No collection on our street today.',
  images: [],
  createdAt: Timestamp.now(),
});

const communityPost = (uid) => ({
  authorId: uid,
  body: 'Hello neighbours.',
  createdAt: Timestamp.now(),
});

const session = (id, authTime = 1000) => ({
  sessionId: id,
  startedAt: Timestamp.now(),
  platform: 'web',
  authTime,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ecoconnect-unverified',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/pending'), pendingProfile);
    await setDoc(doc(db, 'users/active'), activeProfile);
    await setDoc(doc(db, 'users/root'), {name: 'Root', role: 'admin'});
    await setDoc(doc(db, 'routes/dan'), {
      status: 'inTransit',
      driverName: 'Dan',
      lat: 14.6,
      lng: 121.0,
      lastSeenAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'routePlans/plan1'), {
      driverId: 'dan',
      status: 'active',
      stops: [{name: 'Purok 1', lat: 14.6, lng: 121.0}],
    });
    await setDoc(doc(db, 'announcements/a1'), {status: 'published'});
  });
});

test('an unverified resident can track the truck and submit an ID', async () => {
  // The tracking map needs the live route and the active plan behind it.
  await assertSucceeds(getDoc(doc(as('pending'), 'routes/dan')));
  await assertSucceeds(getDoc(doc(as('pending'), 'routePlans/plan1')));

  // The dashboard uploader writes the ID under the resident's own uid.
  await assertSucceeds(
    setDoc(
      doc(as('pending'), 'verificationRequests/pending'),
      idDocument('pending'),
    ),
  );

  // A clearer photo can replace the first one while review is pending.
  await assertSucceeds(
    updateDoc(doc(as('pending'), 'verificationRequests/pending'), {
      document: {dataUrl: 'data:image/png;base64,BBBB'},
      status: 'pending',
    }),
  );
});

test('an unverified resident cannot request, report or upload waste', async () => {
  await assertFails(
    setDoc(
      doc(as('pending'), 'collectionRequests/r1'),
      collectionRequest('pending'),
    ),
  );
  await assertFails(
    setDoc(
      doc(as('pending'), 'wasteSubmissions/w1'),
      wasteSubmission('pending'),
    ),
  );
  await assertFails(
    setDoc(doc(as('pending'), 'complaints/c1'), complaint('pending')),
  );
  await assertFails(
    setDoc(doc(as('pending'), 'communityPosts/p1'), communityPost('pending')),
  );

  // No active account means no single-device session claim yet.
  await assertFails(
    setDoc(
      doc(asSignedInAt('pending', 1000), 'sessions/pending'),
      session('a'.repeat(32)),
    ),
  );

  // The ID upload's staff alert is 'verification' and is refused for a
  // pending account; the service treats that as best effort. The sign-up
  // notice ('account') is the one alert the rules allow.
  await assertFails(
    setDoc(doc(as('pending'), 'notifications/verification-alert'), {
      userId: 'staff',
      title: 'Resident uploaded an ID',
      body: 'Pending Resident submitted an ID.',
      type: 'verification',
      read: false,
      createdAt: Timestamp.now(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(as('pending'), 'notifications/registration-alert'), {
      userId: 'staff',
      title: 'New resident registration',
      body: 'Pending Resident confirmed their email.',
      type: 'account',
      read: false,
      createdAt: Timestamp.now(),
    }),
  );
});

test('the same account unlocks after barangay approval', async () => {
  // The barangay desk approves the ID.
  await assertSucceeds(
    updateDoc(doc(as('root'), 'users/pending'), {
      accountStatus: 'active',
      registrationStatus: 'accepted',
      verificationStatus: 'verified',
    }),
  );

  await assertSucceeds(
    setDoc(
      doc(as('pending'), 'collectionRequests/r1'),
      collectionRequest('pending'),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(as('pending'), 'wasteSubmissions/w1'),
      wasteSubmission('pending'),
    ),
  );
  await assertSucceeds(
    setDoc(doc(as('pending'), 'complaints/c1'), complaint('pending')),
  );
  await assertSucceeds(
    setDoc(doc(as('pending'), 'communityPosts/p1'), communityPost('pending')),
  );

  // And the tracking reads still work.
  await assertSucceeds(getDoc(doc(as('pending'), 'routes/dan')));
  await assertSucceeds(getDoc(doc(as('pending'), 'routePlans/plan1')));

  // Approval also lets the device claim its single session. This is last:
  // once the session records a newer auth time, an older token is a replaced
  // device and is refused everywhere.
  await assertSucceeds(
    setDoc(
      doc(asSignedInAt('pending', 2000), 'sessions/pending'),
      session('b'.repeat(32), 2000),
    ),
  );
});

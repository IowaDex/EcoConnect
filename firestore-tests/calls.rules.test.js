// Rules for the in-app voice calls: `calls/{id}` (the ringing invitation and
// the WebRTC signalling channel) and `call_logs/{id}` (the durable history).
//
// This file exists because the desk was getting `permission-denied` while
// listening for incoming calls, so it pins down exactly who may read them.
const {test, before, after, beforeEach} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  where,
} = require('firebase/firestore');

let env;

const as = (uid) => env.authenticatedContext(uid, {email_verified: true}).firestore();
const seed = (fn) => env.withSecurityRulesDisabled((c) => fn(c.firestore()));

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ecoconnect-calls',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    const user = (name, role, extra = {}) => ({
      name,
      role,
      accountStatus: 'active',
      ...extra,
    });
    await setDoc(doc(db, 'users/dsqc'), user('DSQC', 'cityHall'));
    await setDoc(doc(db, 'users/officer'), user('Officer', 'districtOfficer', {district: 'District 2'}));
    await setDoc(doc(db, 'users/staff'), user('Staff', 'admin', {barangay: 'Batasan Hills'}));
    await setDoc(doc(db, 'users/resident'), user('Resident', 'user'));
    await setDoc(doc(db, 'calls/c1'), {
      fromUid: 'officer',
      fromName: 'Officer',
      fromRole: 'districtOfficer',
      toRole: 'admin',
      calleeId: 'staff',
      status: 'ringing',
      context: 'sos',
      incidentId: 'sos1',
      participantIds: ['officer', 'staff'],
    });
    await setDoc(doc(db, 'call_logs/l1'), {
      callId: 'c1',
      incidentId: 'sos1',
      participantIds: ['officer', 'staff'],
    });
  });
});

const ringingQuery = (db) =>
  query(collection(db, 'calls'), where('status', '==', 'ringing'));

test('the three desks can listen for a ringing call', async () => {
  for (const uid of ['dsqc', 'officer', 'staff']) {
    await assertSucceeds(getDocs(ringingQuery(as(uid))));
  }
});

test('a resident cannot listen for calls', async () => {
  await assertFails(getDocs(ringingQuery(as('resident'))));
});

test('a participant reads the call history of their own call', async () => {
  await assertSucceeds(
    getDocs(query(collection(as('officer'), 'call_logs'), where('participantIds', 'array-contains', 'officer'))),
  );
  await assertSucceeds(
    getDocs(query(collection(as('staff'), 'call_logs'), where('participantIds', 'array-contains', 'staff'))),
  );
});

test('City Hall reads any call history, a stranger reads none', async () => {
  await assertSucceeds(getDocs(collection(as('dsqc'), 'call_logs')));
  await assertFails(getDocs(collection(as('resident'), 'call_logs')));
});

test('an officer cannot open another desk call log by id', async () => {
  await seed((db) =>
    setDoc(doc(db, 'call_logs/other'), {
      callId: 'c9',
      participantIds: ['dsqc', 'staff'],
    }),
  );
  await assertFails(getDoc(doc(as('officer'), 'call_logs/other')));
});

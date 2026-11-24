// Rules for the SOS board: `sos_incidents/{id}`.
//
// The District Officer dashboard was showing "Could not load the SOS board.
// [cloud_firestore/permission-denied]", so this pins down the two list queries
// `SosService` actually runs, not just single-document reads:
//   * an officer with a district -> where('district', '==', that district)
//   * an officer without one      -> where('officerUids', 'array-contains', uid)
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
    projectId: 'demo-ecoconnect-sos',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(() => env.cleanup());

const incident = (extra = {}) => ({
  code: 'SOS-1',
  description: 'Truck stalled on the corner of IBP road.',
  reason: 'breakdown',
  incidentAt: new Date('2026-11-24T02:00:00Z'),
  district: 'District 2',
  barangay: 'Batasan Hills',
  status: 'newAlert',
  createdBy: 'dsqc',
  officerUids: [],
  ...extra,
});

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
    await setDoc(doc(db, 'users/officer2'), user('Officer 2', 'districtOfficer', {district: 'District 4'}));
    await setDoc(doc(db, 'users/floating'), user('Floating', 'districtOfficer'));
    await setDoc(doc(db, 'users/staff'), user('Staff', 'admin', {barangay: 'Batasan Hills'}));
    await setDoc(doc(db, 'users/resident'), user('Resident', 'user'));
    await setDoc(doc(db, 'sos_incidents/mine'), incident());
    await setDoc(doc(db, 'sos_incidents/other'), incident({code: 'SOS-2', district: 'District 4'}));
    await setDoc(doc(db, 'sos_incidents/named'), incident({
      code: 'SOS-3',
      district: 'District 4',
      officerUids: ['floating'],
    }));
  });
});

test('an officer lists the incidents of their own district', async () => {
  await assertSucceeds(
    getDocs(query(collection(as('officer'), 'sos_incidents'), where('district', '==', 'District 2'))),
  );
});

test('an officer cannot list another district', async () => {
  await assertFails(
    getDocs(query(collection(as('officer2'), 'sos_incidents'), where('district', '==', 'District 2'))),
  );
});

test('an officer with no district lists the incidents that named them', async () => {
  await assertSucceeds(
    getDocs(query(collection(as('floating'), 'sos_incidents'), where('officerUids', 'array-contains', 'floating'))),
  );
});

test('an officer opens an incident of their district by id', async () => {
  await assertSucceeds(getDoc(doc(as('officer'), 'sos_incidents/mine')));
  await assertFails(getDoc(doc(as('officer'), 'sos_incidents/other')));
});

test('City Hall lists every incident', async () => {
  await assertSucceeds(getDocs(collection(as('dsqc'), 'sos_incidents')));
});

test('the barangay desk lists its own barangay', async () => {
  await assertSucceeds(
    getDocs(query(collection(as('staff'), 'sos_incidents'), where('barangay', '==', 'Batasan Hills'))),
  );
});

test('a resident reads none', async () => {
  await assertFails(getDocs(collection(as('resident'), 'sos_incidents')));
});

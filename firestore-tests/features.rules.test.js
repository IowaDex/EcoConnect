// Rules for the feature collections: requests, announcements, events, waste,
// verification, route plans, collection points, live routes and the staff
// notification channel. Denials matter most: a rule that is too loose still
// passes every "allowed" case.
//
// Uses its own emulator project so it can run in parallel with rules.test.js.
const {test, before, after, beforeEach} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

let env;

const as = (uid) => env.authenticatedContext(uid, {email_verified: true}).firestore();
const seed = (fn) => env.withSecurityRulesDisabled((c) => fn(c.firestore()));
const text = (n) => 'x'.repeat(n);
const photo = {dataUrl: 'data:image/jpeg;base64,AAAA'};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ecoconnect-features',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    const user = (name, role, extra = {}) => ({name, role, accountStatus: 'active', ...extra});
    await setDoc(doc(db, 'users/alice'), user('Alice', 'user'));
    await setDoc(doc(db, 'users/bob'), user('Bob', 'user'));
    await setDoc(doc(db, 'users/dan'), user('Dan', 'driver'));
    await setDoc(doc(db, 'users/eli'), user('Eli', 'driver'));
    await setDoc(doc(db, 'users/root'), user('Root', 'admin'));
    await setDoc(doc(db, 'users/gina'), user('Gina', 'user', {accountType: 'government', verificationStatus: 'verified'}));
    await setDoc(doc(db, 'users/ugo'), user('Ugo', 'user', {accountType: 'government', verificationStatus: 'pending'}));
  });
});

// ---------------------------------------------------------------- accounts

test('nobody can self-verify, change account type or clear a rejection', async () => {
  const alice = doc(as('alice'), 'users/alice');
  await assertFails(updateDoc(alice, {accountType: 'government'}));
  await assertFails(updateDoc(alice, {verificationStatus: 'verified'}));
  await assertFails(updateDoc(alice, {rejectionReason: 'none'}));
  await assertFails(updateDoc(alice, {verifiedBy: 'alice'}));
  await assertSucceeds(updateDoc(alice, {phone: '0917'}));
  await assertSucceeds(updateDoc(doc(as('root'), 'users/ugo'), {verificationStatus: 'verified'}));
});

test('signup can ask for government review but not skip it', async () => {
  const base = {name: 'E', role: 'user', accountStatus: 'pending'};
  const gov = {...base, accountType: 'government'};
  await assertFails(setDoc(doc(as('e1'), 'users/e1'), {...gov, verificationStatus: 'verified'}));
  await assertFails(setDoc(doc(as('e2'), 'users/e2'), {...base, accountType: 'admin'}));
  await assertFails(setDoc(doc(as('e3'), 'users/e3'), {...base, accountType: 'resident', verificationStatus: 'verified'}));
  await assertSucceeds(setDoc(doc(as('e4'), 'users/e4'), {...gov, verificationStatus: 'pending'}));
  // Every resident's ID now waits for the barangay too.
  await assertSucceeds(setDoc(doc(as('e5'), 'users/e5'), {...base, accountType: 'resident', verificationStatus: 'pending'}));
});

// -------------------------------------------------------- collectionRequests

const request = (requesterId, overrides = {}) => ({
  requesterId,
  status: 'pending',
  kind: 'resident',
  title: 'Old furniture',
  description: 'A sofa by the gate',
  estimatedQuantity: '1 sofa',
  location: 'Purok 1',
  preferredDate: Timestamp.now(),
  ...overrides,
});

test('every approved resident may send a special request; crews may not', async () => {
  // All residents had their ID checked by the barangay at sign-up.
  const special = {kind: 'special'};
  await assertSucceeds(setDoc(doc(as('alice'), 'collectionRequests/a'), request('alice')));
  await assertSucceeds(setDoc(doc(as('alice'), 'collectionRequests/b'), request('alice', special)));
  await assertSucceeds(setDoc(doc(as('gina'), 'collectionRequests/d'), request('gina', special)));
  await assertFails(setDoc(doc(as('dan'), 'collectionRequests/e'), request('dan', special)));
  // Residents report garbage the truck missed (wave 2); unknown kinds fail.
  await assertSucceeds(setDoc(doc(as('bob'), 'collectionRequests/g'), request('bob', {kind: 'uncollected'})));
  await assertFails(setDoc(doc(as('bob'), 'collectionRequests/h'), request('bob', {kind: 'vip'})));
  // A resident still waiting for the barangay cannot send anything.
  await seed((db) => setDoc(doc(db, 'users/pat'), {name: 'Pat', role: 'user', accountStatus: 'pending'}));
  await assertFails(setDoc(doc(as('pat'), 'collectionRequests/f'), request('pat', special)));
});

test('a request is created as the caller, pending, with valid fields and photos', async () => {
  const create = (id, data) => setDoc(doc(as('alice'), `collectionRequests/${id}`), data);
  await assertFails(create('a', request('bob')));
  await assertFails(create('b', request('alice', {status: 'collected'})));
  await assertFails(create('c', request('alice', {kind: 'bulk'})));
  await assertFails(create('d', request('alice', {title: text(161)})));
  await assertFails(create('e', request('alice', {preferredDate: 'tomorrow'})));
  await assertFails(create('f', request('alice', {images: [photo, photo, photo, photo]})));
  await assertFails(create('g', request('alice', {images: [{name: 'no data url'}]})));
  await assertSucceeds(create('h', request('alice', {images: []})));
  await assertSucceeds(create('i', request('alice', {images: [photo, photo, photo]})));
});

test('only the requester, the assigned driver and staff can read a request', async () => {
  await seed((db) => setDoc(doc(db, 'collectionRequests/r1'), request('alice', {assignedDriverId: 'dan'})));
  const read = (uid) => getDoc(doc(as(uid), 'collectionRequests/r1'));
  await assertSucceeds(read('alice'));
  await assertSucceeds(read('dan'));
  await assertSucceeds(read('root'));
  await assertFails(read('bob'));
  await assertFails(read('eli'));
});

test('the assigned driver can only advance their own job', async () => {
  await seed((db) => setDoc(doc(db, 'collectionRequests/r1'), request('alice', {assignedDriverId: 'dan'})));
  const job = (uid) => doc(as(uid), 'collectionRequests/r1');
  await assertSucceeds(updateDoc(job('dan'), {status: 'inProgress'}));
  await assertSucceeds(updateDoc(job('dan'), {status: 'collected'}));
  await assertFails(updateDoc(job('dan'), {status: 'pending'}));
  await assertFails(updateDoc(job('dan'), {title: 'renamed'}));
  await assertFails(updateDoc(job('dan'), {assignedDriverId: 'eli'}));
  await assertFails(updateDoc(job('eli'), {status: 'inProgress'}));
  await assertFails(updateDoc(job('alice'), {status: 'collected'}));
  await assertSucceeds(updateDoc(job('root'), {assignedDriverId: 'eli'}));
});

test('a requester can withdraw a request only while it is pending', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'collectionRequests/open'), request('alice'));
    await setDoc(doc(db, 'collectionRequests/done'), request('alice', {status: 'collected'}));
  });
  await assertFails(deleteDoc(doc(as('bob'), 'collectionRequests/open')));
  await assertSucceeds(deleteDoc(doc(as('alice'), 'collectionRequests/open')));
  await assertFails(deleteDoc(doc(as('alice'), 'collectionRequests/done')));
  await assertSucceeds(deleteDoc(doc(as('root'), 'collectionRequests/done')));
});

// ------------------------------------------------- announcements and events

const announcement = (overrides = {}) => ({title: 'Schedule', body: 'Moved', status: 'published', ...overrides});
const event = (overrides = {}) => ({
  title: 'Clean-up',
  description: 'Bring gloves',
  startAt: Timestamp.now(),
  status: 'published',
  ...overrides,
});

test('residents read published announcements, never drafts, and cannot write', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'announcements/pub'), announcement());
    await setDoc(doc(db, 'announcements/draft'), announcement({status: 'draft'}));
  });
  await assertSucceeds(getDoc(doc(as('alice'), 'announcements/pub')));
  await assertFails(getDoc(doc(as('alice'), 'announcements/draft')));
  await assertSucceeds(getDoc(doc(as('root'), 'announcements/draft')));
  await assertFails(setDoc(doc(as('alice'), 'announcements/x'), announcement()));
  await assertFails(setDoc(doc(as('dan'), 'announcements/x'), announcement()));
  await assertFails(deleteDoc(doc(as('alice'), 'announcements/pub')));
});

test('announcements are validated before staff can publish them', async () => {
  const create = (id, data) => setDoc(doc(as('root'), `announcements/${id}`), data);
  await assertSucceeds(create('a', announcement()));
  await assertFails(create('b', announcement({title: text(161)})));
  await assertFails(create('c', announcement({body: text(4001)})));
  await assertFails(create('d', announcement({status: 'archived'})));
  await assertFails(create('e', announcement({image: {dataUrl: text(900000)}})));
  await assertSucceeds(create('f', announcement({image: photo})));
});

test('events follow the same read and write rules', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'events/pub'), event());
    await setDoc(doc(db, 'events/draft'), event({status: 'draft'}));
  });
  await assertSucceeds(getDoc(doc(as('alice'), 'events/pub')));
  await assertFails(getDoc(doc(as('alice'), 'events/draft')));
  await assertFails(setDoc(doc(as('alice'), 'events/x'), event()));
  await assertSucceeds(setDoc(doc(as('root'), 'events/x'), event()));
  await assertFails(setDoc(doc(as('root'), 'events/y'), event({startAt: 'soon'})));
  await assertFails(setDoc(doc(as('root'), 'events/z'), event({description: text(6001)})));
});

// ---------------------------------------------------------- wasteSubmissions

const waste = (userId, overrides = {}) => ({
  userId,
  status: 'pending',
  description: 'Plastic bottles',
  images: [photo],
  ...overrides,
});

test('waste uploads need one to three photos and the caller as owner', async () => {
  const create = (id, data) => setDoc(doc(as('alice'), `wasteSubmissions/${id}`), data);
  await assertSucceeds(create('a', waste('alice')));
  await assertSucceeds(create('b', waste('alice', {images: [photo, photo, photo]})));
  await assertFails(create('c', waste('alice', {images: []})));
  await assertFails(create('d', waste('alice', {images: [photo, photo, photo, photo]})));
  await assertFails(create('e', waste('bob')));
  await assertFails(create('f', waste('alice', {status: 'validated'})));
  await assertFails(create('g', waste('alice', {description: text(2001)})));
});

test('only the owner and staff read a waste upload; only staff validate it', async () => {
  await seed((db) => setDoc(doc(db, 'wasteSubmissions/w1'), waste('alice')));
  await assertSucceeds(getDoc(doc(as('alice'), 'wasteSubmissions/w1')));
  await assertSucceeds(getDoc(doc(as('root'), 'wasteSubmissions/w1')));
  await assertFails(getDoc(doc(as('bob'), 'wasteSubmissions/w1')));
  await assertFails(getDoc(doc(as('dan'), 'wasteSubmissions/w1')));
  await assertFails(updateDoc(doc(as('alice'), 'wasteSubmissions/w1'), {status: 'validated'}));
  await assertSucceeds(updateDoc(doc(as('root'), 'wasteSubmissions/w1'), {status: 'validated'}));
});

// ---------------------------------------------------- verificationRequests

const verification = (userId, overrides = {}) => ({
  userId,
  status: 'pending',
  accountType: 'government',
  document: {dataUrl: 'data:application/pdf;base64,AAAA'},
  ...overrides,
});

test('a government ID is submitted by its owner, as pending, within the size cap', async () => {
  const create = (uid, id, data) => setDoc(doc(as(uid), `verificationRequests/${id}`), data);
  await assertSucceeds(create('ugo', 'a', verification('ugo')));
  await assertFails(create('alice', 'b', verification('ugo')));
  await assertFails(create('ugo', 'c', verification('ugo', {status: 'verified'})));
  // Residents upload an ID at sign-up as well; other account types do not.
  await assertSucceeds(create('ugo', 'd', verification('ugo', {accountType: 'resident'})));
  await assertFails(create('ugo', 'g', verification('ugo', {accountType: 'admin'})));
  await assertFails(create('ugo', 'e', verification('ugo', {document: {dataUrl: text(900000)}})));
  await assertFails(create('ugo', 'f', verification('ugo', {document: 'scan.pdf'})));
});

test('an ID document is private to its owner and staff, and only staff decide it', async () => {
  await seed((db) => setDoc(doc(db, 'verificationRequests/v1'), verification('ugo')));
  await assertSucceeds(getDoc(doc(as('ugo'), 'verificationRequests/v1')));
  await assertSucceeds(getDoc(doc(as('root'), 'verificationRequests/v1')));
  await assertFails(getDoc(doc(as('alice'), 'verificationRequests/v1')));
  await assertFails(getDoc(doc(as('dan'), 'verificationRequests/v1')));
  await assertFails(updateDoc(doc(as('ugo'), 'verificationRequests/v1'), {status: 'verified'}));
  await assertFails(deleteDoc(doc(as('ugo'), 'verificationRequests/v1')));
  await assertSucceeds(updateDoc(doc(as('root'), 'verificationRequests/v1'), {status: 'verified'}));
});

// --------------------------------------------------------------- routePlans

test('residents see only the plan that is being run', async () => {
  await seed(async (db) => {
    for (const status of ['scheduled', 'active', 'completed']) {
      await setDoc(doc(db, `routePlans/${status}`), {driverId: 'dan', status});
    }
  });
  await assertSucceeds(getDoc(doc(as('alice'), 'routePlans/active')));
  await assertFails(getDoc(doc(as('alice'), 'routePlans/scheduled')));
  await assertFails(getDoc(doc(as('alice'), 'routePlans/completed')));
  await assertSucceeds(getDoc(doc(as('dan'), 'routePlans/scheduled')));
  await assertFails(getDoc(doc(as('eli'), 'routePlans/scheduled')));
  await assertSucceeds(getDoc(doc(as('root'), 'routePlans/completed')));
});

test('a driver can start or finish only their own plan and change nothing else', async () => {
  await seed((db) => setDoc(doc(db, 'routePlans/p1'), {driverId: 'dan', status: 'scheduled', zone: 'A'}));
  const plan = (uid) => doc(as(uid), 'routePlans/p1');
  await assertFails(updateDoc(plan('eli'), {status: 'active'}));
  await assertFails(updateDoc(plan('alice'), {status: 'active'}));
  await assertFails(updateDoc(plan('dan'), {driverId: 'eli'}));
  await assertFails(updateDoc(plan('dan'), {zone: 'B'}));
  await assertFails(updateDoc(plan('dan'), {status: 'scheduled'}));
  await assertSucceeds(updateDoc(plan('dan'), {status: 'active', sessionId: 's1', activatedAt: Timestamp.now()}));
  await assertFails(setDoc(doc(as('alice'), 'routePlans/p2'), {driverId: 'alice', status: 'scheduled'}));
  await assertSucceeds(setDoc(doc(as('root'), 'routePlans/p3'), {driverId: 'dan', status: 'scheduled'}));
});

// --------------------------------------------------------- collectionPoints

test('only staff manage collection points, and they must be valid', async () => {
  const point = (overrides = {}) => ({name: 'Covered court', lat: 14.6, lng: 121, status: 'active', ...overrides});
  await seed((db) => setDoc(doc(db, 'collectionPoints/c1'), point()));
  await assertSucceeds(getDoc(doc(as('alice'), 'collectionPoints/c1')));
  await assertFails(setDoc(doc(as('alice'), 'collectionPoints/x'), point()));
  await assertFails(setDoc(doc(as('dan'), 'collectionPoints/x'), point()));
  await assertFails(deleteDoc(doc(as('alice'), 'collectionPoints/c1')));
  await assertSucceeds(setDoc(doc(as('root'), 'collectionPoints/x'), point()));
  await assertFails(setDoc(doc(as('root'), 'collectionPoints/y'), point({lat: '14.6'})));
  await assertFails(setDoc(doc(as('root'), 'collectionPoints/z'), point({status: 'closed'})));
});

// ------------------------------------------------------------- live routes

test('a driver reports why their location stopped, with a known reason only', async () => {
  const live = {status: 'inTransit', lat: 1, lng: 2, updatedAt: Timestamp.now()};
  await assertSucceeds(setDoc(doc(as('dan'), 'routes/dan'), live));
  const route = doc(as('dan'), 'routes/dan');
  for (const state of ['disabled', 'permission', 'offline', 'unknown', 'ok']) {
    await assertSucceeds(updateDoc(route, {locationState: state, locationUpdatedAt: Timestamp.now()}));
  }
  await assertFails(updateDoc(route, {locationState: 'banana'}));
  await assertFails(updateDoc(route, {driverId: 'eli'}));
  await assertFails(updateDoc(doc(as('eli'), 'routes/dan'), {locationState: 'ok'}));
  await assertFails(setDoc(doc(as('alice'), 'routes/dan'), live));
  await assertSucceeds(getDoc(doc(as('alice'), 'routes/dan')));
});

// ------------------------------------------------- staff notification channel

test('the staff channel is readable only by staff, but anyone can raise an alert', async () => {
  const alert = {userId: 'staff', title: 'Driver location unavailable', body: 'Dan', read: false, type: 'route'};
  await assertSucceeds(setDoc(doc(as('dan'), 'notifications/a1'), alert));
  await assertSucceeds(setDoc(doc(as('alice'), 'notifications/a2'), alert));
  await assertSucceeds(getDoc(doc(as('root'), 'notifications/a1')));
  await assertFails(getDoc(doc(as('alice'), 'notifications/a1')));
  await assertFails(getDoc(doc(as('dan'), 'notifications/a1')));

  const mine = (uid) => query(collection(as(uid), 'notifications'), where('userId', 'in', [uid, 'staff']));
  const snap = await assertSucceeds(getDocs(mine('root')));
  if (snap.size !== 2) throw new Error(`staff should see both alerts, saw ${snap.size}`);
  await assertFails(getDocs(mine('dan')));
});

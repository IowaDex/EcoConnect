// Run with: npm run test:emulator (needs firebase-tools on PATH; starts the
// Firestore emulator, then npm test)
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
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');

let env;

const shared = (role, overrides = {}) => ({
  displayName: 'Someone',
  role,
  latitude: 1,
  longitude: 2,
  accuracy: 3,
  recordedAt: Timestamp.now(),
  ...overrides,
});

const as = (uid, emailVerified = true) =>
  env.authenticatedContext(uid, {email_verified: emailVerified}).firestore();

// A token issued at [authTime] seconds, like a device that signed in then.
const asSignedInAt = (uid, authTime) =>
  env.authenticatedContext(uid, {email_verified: true, auth_time: authTime}).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ecoconnect',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), {name: 'Alice', role: 'user'});
    await setDoc(doc(db, 'users/bob'), {name: 'Bob', role: 'user'});
    await setDoc(doc(db, 'users/dan'), {name: 'Dan', role: 'driver'});
    await setDoc(doc(db, 'users/root'), {name: 'Root', role: 'admin'});
    await setDoc(doc(db, 'users/ivy'), {name: 'Ivy', role: 'iswim'});
    await setDoc(doc(db, 'users/carl'), {name: 'Carl', role: 'cityHall'});
    await setDoc(doc(db, 'users/alice/locations/l1'), {latitude: 1});
    await setDoc(doc(db, 'shared_locations/dan'), shared('driver'));
    await setDoc(doc(db, 'shared_locations/alice'), shared('user'));
  });
});

test('nobody but the owner can read a location, not residents, drivers or admins', async () => {
  await assertSucceeds(getDoc(doc(as('alice'), 'shared_locations/alice')));
  await assertFails(getDoc(doc(as('dan'), 'shared_locations/alice')));
  await assertFails(getDoc(doc(as('root'), 'shared_locations/alice')));
  await assertFails(getDoc(doc(as('alice'), 'shared_locations/dan')));
  await assertFails(getDocs(collection(as('alice'), 'shared_locations')));
  await assertSucceeds(getDocs(collection(as('alice'), 'users/alice/locations')));
  await assertFails(getDocs(collection(as('dan'), 'users/alice/locations')));
  await assertFails(getDocs(collection(as('root'), 'users/alice/locations')));
});

test('only the owner reads or writes their login session, with a valid shape', async () => {
  const session = (id, authTime = 1000) => ({sessionId: id, startedAt: Timestamp.now(), platform: 'android', authTime});
  const id = 'a'.repeat(32);
  await assertSucceeds(setDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice'), session(id)));
  await assertSucceeds(getDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice')));
  await assertFails(getDoc(doc(as('dan'), 'sessions/alice')));
  await assertFails(getDoc(doc(as('root'), 'sessions/alice')));
  await assertFails(setDoc(doc(as('dan'), 'sessions/alice'), session(id)));
  await assertFails(setDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice'), session('short')));
  await assertFails(setDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice'), {...session(id), role: 'admin'}));
  // The recorded login time must be the token's own, not a made-up one.
  await assertFails(setDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice'), session(id, 5000)));
  await assertFails(deleteDoc(doc(asSignedInAt('alice', 1000), 'sessions/alice')));
  await assertSucceeds(deleteDoc(doc(as('root'), 'sessions/alice')));
});

test('a device replaced by a newer login is refused everywhere, the new one is not', async () => {
  const claim = (id, authTime) => ({sessionId: id, startedAt: Timestamp.now(), platform: 'android', authTime});
  const oldDevice = () => asSignedInAt('alice', 1000);
  const newDevice = () => asSignedInAt('alice', 2000);

  // Before any session exists nobody is locked out.
  await assertSucceeds(getDoc(doc(oldDevice(), 'users/alice')));

  await assertSucceeds(setDoc(doc(oldDevice(), 'sessions/alice'), claim('a'.repeat(32), 1000)));
  await assertSucceeds(getDoc(doc(oldDevice(), 'users/alice')));

  // A newer login takes over...
  await assertSucceeds(setDoc(doc(newDevice(), 'sessions/alice'), claim('b'.repeat(32), 2000)));
  await assertSucceeds(getDoc(doc(newDevice(), 'users/alice')));

  // ...and the old device can no longer read or write anything, including its own session.
  await assertFails(getDoc(doc(oldDevice(), 'users/alice')));
  await assertFails(updateDoc(doc(oldDevice(), 'users/alice'), {name: 'Al'}));
  await assertFails(getDoc(doc(oldDevice(), 'sessions/alice')));
  await assertFails(setDoc(doc(oldDevice(), 'sessions/alice'), claim('c'.repeat(32), 1000)));

  // Another account is unaffected.
  await assertSucceeds(getDoc(doc(as('dan'), 'users/dan')));
  // A driver's replaced device cannot publish a position either.
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'sessions/dan'), claim('d'.repeat(32), 3000)));
  const live = {status: 'inTransit', lat: 1, lng: 2, updatedAt: Timestamp.now()};
  await assertFails(setDoc(doc(asSignedInAt('dan', 1000), 'routes/dan'), live));
  await assertSucceeds(setDoc(doc(asSignedInAt('dan', 3000), 'routes/dan'), live));
});

test('event sign-ups: own row only, fixed shape, create-only, open events only', async () => {
  const now = Date.now();
  const hour = 3600 * 1000;
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    const event = (status, startOffsetH, endOffsetH) => ({
      title: 'Clean-up', description: 'x', status,
      startAt: Timestamp.fromMillis(now + startOffsetH * hour),
      endAt: endOffsetH === null ? null : Timestamp.fromMillis(now + endOffsetH * hour),
    });
    await setDoc(doc(db, 'events/e1'), event('published', 24, 28));
    await setDoc(doc(db, 'events/draft'), event('draft', 24, 28));
    await setDoc(doc(db, 'events/past'), event('published', -30, -26));
    // No end time: still open for 4 hours after the start.
    await setDoc(doc(db, 'events/running'), event('published', -2, null));
    await setDoc(doc(db, 'events/over'), event('published', -5, null));
  });
  const row = (uid, extra = {}) => ({
    uid, name: 'Alice', street: 'Mabini St', streetKey: 'mabini st',
    barangay: 'Bangcagan', joinedAt: serverTimestamp(), ...extra,
  });
  const path = 'events/e1/participants/alice';

  await assertSucceeds(setDoc(doc(as('alice'), path), row('alice')));
  // The first sign-up is final: street and join time cannot be rewritten.
  await assertFails(setDoc(doc(as('alice'), path), row('alice', {street: '5th Ave', streetKey: '5th ave'})));
  await assertFails(setDoc(doc(as('alice'), path), row('alice')));
  await assertFails(setDoc(doc(as('dan'), path), row('alice')));
  await assertFails(deleteDoc(doc(as('dan'), path)));
  await assertSucceeds(deleteDoc(doc(as('root'), path)));

  // Shape and size checks, on a fresh row each time.
  await assertFails(setDoc(doc(as('alice'), path), row('alice', {role: 'admin'})));
  await assertFails(setDoc(doc(as('alice'), path), row('alice', {joinedAt: Timestamp.fromMillis(1)})));
  await assertFails(setDoc(doc(as('alice'), path), row('alice', {name: 'x'.repeat(200)})));

  // Leaving then joining again starts a fresh row.
  await assertSucceeds(setDoc(doc(as('alice'), path), row('alice')));
  await assertSucceeds(deleteDoc(doc(as('alice'), path)));
  await assertSucceeds(setDoc(doc(as('alice'), path), row('alice')));

  // Only an open, published event takes sign-ups.
  await assertFails(setDoc(doc(as('alice'), 'events/draft/participants/alice'), row('alice')));
  await assertFails(setDoc(doc(as('alice'), 'events/past/participants/alice'), row('alice')));
  await assertFails(setDoc(doc(as('alice'), 'events/over/participants/alice'), row('alice')));
  await assertFails(setDoc(doc(as('alice'), 'events/missing/participants/alice'), row('alice')));
  await assertSucceeds(setDoc(doc(as('alice'), 'events/running/participants/alice'), row('alice')));
});

// An open event, plus the residents and a closed event the street tests use.
const seedEvents = async () => {
  const now = Date.now();
  const hour = 3600 * 1000;
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    const event = (startH, endH) => ({
      title: 'Clean-up', description: 'x', status: 'published',
      startAt: Timestamp.fromMillis(now + startH * hour),
      endAt: Timestamp.fromMillis(now + endH * hour),
    });
    await setDoc(doc(db, 'events/e1'), event(24, 28));
    await setDoc(doc(db, 'events/past'), event(-30, -26));
    await setDoc(doc(db, 'users/bob'), {name: 'Bob', role: 'user'});
  });
};

const signUpRow = (uid, key, extra = {}) => ({
  uid, name: uid, street: key, streetKey: key, barangay: 'B1',
  joinedAt: serverTimestamp(), ...extra,
});

test('sign-up rows are private: only the owner and staff can read them', async () => {
  await seedEvents();
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'events/e1/participants/alice'), {
      uid: 'alice', name: 'Alice', street: 'Mabini St', streetKey: 'mabini st',
      barangay: 'B1', joinedAt: Timestamp.now(),
    }));
  const row = 'events/e1/participants/alice';
  await assertSucceeds(getDoc(doc(as('alice'), row)));
  await assertSucceeds(getDoc(doc(as('root'), row)));
  await assertSucceeds(getDocs(collection(as('root'), 'events/e1/participants')));
  await assertFails(getDoc(doc(as('bob'), row)));
  await assertFails(getDoc(doc(as('dan'), row)));
  await assertFails(getDocs(collection(as('bob'), 'events/e1/participants')));
});

test('street counters follow the caller\'s own sign-up and nothing else', async () => {
  await seedEvents();
  const join = (db, uid, key, label, exists) => {
    const batch = writeBatch(db);
    batch.set(doc(db, `events/e1/participants/${uid}`), signUpRow(uid, key));
    const bucket = key === '' ? '_none' : key;
    const counter = doc(db, `events/e1/streets/${bucket}`);
    if (exists) batch.update(counter, {count: increment(1)});
    else batch.set(counter, {label, count: 1});
    return batch.commit();
  };
  const leave = (db, uid, key, last) => {
    const batch = writeBatch(db);
    batch.delete(doc(db, `events/e1/participants/${uid}`));
    const counter = doc(db, `events/e1/streets/${key === '' ? '_none' : key}`);
    if (last) batch.delete(counter);
    else batch.update(counter, {count: increment(-1)});
    return batch.commit();
  };

  // First resident on a street creates its counter with a count of 1.
  await assertSucceeds(join(as('alice'), 'alice', 'mabini st', 'Mabini St', false));
  // A counter cannot start higher, be created without a sign-up, or for someone else.
  await assertFails(setDoc(doc(as('bob'), 'events/e1/streets/rizal st'), {label: 'Rizal St', count: 1}));
  await assertFails(setDoc(doc(as('bob'), 'events/e1/streets/rizal st'), {label: 'Rizal St', count: 5}));

  // Everyone with a profile reads the counters, which hold no names or ids.
  await assertSucceeds(getDoc(doc(as('bob'), 'events/e1/streets/mabini st')));
  await assertSucceeds(getDocs(collection(as('bob'), 'events/e1/streets')));

  // A second resident adds exactly one place with their own row.
  await assertFails(updateDoc(doc(as('bob'), 'events/e1/streets/mabini st'), {count: increment(1)}));
  await assertSucceeds(join(as('bob'), 'bob', 'mabini st', 'Mabini St', true));
  // The counter cannot jump by two, nor use a different street than the row.
  await assertFails(updateDoc(doc(as('dan'), 'events/e1/streets/mabini st'), {count: increment(2)}));
  const dan = as('dan');
  const wrongBucket = writeBatch(dan);
  wrongBucket.set(doc(dan, 'events/e1/participants/dan'), signUpRow('dan', 'rizal st'));
  wrongBucket.update(doc(dan, 'events/e1/streets/mabini st'), {count: increment(1)});
  await assertFails(wrongBucket.commit());
  // The label is fixed once the street exists.
  await assertFails(updateDoc(doc(as('bob'), 'events/e1/streets/mabini st'), {label: 'Hacked'}));

  // Leaving takes exactly one place off, and only together with your own row.
  await assertFails(updateDoc(doc(as('bob'), 'events/e1/streets/mabini st'), {count: increment(-1)}));
  await assertSucceeds(leave(as('bob'), 'bob', 'mabini st', false));
  // The last person out removes the counter.
  await assertFails(deleteDoc(doc(as('dan'), 'events/e1/streets/mabini st')));
  await assertSucceeds(leave(as('alice'), 'alice', 'mabini st', true));

  // A resident with no street counts under '_none'.
  await assertSucceeds(join(as('bob'), 'bob', '', 'Street not set', false));
  // Closed events take no counter changes.
  const alice = as('alice');
  const closed = writeBatch(alice);
  closed.set(doc(alice, 'events/past/participants/alice'), signUpRow('alice', 'mabini st'));
  closed.set(doc(alice, 'events/past/streets/mabini st'), {label: 'Mabini St', count: 1});
  await assertFails(closed.commit());
  // Staff can repair a counter.
  await assertSucceeds(setDoc(doc(as('root'), 'events/e1/streets/mabini st'), {label: 'Mabini St', count: 7}));
});

test('nobody can publish a location for others to see', async () => {
  await assertFails(setDoc(doc(as('alice'), 'shared_locations/alice'), shared('user')));
  await assertFails(setDoc(doc(as('dan'), 'shared_locations/dan'), shared('driver')));
});

test('a driver position stays readable to every signed-in user through routes', async () => {
  const live = {status: 'inTransit', lat: 1, lng: 2, updatedAt: Timestamp.now()};
  await assertSucceeds(setDoc(doc(as('dan'), 'routes/dan'), live));
  await assertSucceeds(getDoc(doc(as('alice'), 'routes/dan')));
});

test('ending a run lets the driver clear the published position', async () => {
  const live = {status: 'inTransit', lat: 1, lng: 2, lastKnownLat: 1, lastKnownLng: 2, updatedAt: Timestamp.now()};
  await assertSucceeds(setDoc(doc(as('dan'), 'routes/dan'), live));
  const end = {status: 'completed', lat: null, lng: null, lastKnownLat: null, lastKnownLng: null, updatedAt: Timestamp.now()};
  await assertSucceeds(setDoc(doc(as('dan'), 'routes/dan'), end, {merge: true}));
  await assertFails(setDoc(doc(as('alice'), 'routes/dan'), end, {merge: true}));
});

test('signup cannot choose the admin role', async () => {
  await assertFails(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'admin', accountStatus: 'active'}));
  await assertSucceeds(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'user', accountStatus: 'pending'}));
});

test('signup is residents only, waits for the barangay and cannot self-verify', async () => {
  // Residents start pending; nobody signs themselves up active or as a driver.
  await assertFails(setDoc(doc(as('u0'), 'users/u0'), {name: 'U', role: 'user', accountStatus: 'active'}));
  await assertFails(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'active'}));
  await assertFails(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'pending'}));
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), {name: 'U', role: 'user', accountStatus: 'pending', points: 999}));
  await assertFails(setDoc(doc(as('u2'), 'users/u2'), {name: 'U', role: 'user', accountStatus: 'pending', photoUrl: 'x'.repeat(150000)}));
  // A new profile never claims a confirmed email.
  await assertFails(setDoc(doc(as('u3'), 'users/u3'), {name: 'U', role: 'user', accountStatus: 'pending', emailVerified: true}));
  const pending = {
    name: 'U', role: 'user', accountStatus: 'pending', registrationStatus: 'pending',
    verificationStatus: 'pending', emailVerified: false,
  };
  await assertSucceeds(setDoc(doc(as('u4', false), 'users/u4'), pending));
  await assertFails(updateDoc(doc(as('u4', false), 'users/u4'), {accountStatus: 'active'}));
});

test('a resident marks their email confirmed only once Firebase confirmed it', async () => {
  const pending = {
    name: 'U', role: 'user', accountStatus: 'pending', registrationStatus: 'pending',
    verificationStatus: 'pending', emailVerified: false,
  };
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'users/u5'), pending));
  // Link not clicked yet: the sign-in token says the email is unconfirmed.
  await assertFails(updateDoc(doc(as('u5', false), 'users/u5'), {emailVerified: true}));
  await assertSucceeds(updateDoc(doc(as('u5', true), 'users/u5'), {emailVerified: true}));
});

test('a pending resident with a confirmed email may tell the barangay, nothing more', async () => {
  const pending = {
    name: 'U', role: 'user', accountStatus: 'pending', registrationStatus: 'pending',
    verificationStatus: 'pending', emailVerified: true,
  };
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'users/u6'), pending));
  const notice = (overrides = {}) => ({
    userId: 'staff', title: 'New resident registration', body: 'U is waiting for ID review.',
    type: 'account', read: false, ...overrides,
  });
  await assertSucceeds(setDoc(doc(as('u6', true), 'notifications/n1'), notice()));
  await assertFails(setDoc(doc(as('u6', false), 'notifications/n2'), notice()));
  await assertFails(setDoc(doc(as('u6', true), 'notifications/n3'), notice({type: 'system'})));
  await assertFails(setDoc(doc(as('u6', true), 'notifications/n4'), notice({userId: 'alice'})));
  await assertFails(setDoc(doc(as('u6', true), 'notifications/n5'), notice({userId: 'cityHall'})));
});

test('users cannot approve themselves, edit points or set a huge photo', async () => {
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'users/pd'), {name: 'P', role: 'driver', accountStatus: 'pending'}));
  await assertFails(updateDoc(doc(as('pd'), 'users/pd'), {accountStatus: 'active'}));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {points: 100}));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {photoUrl: 'x'.repeat(150000)}));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), {photoUrl: 'data:image/jpeg;base64,AAAA'}));
  await assertSucceeds(updateDoc(doc(as('root'), 'users/pd'), {accountStatus: 'active'}));
});

test('a pending driver cannot publish a route or plan until approved', async () => {
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'users/pd'), {name: 'P', role: 'driver', accountStatus: 'pending'}));
  const live = {status: 'inTransit', lat: 1, lng: 2, updatedAt: Timestamp.now()};
  const plan = {driverId: 'pd', adHoc: true, status: 'scheduled'};
  await assertFails(setDoc(doc(as('pd'), 'routes/pd'), live));
  await assertFails(setDoc(doc(as('pd'), 'routePlans/p1'), plan));
  await env.withSecurityRulesDisabled((c) =>
    updateDoc(doc(c.firestore(), 'users/pd'), {accountStatus: 'active'}));
  await assertSucceeds(setDoc(doc(as('pd'), 'routes/pd'), live));
  await assertSucceeds(setDoc(doc(as('pd'), 'routePlans/p1'), plan));
});

test('only admins write the audit log, only as themselves, and entries are permanent', async () => {
  const entry = (actorUid) => ({action: 'approve', targetUid: 'dan', actorUid});
  await assertFails(setDoc(doc(as('alice'), 'admin_audit/a1'), entry('alice')));
  await assertFails(setDoc(doc(as('root'), 'admin_audit/a1'), entry('someone-else')));
  await assertSucceeds(setDoc(doc(as('root'), 'admin_audit/a1'), entry('root')));
  await assertFails(updateDoc(doc(as('root'), 'admin_audit/a1'), {action: 'x'}));
  await assertFails(deleteDoc(doc(as('root'), 'admin_audit/a1')));
  await assertFails(getDoc(doc(as('alice'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(as('root'), 'admin_audit/a1')));
});

test('users cannot change their own role but can edit other fields', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {role: 'admin'}));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), {name: 'Al'}));
});

test('users cannot read other profiles', async () => {
  await assertFails(getDoc(doc(as('dan'), 'users/alice')));
});

test('the calls the app makes every day are allowed', async () => {
  const alice = as('alice');
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
  await assertSucceeds(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
  await assertSucceeds(deleteDoc(doc(alice, 'shared_locations/alice')));
  await assertFails(deleteDoc(doc(as('alice'), 'shared_locations/dan')));
});

test('admins can run every step of delete user and change roles; others cannot', async () => {
  await assertFails(getDocs(collection(as('dan'), 'users')));
  await assertFails(deleteDoc(doc(as('dan'), 'users/alice/locations/l1')));
  await assertFails(setDoc(doc(as('dan'), 'removed_users/alice'), {removedAt: 1}));

  const root = as('root');
  await assertSucceeds(getDocs(collection(root, 'users')));
  await assertSucceeds(updateDoc(doc(root, 'users/alice'), {role: 'driver'}));
  // Staff can list location history only once the deletion tombstone exists.
  await assertFails(getDocs(collection(root, 'users/alice/locations')));
  await assertSucceeds(setDoc(doc(root, 'removed_users/alice'), {removedAt: 1}));
  await assertSucceeds(getDocs(collection(root, 'users/alice/locations')));
  await assertSucceeds(deleteDoc(doc(root, 'users/alice/locations/l1')));
  await assertSucceeds(deleteDoc(doc(root, 'shared_locations/alice')));
  await assertSucceeds(deleteDoc(doc(root, 'users/alice')));
});

test('admins cannot delete their own profile', async () => {
  await assertFails(deleteDoc(doc(as('root'), 'users/root')));
});

test('a deleted user is locked out even though their login still works', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'removed_users/alice'), {removedAt: 1});
    await deleteDoc(doc(db, 'users/alice'));
  });
  const alice = as('alice');
  await assertFails(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
  await assertFails(setDoc(doc(alice, 'users/alice'), {name: 'Alice', role: 'user'}));
});

const note = (userId) => ({
  userId,
  title: 'Hi',
  body: 'Hello',
  read: false,
});

test('residents notify only themselves or staff; admins and drivers notify anyone', async () => {
  await assertSucceeds(setDoc(doc(as('alice'), 'notifications/n1'), note('alice')));
  await assertSucceeds(setDoc(doc(as('alice'), 'notifications/n2'), note('staff')));
  await assertFails(setDoc(doc(as('alice'), 'notifications/n3'), note('dan')));
  await assertSucceeds(setDoc(doc(as('dan'), 'notifications/n4'), {...note('alice'), type: 'route'}));
  await assertSucceeds(setDoc(doc(as('dan'), 'notifications/n6'), {...note('alice'), type: 'request'}));
  await assertFails(setDoc(doc(as('dan'), 'notifications/n7'), {...note('alice'), type: 'system'}));
  await assertFails(setDoc(doc(as('dan'), 'notifications/n8'), note('alice')));
  await assertSucceeds(setDoc(doc(as('root'), 'notifications/n5'), {...note('alice'), type: 'system'}));
});

const seedPost = () =>
  env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'communityPosts/p1'), {
      authorId: 'dan',
      body: 'Collection moved',
      likedBy: ['dan'],
      comments: [{id: 'c1', authorId: 'dan', authorName: 'Dan', body: 'ok'}],
    }));

test('members can like and unlike as themselves, but not for someone else', async () => {
  await seedPost();
  const post = doc(as('alice'), 'communityPosts/p1');
  await assertSucceeds(updateDoc(post, {likedBy: arrayUnion('alice')}));
  await assertSucceeds(updateDoc(post, {likedBy: arrayRemove('alice')}));
  await assertFails(updateDoc(post, {likedBy: arrayUnion('eve')}));
  await assertFails(updateDoc(post, {likedBy: arrayRemove('dan')}));
  await assertFails(updateDoc(post, {likedBy: []}));
});

test('members can append their own comment but not edit, remove or forge one', async () => {
  await seedPost();
  const post = doc(as('alice'), 'communityPosts/p1');
  const mine = {id: 'c2', authorId: 'alice', authorName: 'Alice', body: 'thanks'};
  await assertSucceeds(updateDoc(post, {comments: arrayUnion(mine)}));
  await assertFails(updateDoc(post, {comments: arrayUnion({...mine, id: 'c3', authorId: 'dan'})}));
  await assertFails(updateDoc(post, {comments: arrayUnion({...mine, id: 'c4', junk: 'x'.repeat(500)})}));
  await assertFails(updateDoc(post, {comments: []}));
  await assertFails(updateDoc(post, {
    comments: [{id: 'c1', authorId: 'dan', authorName: 'Dan', body: 'edited'}, mine],
  }));
});

test('a comment must carry the name on the sign-in token when it has one', async () => {
  await seedPost();
  const named = env.authenticatedContext('alice', {email_verified: true, name: 'Alice'}).firestore();
  const comment = (id, authorName) => ({id, authorId: 'alice', authorName, body: 'hi'});
  await assertSucceeds(updateDoc(doc(named, 'communityPosts/p1'), {comments: arrayUnion(comment('c5', 'Alice'))}));
  await assertFails(updateDoc(doc(named, 'communityPosts/p1'), {comments: arrayUnion(comment('c6', 'Barangay Captain'))}));
  // A fresh token has no name yet, so the app's own name is accepted.
  await assertSucceeds(updateDoc(doc(as('alice'), 'communityPosts/p1'), {comments: arrayUnion(comment('c7', 'Alice'))}));
});

test('admins can strip a deleted user from other posts', async () => {
  await seedPost();
  await assertSucceeds(updateDoc(doc(as('root'), 'communityPosts/p1'), {
    likedBy: arrayRemove('dan'),
    comments: arrayRemove({id: 'c1', authorId: 'dan', authorName: 'Dan', body: 'ok'}),
  }));
  let stored;
  await env.withSecurityRulesDisabled(async (c) => {
    stored = (await getDoc(doc(c.firestore(), 'communityPosts/p1'))).data();
  });
  assert.deepEqual(stored.likedBy, []);
  assert.deepEqual(stored.comments, []);
});

test('only the author or an admin can delete a post, and admins can moderate it', async () => {
  await seedPost();
  await assertFails(deleteDoc(doc(as('alice'), 'communityPosts/p1')));
  await assertSucceeds(updateDoc(doc(as('root'), 'communityPosts/p1'), {comments: []}));
  await assertSucceeds(deleteDoc(doc(as('dan'), 'communityPosts/p1')));
});

test('a user being deleted cannot write while the delete is still running', async () => {
  // Admin delete has written the tombstone but not yet removed the profile.
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'removed_users/alice'), {removedAt: 1});
  });
  const alice = as('alice');
  await assertFails(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
});

// --- Manuals: Iswim -> City Hall only ---------------------------------------

const manual = (overrides = {}) => ({
  title: 'Collection SOP',
  category: 'collection',
  summary: 'How a route is run',
  version: 1,
  status: 'submitted',
  createdBy: 'ivy',
  createdByName: 'Ivy',
  currentNotes: 'First issue',
  file: {
    dataUrl: 'data:image/png;base64,AA==',
    fileName: 'sop.png',
    mimeType: 'image/png',
    bytes: 2,
  },
  ...overrides,
});

test('manuals are written by Iswim and read only by Iswim and City Hall', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'manuals/m1'), manual()));
  await assertFails(setDoc(doc(as('carl'), 'manuals/m2'), manual()));
  await assertFails(setDoc(doc(as('root'), 'manuals/m3'), manual()));

  await assertSucceeds(getDoc(doc(as('ivy'), 'manuals/m1')));
  await assertSucceeds(getDoc(doc(as('carl'), 'manuals/m1')));
  await assertFails(getDoc(doc(as('root'), 'manuals/m1')));
  await assertFails(getDoc(doc(as('alice'), 'manuals/m1')));
});

test('City Hall can acknowledge a manual but cannot rewrite it', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'manuals/m1'), manual()));
  await assertSucceeds(updateDoc(doc(as('carl'), 'manuals/m1'), {
    status: 'acknowledged',
    acknowledgedAt: Timestamp.now(),
    acknowledgedByName: 'Carl',
  }));
  await assertFails(updateDoc(doc(as('carl'), 'manuals/m1'), {title: 'Hijacked'}));
});

test('manual version history is append-only and Iswim-only', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'manuals/m1'), manual()));
  await assertSucceeds(setDoc(doc(as('ivy'), 'manuals/m1/versions/v1'), {
    version: 1,
    notes: 'First',
    file: manual().file,
    submittedBy: 'ivy',
    submittedByName: 'Ivy',
    submittedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(doc(as('carl'), 'manuals/m1/versions/v1')));
  await assertFails(setDoc(doc(as('carl'), 'manuals/m1/versions/v2'), {
    version: 2,
    notes: 'Fake',
    file: manual().file,
  }));
  await assertFails(updateDoc(doc(as('ivy'), 'manuals/m1/versions/v1'), {notes: 'Edited'}));
});

test('City Hall requests a manual and Iswim fulfils it', async () => {
  const request = {
    code: 'MR-2026-0001',
    title: 'Flood response manual',
    details: 'Needed for the rainy season',
    requestedByName: 'Carl',
    status: 'pending',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(as('carl'), 'manual_requests/r1'), request));
  await assertFails(setDoc(doc(as('ivy'), 'manual_requests/r2'), request));
  await assertSucceeds(updateDoc(doc(as('ivy'), 'manual_requests/r1'), {
    status: 'fulfilled',
    fulfilledAt: serverTimestamp(),
    fulfilledByName: 'Ivy',
  }));
  await assertSucceeds(getDoc(doc(as('carl'), 'manual_requests/r1')));
  await assertFails(getDoc(doc(as('alice'), 'manual_requests/r1')));
});

// --- Complaints: resident -> DSQC / City Hall only -------------------------

const complaint = (overrides = {}) => ({
  referenceNo: 'CMP-2026-000001',
  residentId: 'alice',
  residentName: 'Alice',
  title: 'Missed pickup',
  description: 'The truck skipped our street for two weeks.',
  category: 'missedCollection',
  status: 'pending',
  images: [],
  createdAt: serverTimestamp(),
  ...overrides,
});

test('a resident files a complaint and reads only their own thread', async () => {
  await assertSucceeds(setDoc(doc(as('alice'), 'complaints/c1'), complaint()));
  await assertFails(setDoc(doc(as('dan'), 'complaints/c2'), complaint({residentId: 'dan'})));
  await assertSucceeds(getDoc(doc(as('alice'), 'complaints/c1')));
  await assertFails(getDoc(doc(as('bob'), 'complaints/c1')));
});

test('City Hall works complaints; the barangay and admin do not', async () => {
  await assertSucceeds(setDoc(doc(as('alice'), 'complaints/c1'), complaint()));
  await assertSucceeds(getDoc(doc(as('carl'), 'complaints/c1')));
  await assertFails(getDoc(doc(as('root'), 'complaints/c1')));
  await assertSucceeds(updateDoc(doc(as('carl'), 'complaints/c1'), {
    status: 'underReview',
    responses: arrayUnion({message: 'Checking with the crew', byName: 'Carl', byRole: 'cityHall', at: Timestamp.now()}),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {status: 'resolved'}));
});

test('a resident replies in their own open complaint thread, and nothing more', async () => {
  const reply = (overrides = {}) => ({
    message: 'It happened again today.',
    byName: 'Alice',
    byRole: 'resident',
    at: Timestamp.now(),
    ...overrides,
  });
  await assertSucceeds(setDoc(doc(as('alice'), 'complaints/c1'), complaint()));

  // Their own reply, appended while the complaint is open.
  await assertSucceeds(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply()),
    updatedAt: serverTimestamp(),
  }));
  // Never posing as City Hall, never with extra fields or an empty message.
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply({byRole: 'cityHall', message: 'Resolved'})),
  }));
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply({message: '', at: Timestamp.now()})),
  }));
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply({message: 'x', status: 'resolved'})),
  }));
  // A reply cannot carry a status change, and nobody else can reply.
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply({message: 'And close it'})),
    status: 'resolved',
  }));
  await assertFails(updateDoc(doc(as('dan'), 'complaints/c1'), {
    responses: arrayUnion(reply({byName: 'Dan', message: 'Me too'})),
  }));
  // Earlier messages cannot be rewritten.
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: [reply({message: 'Edited history'})],
  }));

  // Once City Hall closes it, the thread is read-only for the resident.
  await assertSucceeds(updateDoc(doc(as('carl'), 'complaints/c1'), {status: 'resolved'}));
  await assertFails(updateDoc(doc(as('alice'), 'complaints/c1'), {
    responses: arrayUnion(reply({message: 'Not fixed'})),
  }));
});

// --- Points ledger ----------------------------------------------------------

test('points ledger rows are written by staff and read by their owner', async () => {
  const row = {
    residentId: 'alice',
    residentName: 'Alice',
    points: 10,
    reason: 'Waste validation · Recyclable',
    sourceType: 'wasteSubmission',
    sourceId: 'w1',
    byUid: 'root',
    byName: 'Root',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(as('root'), 'points_transactions/p1'), row));
  await assertSucceeds(getDoc(doc(as('alice'), 'points_transactions/p1')));
  await assertFails(getDoc(doc(as('bob'), 'points_transactions/p1')));
  await assertFails(setDoc(doc(as('alice'), 'points_transactions/p2'), {...row, byUid: 'alice'}));
  await assertFails(updateDoc(doc(as('root'), 'points_transactions/p1'), {points: 999}));
});

// --- Desk notification channels -------------------------------------------

test('City Hall and Iswim read their own desk channel', async () => {
  await assertSucceeds(setDoc(doc(as('alice'), 'notifications/n20'), note('cityHall')));
  await assertSucceeds(getDoc(doc(as('carl'), 'notifications/n20')));
  await assertFails(getDoc(doc(as('ivy'), 'notifications/n20')));
  await assertSucceeds(updateDoc(doc(as('carl'), 'notifications/n20'), {read: true}));

  await assertSucceeds(setDoc(doc(as('carl'), 'notifications/n21'), note('iswim')));
  await assertSucceeds(getDoc(doc(as('ivy'), 'notifications/n21')));
  await assertFails(getDoc(doc(as('carl'), 'notifications/n21')));
});

// --- Trip ticket audit trail ----------------------------------------------

test('a driver may append an audit entry when accepting a ticket', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'trip_tickets/t1'), {
    code: 'TT-2026-0001',
    plateNumber: 'ABC 123',
    driverId: 'dan',
    driverName: 'Dan',
    status: 'issued',
    createdBy: 'ivy',
    createdAt: serverTimestamp(),
    signatures: {},
    history: [],
  }));
  await assertSucceeds(updateDoc(doc(as('dan'), 'trip_tickets/t1'), {
    status: 'accepted',
    acceptedAt: Timestamp.now(),
    history: arrayUnion({
      status: 'accepted',
      previousStatus: 'issued',
      byUid: 'dan',
      byName: 'Dan',
      note: 'Ticket received',
      at: Timestamp.now(),
    }),
  }));
  await assertFails(updateDoc(doc(as('dan'), 'trip_tickets/t1'), {
    plateNumber: 'FORGED',
  }));
});

// --- Resident registration decision ---------------------------------------

test('a resident answers only an approval the barangay already gave', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), {
      name: 'Alice', role: 'user', registrationStatus: 'approved',
    });
    await setDoc(doc(db, 'users/bob'), {
      name: 'Bob', role: 'user', registrationStatus: 'pending',
    });
  });

  // A pending registration has no approval to answer.
  await assertFails(updateDoc(doc(as('bob'), 'users/bob'), {
    registrationStatus: 'accepted',
    registrationDecidedAt: serverTimestamp(),
  }));
  // The resident cannot approve themselves.
  await assertFails(updateDoc(doc(as('bob'), 'users/bob'), {
    registrationStatus: 'approved',
  }));
  // The barangay's approval timestamp is not the resident's to write.
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {
    registrationApprovedAt: serverTimestamp(),
  }));

  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), {
    registrationStatus: 'accepted',
    registrationDecidedAt: serverTimestamp(),
  }));
  // The decision is final from the resident side.
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {
    registrationStatus: 'declined',
    registrationDecidedAt: serverTimestamp(),
  }));
});

test('barangay staff approve a registration without touching the resident answer', async () => {
  await assertSucceeds(updateDoc(doc(as('root'), 'users/alice'), {
    verificationStatus: 'verified',
    registrationStatus: 'approved',
    registrationApprovedAt: serverTimestamp(),
  }));
});

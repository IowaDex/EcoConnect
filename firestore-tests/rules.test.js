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
  limit,
  orderBy,
  query,
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
    await setDoc(doc(db, 'users/auditor'), {
      name: 'Auditor',
      role: 'auditor',
      accountStatus: 'active',
    });
    await setDoc(doc(db, 'users/alice/locations/l1'), {latitude: 1});
    await setDoc(doc(db, 'shared_locations/dan'), shared('driver'));
    await setDoc(doc(db, 'shared_locations/alice'), shared('user'));
    await setDoc(doc(db, 'admin_audit/a1'), {
      action: 'update',
      actorUid: 'root',
      at: Timestamp.now(),
    });
    await setDoc(doc(db, 'routes/dan'), {status: 'inTransit'});
    await setDoc(doc(db, 'trucks/t1'), {plateNumber: 'ABC-123'});
    await setDoc(doc(db, 'announcements/a1'), {status: 'published'});
    await setDoc(doc(db, 'incidents/old-report'), {
      residentId: 'alice',
      status: 'pending',
    });
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
  await assertSucceeds(setDoc(doc(asSignedInAt('auditor', 1000), 'sessions/auditor'), session(id)));
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

test('residents cannot create or read incident reports; staff retain access', async () => {
  await assertFails(getDoc(doc(as('alice'), 'incidents/old-report')));
  await assertFails(getDocs(collection(as('alice'), 'incidents')));
  await assertFails(setDoc(doc(as('alice'), 'incidents/new-report'), {
    residentId: 'alice',
    status: 'pending',
  }));
  await assertSucceeds(getDoc(doc(as('carl'), 'incidents/old-report')));
  await assertSucceeds(getDocs(collection(as('carl'), 'incidents')));
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
  await assertSucceeds(setDoc(doc(as('eve'), 'users/eve'), {
    name: 'Eve', role: 'user', accountStatus: 'pending', barangay: 'Batasan Hills',
  }));
});

test('signup is residents only, waits for the barangay and cannot self-verify', async () => {
  const home = {barangay: 'Batasan Hills'};
  // Residents start pending; nobody signs themselves up active or as a driver.
  await assertFails(setDoc(doc(as('u0'), 'users/u0'), {name: 'U', role: 'user', accountStatus: 'active', ...home}));
  await assertFails(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'active', ...home}));
  await assertFails(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'pending', ...home}));
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), {name: 'U', role: 'user', accountStatus: 'pending', points: 999, ...home}));
  await assertFails(setDoc(doc(as('u2'), 'users/u2'), {name: 'U', role: 'user', accountStatus: 'pending', photoUrl: 'x'.repeat(150000), ...home}));
  // A new profile never claims a confirmed email.
  await assertFails(setDoc(doc(as('u3'), 'users/u3'), {name: 'U', role: 'user', accountStatus: 'pending', emailVerified: true, ...home}));
  // The address is fixed: sign-up cannot pick a barangay outside the service area.
  await assertFails(setDoc(doc(as('u9'), 'users/u9'), {
    name: 'U', role: 'user', accountStatus: 'pending', barangay: 'Payatas',
  }));
  await assertFails(setDoc(doc(as('u8'), 'users/u8'), {name: 'U', role: 'user', accountStatus: 'pending'}));
  const pending = {
    name: 'U', role: 'user', accountStatus: 'pending', registrationStatus: 'pending',
    verificationStatus: 'pending', emailVerified: false, ...home,
  };
  await assertSucceeds(setDoc(doc(as('u4', false), 'users/u4'), pending));
  await assertFails(updateDoc(doc(as('u4', false), 'users/u4'), {accountStatus: 'active'}));
});

test('each desk provisions only its own crew, never another desk', async () => {
  const crew = (role, extra = {}) => ({name: 'Crew', role, accountStatus: 'active', ...extra});
  const driver = crew('driver', {crewRole: 'driver'});
  const guide = crew('driver', {crewRole: 'guide'});

  // City Hall is the only desk that makes every role.
  await assertSucceeds(setDoc(doc(as('carl'), 'users/c-driver'), driver));
  await assertSucceeds(setDoc(doc(as('carl'), 'users/c-admin'), crew('admin')));
  await assertSucceeds(setDoc(doc(as('carl'), 'users/c-iswim'), crew('iswim')));

  // Iswim makes the drivers — the people who hold a plate.
  await assertSucceeds(setDoc(doc(as('ivy'), 'users/i-driver'), driver));
  // A guide rides with someone else's plate: the barangay makes that login.
  await assertFails(setDoc(doc(as('ivy'), 'users/i-guide'), guide));
  // Its own colleagues and the other desks are City Hall's to create.
  await assertFails(setDoc(doc(as('ivy'), 'users/i-iswim'), crew('iswim')));
  await assertFails(setDoc(doc(as('ivy'), 'users/i-admin'), crew('admin')));
  await assertFails(setDoc(doc(as('ivy'), 'users/i-carl'), crew('cityHall')));
  await assertFails(setDoc(doc(as('ivy'), 'users/i-auditor'), crew('auditor')));
  // A driver with no crewRole would be a crew member nobody labelled.
  await assertFails(setDoc(doc(as('ivy'), 'users/i-bare'), crew('driver')));

  // The barangay makes its truck guides, and only guides.
  await assertSucceeds(setDoc(doc(as('root'), 'users/b-guide'), guide));
  await assertFails(setDoc(doc(as('root'), 'users/b-driver'), driver));
  await assertFails(setDoc(doc(as('root'), 'users/b-admin'), crew('admin')));
  await assertFails(setDoc(doc(as('root'), 'users/b-iswim'), crew('iswim')));
  await assertFails(setDoc(doc(as('root'), 'users/b-carl'), crew('cityHall')));
  await assertFails(setDoc(doc(as('root'), 'users/b-auditor'), crew('auditor')));

  // A provisioned login is active on arrival, never pending.
  await assertFails(setDoc(doc(as('ivy'), 'users/pending'), {
    name: 'P', role: 'driver', crewRole: 'driver', accountStatus: 'pending',
  }));
});

test('a desk suspends and deletes only its own people', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'users/g1'), {name: 'G', role: 'driver', crewRole: 'guide'});
    await setDoc(doc(db, 'users/d1'), {name: 'D', role: 'driver', crewRole: 'driver'});
    await setDoc(doc(db, 'users/i2'), {name: 'I', role: 'iswim'});
    await setDoc(doc(db, 'users/a2'), {name: 'A', role: 'admin'});
    await setDoc(doc(db, 'users/c2'), {name: 'C', role: 'cityHall'});
  });

  // The barangay suspends its guides, and only them.
  await assertSucceeds(updateDoc(doc(as('root'), 'users/g1'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('root'), 'users/d1'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('root'), 'users/i2'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('root'), 'users/a2'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('root'), 'users/c2'), {accountStatus: 'suspended'}));

  // Iswim suspends the drivers, and nothing else — not a guide, not another
  // desk. A profile from before crewRole existed still counts as a driver.
  await assertSucceeds(updateDoc(doc(as('ivy'), 'users/d1'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('ivy'), 'users/g1'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('ivy'), 'users/i2'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('ivy'), 'users/a2'), {accountStatus: 'suspended'}));
  await assertFails(updateDoc(doc(as('ivy'), 'users/c2'), {accountStatus: 'suspended'}));
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'users/legacy'), {name: 'L', role: 'driver'}));
  await assertSucceeds(updateDoc(doc(as('ivy'), 'users/legacy'), {accountStatus: 'suspended'}));

  // Nobody hands out a role through the desk.
  await assertFails(updateDoc(doc(as('ivy'), 'users/d1'), {role: 'admin'}));
  await assertFails(updateDoc(doc(as('root'), 'users/g1'), {role: 'admin'}));

  // Deleting: residents and its own guides. Never another desk's login.
  await assertSucceeds(deleteDoc(doc(as('root'), 'users/g1')));
  await assertSucceeds(deleteDoc(doc(as('root'), 'users/alice')));
  await assertFails(deleteDoc(doc(as('root'), 'users/d1')));
  await assertFails(deleteDoc(doc(as('root'), 'users/i2')));
  await assertFails(deleteDoc(doc(as('root'), 'users/c2')));
});

test('Iswim removes a departed driver, and only a driver', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/d1'), {
      name: 'D', role: 'driver', crewRole: 'driver', accountStatus: 'active',
    });
    await setDoc(doc(db, 'users/g1'), {
      name: 'G', role: 'driver', crewRole: 'guide', accountStatus: 'active',
    });
    await setDoc(doc(db, 'routes/d1'), {status: 'inTransit'});
    await setDoc(doc(db, 'routes/g1'), {status: 'inTransit'});
    await setDoc(doc(db, 'sessions/d1'), {sessionId: 'a'.repeat(20), authTime: 1});
  });

  // The tombstone is what stops the profile coming back, so Iswim may lay it
  // only over a driver: never a guide, a resident, a colleague or another desk.
  await assertFails(setDoc(doc(as('ivy'), 'removed_users/g1'), {removedAt: 1}));
  await assertFails(setDoc(doc(as('ivy'), 'removed_users/alice'), {removedAt: 1}));
  await assertFails(setDoc(doc(as('ivy'), 'removed_users/ivy'), {removedAt: 1}));
  await assertFails(setDoc(doc(as('ivy'), 'removed_users/carl'), {removedAt: 1}));
  await assertSucceeds(setDoc(doc(as('ivy'), 'removed_users/d1'), {removedAt: 1}));
  // A removal that failed after the tombstone is retried, and the second
  // write arrives as an update rather than a create.
  await assertSucceeds(setDoc(doc(as('ivy'), 'removed_users/d1'), {removedAt: 2}));

  // The live route and the device marker go with the account.
  await assertFails(deleteDoc(doc(as('ivy'), 'routes/g1')));
  await assertSucceeds(deleteDoc(doc(as('ivy'), 'routes/d1')));
  await assertSucceeds(deleteDoc(doc(as('ivy'), 'sessions/d1')));

  // The profile goes last, so a failure halfway leaves it listed to retry.
  await assertFails(deleteDoc(doc(as('ivy'), 'users/g1')));
  await assertFails(deleteDoc(doc(as('ivy'), 'users/alice')));
  await assertSucceeds(deleteDoc(doc(as('ivy'), 'users/d1')));

  // Nobody removes their own login through the desk.
  await assertFails(deleteDoc(doc(as('ivy'), 'users/ivy')));
});

test('City Hall alone keeps the District Officer email address', async () => {
  const ref = (uid) => doc(as(uid), 'settings/districtOfficer');
  await assertSucceeds(setDoc(ref('carl'), {email: 'officer@qc.gov.ph'}));
  await assertSucceeds(getDoc(ref('carl')));
  await assertFails(setDoc(ref('carl'), {email: 'x'.repeat(201)}));
  await assertFails(setDoc(ref('carl'), {email: 'officer@qc.gov.ph', extra: true}));
  await assertFails(setDoc(ref('root'), {email: 'officer@qc.gov.ph'}));
  await assertFails(getDoc(ref('alice')));
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
  // A guide, because a pending crew account is the barangay's to approve and
  // guides are the crew it owns.
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'users/pd'), {
      name: 'P', role: 'driver', crewRole: 'guide', accountStatus: 'pending',
    }));
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

test('a resident uploads an ID and may replace it while pending or after a rejection', async () => {
  const id = (overrides = {}) => ({
    userId: 'alice',
    status: 'pending',
    accountType: 'resident',
    document: {dataUrl: 'data:image/jpeg;base64,AAAA'},
    ...overrides,
  });
  await assertSucceeds(setDoc(doc(as('alice'), 'verificationRequests/alice'), id()));
  await assertSucceeds(getDoc(doc(as('alice'), 'verificationRequests/alice')));
  // The ID is private to its owner and the barangay desk.
  await assertFails(getDoc(doc(as('bob'), 'verificationRequests/alice')));
  await assertFails(getDoc(doc(as('dan'), 'verificationRequests/alice')));
  await assertSucceeds(getDoc(doc(as('root'), 'verificationRequests/alice')));
  // Nobody files an ID in another resident's name, nor approves themselves.
  await assertFails(setDoc(doc(as('bob'), 'verificationRequests/bob'), id()));
  await assertFails(setDoc(doc(as('bob'), 'verificationRequests/bob2'), id({userId: 'bob', status: 'verified'})));
  // A resident swaps in a clearer photo while the desk is still looking.
  await assertSucceeds(setDoc(
      doc(as('alice'), 'verificationRequests/alice'),
      id({document: {dataUrl: 'data:image/png;base64,BBBB'}}),
  ));
  // The desk rejects it; the resident may try again.
  await assertSucceeds(updateDoc(doc(as('root'), 'verificationRequests/alice'), {
    status: 'rejected', rejectionReason: 'The photo is blurry.',
  }));
  await assertSucceeds(updateDoc(doc(as('alice'), 'verificationRequests/alice'), id()));
  // Once approved, the resident cannot keep rewriting it. Approving sets the
  // account to verified (setUserVerification writes both records).
  await assertSucceeds(updateDoc(doc(as('root'), 'verificationRequests/alice'), {status: 'verified'}));
  await env.withSecurityRulesDisabled((context) =>
    updateDoc(doc(context.firestore(), 'users/alice'), {verificationStatus: 'verified'}));
  await assertFails(updateDoc(doc(as('alice'), 'verificationRequests/alice'), id()));
  // A scan past the size cap is refused.
  await assertFails(setDoc(
      doc(as('alice'), 'verificationRequests/big'),
      id({document: {dataUrl: 'x'.repeat(900000)}}),
  ));
});

test('a resident resubmits an ID saved by an older version of the app', async () => {
  const id = {
    userId: 'alice',
    status: 'pending',
    accountType: 'resident',
    document: {dataUrl: 'data:image/jpeg;base64,CCCC'},
  };
  // The desk rejected the last photo, but the record it left behind names no
  // owner and carries a status this build never sends. The resident still owns
  // the record named after their uid and must be able to send another one
  // without the barangay acting first.
  await env.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), 'verificationRequests/alice'), {
      status: 'unverified',
      document: {dataUrl: 'data:image/jpeg;base64,AAAA'},
    }));
  await assertSucceeds(setDoc(doc(as('alice'), 'verificationRequests/alice'), id));
  // Nobody else may write the resident's record, and it can never be approved
  // by its owner: the resubmission is always pending.
  await assertFails(setDoc(doc(as('bob'), 'verificationRequests/alice'), id));
  await assertFails(setDoc(
      doc(as('alice'), 'verificationRequests/alice'),
      {...id, status: 'verified'},
  ));

  // The resubmission also puts the profile back to 'pending' and clears the
  // old reason, so the dashboard stops showing the rejection.
  await env.withSecurityRulesDisabled((context) =>
    updateDoc(doc(context.firestore(), 'users/alice'), {
      verificationStatus: 'rejected', rejectionReason: 'The photo is blurry.',
    }));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), {
    verificationStatus: 'pending', rejectionReason: null,
  }));
  // A resident can never mark themselves verified, nor reopen any other way.
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {
    verificationStatus: 'verified',
  }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {
    verificationStatus: 'rejected', rejectionReason: null,
  }));
});

test('a device token belongs to its owner and must be a real token', async () => {
  const row = (overrides = {}) => ({
    token: 'f'.repeat(140), platform: 'android', updatedAt: Timestamp.now(), ...overrides,
  });
  await assertSucceeds(setDoc(doc(as('alice'), 'users/alice/devices/d1'), row()));
  await assertSucceeds(getDoc(doc(as('alice'), 'users/alice/devices/d1')));
  await assertFails(getDoc(doc(as('dan'), 'users/alice/devices/d1')));
  await assertSucceeds(getDoc(doc(as('root'), 'users/alice/devices/d1')));
  // A token cannot be planted in someone else's profile.
  await assertFails(setDoc(doc(as('dan'), 'users/alice/devices/d2'), row()));
  await assertFails(setDoc(doc(as('alice'), 'users/alice/devices/d3'), row({token: 'short'})));
  await assertFails(setDoc(doc(as('alice'), 'users/alice/devices/d4'), row({token: 'x'.repeat(5000)})));
  await assertFails(setDoc(doc(as('alice'), 'users/alice/devices/d5'), row({platform: 3})));
  // A reinstall refreshes the same row, and signing out drops it.
  await assertSucceeds(setDoc(doc(as('alice'), 'users/alice/devices/d1'), row({token: 'g'.repeat(140)})));
  await assertSucceeds(deleteDoc(doc(as('alice'), 'users/alice/devices/d1')));
});

test('only admins, City Hall, and auditors read immutable server audit entries', async () => {
  const entry = {action: 'approve', targetUid: 'dan', actorUid: 'root'};
  await assertFails(setDoc(doc(as('alice'), 'admin_audit/a2'), entry));
  await assertFails(setDoc(doc(as('root'), 'admin_audit/a2'), entry));
  await assertFails(setDoc(doc(as('auditor'), 'admin_audit/a2'), entry));
  await assertFails(updateDoc(doc(as('root'), 'admin_audit/a1'), {action: 'x'}));
  await assertFails(deleteDoc(doc(as('root'), 'admin_audit/a1')));
  await assertFails(getDoc(doc(as('alice'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(as('root'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(as('carl'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(as('auditor'), 'admin_audit/a1')));
  await assertSucceeds(getDocs(query(
      collection(as('auditor'), 'admin_audit'),
      orderBy('at', 'desc'),
      limit(50),
  )));
});

test('auditors cannot read operational collections or provision themselves', async () => {
  await assertFails(getDoc(doc(as('auditor'), 'routes/dan')));
  await assertFails(getDoc(doc(as('auditor'), 'trucks/t1')));
  await assertFails(getDoc(doc(as('auditor'), 'announcements/a1')));
  await assertFails(getDoc(doc(as('auditor'), 'users/alice')));
  await assertFails(setDoc(doc(as('auditor'), 'users/self-made'), {
    name: 'Not an auditor',
    role: 'auditor',
    accountStatus: 'active',
  }));
  await assertSucceeds(setDoc(doc(as('carl'), 'users/new-auditor'), {
    name: 'New auditor',
    role: 'auditor',
    accountStatus: 'active',
  }));
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

test('admins can delete a user but cannot hand out roles; City Hall can', async () => {
  await assertFails(getDocs(collection(as('dan'), 'users')));
  await assertFails(deleteDoc(doc(as('dan'), 'users/alice/locations/l1')));
  await assertFails(setDoc(doc(as('dan'), 'removed_users/alice'), {removedAt: 1}));

  const root = as('root');
  await assertSucceeds(getDocs(collection(root, 'users')));
  // Provisioning moved to City Hall, so the barangay desk edits a profile but
  // never its role. Re-roled on Bob, so Alice stays the resident this test
  // then deletes — the barangay may only delete residents and its guides.
  await assertFails(updateDoc(doc(root, 'users/alice'), {role: 'driver'}));
  await assertSucceeds(updateDoc(doc(as('carl'), 'users/bob'), {role: 'driver'}));
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
  const mine = {
    id: 'c2',
    authorId: 'alice',
    authorName: 'Alice',
    body: 'thanks',
    createdAt: Timestamp.now(),
  };
  await assertSucceeds(updateDoc(post, {
    comments: arrayUnion(mine),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(post, {comments: arrayUnion({...mine, id: 'c3', authorId: 'dan'})}));
  await assertFails(updateDoc(post, {comments: arrayUnion({...mine, id: 'c4', junk: 'x'.repeat(500)})}));
  await assertFails(updateDoc(post, {comments: []}));
  await assertFails(updateDoc(post, {
    comments: [{id: 'c1', authorId: 'dan', authorName: 'Dan', body: 'edited'}, mine],
  }));
});

test('the first reply on a post with no replies yet goes through', async () => {
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'communityPosts/p2'), {
      authorId: 'dan', body: 'Fresh post', likedBy: [], comments: [],
    }));
  await assertSucceeds(updateDoc(doc(as('alice'), 'communityPosts/p2'), {
    comments: arrayUnion({id: 'c1', authorId: 'alice', authorName: 'Alice', body: 'First!'}),
  }));
});

test('a comment uses the account profile name rather than a stale token name', async () => {
  await seedPost();
  const named = env.authenticatedContext('alice', {email_verified: true, name: 'Old Alice'}).firestore();
  const comment = (id, authorName) => ({id, authorId: 'alice', authorName, body: 'hi'});
  await assertSucceeds(updateDoc(doc(named, 'communityPosts/p1'), {comments: arrayUnion(comment('c5', 'Alice'))}));
  await assertFails(updateDoc(doc(named, 'communityPosts/p1'), {comments: arrayUnion(comment('c6', 'Barangay Captain'))}));
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

const assignmentManual = (overrides = {}) => ({
  title: 'Manual for MR-2026-0001',
  driverId: 'dan',
  driverName: 'Dan',
  truckId: 't1',
  plateNumber: 'ABC-123',
  wheelers: 6,
  routes: ['Purok 1', 'Purok 2', 'Purok 3'],
  days: [1, 3, 5],
  startTime: '06:00',
  recurrence: 'weekly',
  status: 'pendingApproval',
  createdAt: serverTimestamp(),
  ...overrides,
});

test('Iswim drafts the manual and only City Hall approves it', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'assignment_manuals/a1'), assignmentManual()));
  // Nobody else drafts one, and Iswim cannot approve his own work.
  await assertFails(setDoc(doc(as('ivy'), 'assignment_manuals/a2'), assignmentManual({status: 'approved'})));
  await assertFails(setDoc(doc(as('carl'), 'assignment_manuals/a3'), assignmentManual()));
  await assertFails(setDoc(doc(as('alice'), 'assignment_manuals/a4'), assignmentManual()));
  // Staff, the crew and the named driver see the draft...
  await assertSucceeds(getDoc(doc(as('ivy'), 'assignment_manuals/a1')));
  await assertSucceeds(getDoc(doc(as('carl'), 'assignment_manuals/a1')));
  await assertSucceeds(getDoc(doc(as('root'), 'assignment_manuals/a1')));
  await assertSucceeds(getDoc(doc(as('dan'), 'assignment_manuals/a1')));
  // ...but a resident only sees it once it is approved.
  await assertFails(getDoc(doc(as('alice'), 'assignment_manuals/a1')));
  await assertFails(updateDoc(doc(as('root'), 'assignment_manuals/a1'), {status: 'approved'}));
  await assertFails(updateDoc(doc(as('alice'), 'assignment_manuals/a1'), {startTime: '05:00'}));
  await assertSucceeds(updateDoc(doc(as('carl'), 'assignment_manuals/a1'), {
    status: 'approved',
    approvedAt: Timestamp.now(),
    approvedByName: 'Carl',
  }));
  await assertSucceeds(getDoc(doc(as('alice'), 'assignment_manuals/a1')));
  await assertFails(deleteDoc(doc(as('dan'), 'assignment_manuals/a1')));
  await assertSucceeds(deleteDoc(doc(as('carl'), 'assignment_manuals/a1')));
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

// --- Removed recycling points ----------------------------------------------

test('the recycling station and its points ledger are gone', async () => {
  // The drop-off desk and the resident points wallet were removed from the
  // product, so nothing may recreate their collections.
  await assertFails(setDoc(doc(as('root'), 'points_transactions/p1'), {
    residentId: 'alice',
    points: 10,
    reason: 'Waste validation · Recyclable',
  }));
  await assertFails(setDoc(doc(as('root'), 'dropOffs/d1'), {
    residentId: 'alice',
    points: 10,
    weightKg: 2,
  }));
  await assertFails(getDoc(doc(as('alice'), 'points_transactions/p1')));
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

test('a manual ticket waits for City Hall before the driver can take it', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'trip_tickets/t2'), {
    code: 'TT-2026-0002',
    plateNumber: 'ABC 123',
    driverId: 'dan',
    driverName: 'Dan',
    kind: 'assignment',
    status: 'issued',
    approvalPending: true,
    pendingSigner: 'cityHall',
    createdBy: 'ivy',
    createdAt: serverTimestamp(),
    signatures: {},
    history: [],
  }));
  // The driver cannot accept, run or decline a manual the desk has not signed.
  await assertFails(updateDoc(doc(as('dan'), 'trip_tickets/t2'), {
    status: 'accepted',
    acceptedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(as('dan'), 'trip_tickets/t2'), {status: 'valid'}));
  // Only City Hall's signature turns it into a valid manual.
  await assertSucceeds(updateDoc(doc(as('carl'), 'trip_tickets/t2'), {
    status: 'valid',
    approvalPending: false,
    pendingSigner: null,
    signatures: {cityHall: {name: 'Carl', uid: 'carl', at: Timestamp.now()}},
  }));
  // With no end time, the driver closes the run themselves.
  await assertSucceeds(updateDoc(doc(as('dan'), 'trip_tickets/t2'), {
    status: 'completed',
    completedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(as('dan'), 'trip_tickets/t2'), {plateNumber: 'FORGED'}));
});

test('a crew opens the day ticket from a valid schedule only', async () => {
  // The schedule Iswim issued and City Hall has not signed yet.
  await assertSucceeds(setDoc(doc(as('ivy'), 'trip_tickets/sched'), {
    code: 'TT-2026-0100',
    plateNumber: 'ABC 123',
    truckId: 'truck1',
    driverId: 'dan',
    driverName: 'Dan',
    kind: 'assignment',
    status: 'issued',
    approvalPending: true,
    createdBy: 'ivy',
    createdAt: serverTimestamp(),
    signatures: {},
    history: [],
  }));
  const duty = (id, overrides = {}) => ({
    code: `TT-2026-0100-${id}`,
    plateNumber: 'ABC 123',
    truckId: 'truck1',
    driverId: 'dan',
    driverName: 'Dan',
    kind: 'run',
    status: 'issued',
    assignmentId: 'sched',
    createdBy: 'dan',
    createdAt: serverTimestamp(),
    signatures: {},
    history: [],
    ...overrides,
  });

  // A schedule waiting for City Hall is not a licence to open a duty ticket.
  await assertFails(setDoc(doc(as('dan'), 'trip_tickets/duty0'), duty('0')));

  await assertSucceeds(updateDoc(doc(as('carl'), 'trip_tickets/sched'), {
    status: 'valid',
    approvalPending: false,
    pendingSigner: null,
    signatures: {cityHall: {name: 'Carl', uid: 'carl', at: Timestamp.now()}},
  }));

  // Now the crew may copy it for today's duty.
  await assertSucceeds(setDoc(doc(as('dan'), 'trip_tickets/duty1'), duty('1')));
  // Another truck's schedule cannot be borrowed.
  await assertFails(
    setDoc(doc(as('dan'), 'trip_tickets/duty2'), duty('2', {truckId: 'truck2'})),
  );
  // A ticket naming someone else is refused.
  await assertFails(
    setDoc(doc(as('dan'), 'trip_tickets/duty3'), duty('3', {driverId: 'bob'})),
  );
});

test('a crew reports an incident to the Iswim desk', async () => {
  await assertSucceeds(setDoc(doc(as('dan'), 'driver_incidents/i1'), {
    driverId: 'dan',
    driverName: 'Dan',
    plateNumber: 'ABC 123',
    kind: 'accident',
    description: 'Side mirror clipped a post',
    status: 'open',
    createdAt: serverTimestamp(),
  }));
  // Someone else's name is refused.
  await assertFails(setDoc(doc(as('dan'), 'driver_incidents/i2'), {
    driverId: 'bob',
    driverName: 'Bob',
    plateNumber: 'ABC 123',
    kind: 'accident',
    description: 'Test',
    status: 'open',
  }));
  // Residents do not file crew reports.
  await assertFails(setDoc(doc(as('alice'), 'driver_incidents/i3'), {
    driverId: 'alice',
    driverName: 'Alice',
    plateNumber: '',
    kind: 'other',
    description: 'Test',
    status: 'open',
  }));

  // Iswim reads it and marks it seen.
  await assertSucceeds(getDoc(doc(as('ivy'), 'driver_incidents/i1')));
  await assertSucceeds(updateDoc(doc(as('ivy'), 'driver_incidents/i1'), {
    status: 'acknowledged',
    acknowledgedAt: Timestamp.now(),
    acknowledgedByName: 'Ivy',
  }));
  // The crew cannot close its own report.
  await assertFails(
    updateDoc(doc(as('dan'), 'driver_incidents/i1'), {status: 'closed'}),
  );
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

// --- Memos: Iswim <-> City Hall, with real attachments, status and signature.

const memoDoc = (overrides = {}) => ({
  kind: 'memo',
  subject: 'Collection schedule for wave 3',
  body: 'Please review the attached schedule before Friday.',
  fromName: 'Ivy',
  fromRole: 'iswim',
  fromUid: 'ivy',
  toChannel: 'cityHall',
  status: 'sent',
  createdAt: Timestamp.now(),
  ...overrides,
});

const png = {
  dataUrl: 'data:image/png;base64,iVBORw0KGgo=',
  fileName: 'schedule.png',
  mimeType: 'image/png',
  bytes: 12,
};

test('Iswim files a memo to City Hall with an attachment; City Hall reads it', async () => {
  await assertSucceeds(setDoc(doc(as('ivy'), 'memos/m1'), memoDoc({attachment: png})));
  await assertSucceeds(getDoc(doc(as('carl'), 'memos/m1')));
  await assertSucceeds(getDoc(doc(as('root'), 'memos/m1')));
  // Residents and drivers have no business in the memo channel.
  await assertFails(getDoc(doc(as('alice'), 'memos/m1')));
  await assertFails(getDoc(doc(as('dan'), 'memos/m1')));
});

test('a memo cannot be spoofed, self-addressed or malformed', async () => {
  // Someone else's name on the sender.
  await assertFails(setDoc(doc(as('ivy'), 'memos/m2'), memoDoc({fromUid: 'root'})));
  // Addressed to the office that writes it.
  await assertFails(setDoc(doc(as('ivy'), 'memos/m3'), memoDoc({toChannel: 'iswim'})));
  // A made-up destination.
  await assertFails(setDoc(doc(as('ivy'), 'memos/m4'), memoDoc({toChannel: 'district'})));
  // Already signed on creation.
  await assertFails(setDoc(doc(as('ivy'), 'memos/m5'), memoDoc({status: 'acknowledged'})));
  // Oversized subject.
  await assertFails(setDoc(doc(as('ivy'), 'memos/m6'), memoDoc({subject: 'x'.repeat(201)})));
  // A resident cannot use the government channel at all.
  await assertFails(setDoc(doc(as('alice'), 'memos/m7'), memoDoc({fromUid: 'alice', fromRole: 'barangay'})));
});

test('the addressed desk marks a memo received, once, and nobody else can', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'memos/m1'), memoDoc());
  });
  // The author is not the recipient.
  await assertFails(updateDoc(doc(as('ivy'), 'memos/m1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
  // The barangay is not the recipient either.
  await assertFails(updateDoc(doc(as('root'), 'memos/m1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(as('carl'), 'memos/m1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
  // Received is not a state City Hall can walk back or extend.
  await assertFails(updateDoc(doc(as('carl'), 'memos/m1'), {
    status: 'sent', receivedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(as('carl'), 'memos/m1'), {
    status: 'received', receivedAt: serverTimestamp(), subject: 'Rewritten',
  }));
});

test('City Hall files a memo to the barangay and only staff mark it received', async () => {
  const fromCityHall = memoDoc({
    fromUid: 'carl',
    fromName: 'Carl',
    fromRole: 'cityHall',
    toChannel: 'barangay',
  });
  await assertSucceeds(setDoc(doc(as('carl'), 'memos/b1'), fromCityHall));
  // The barangay desk reads it; Iswim has no claim on this one.
  await assertSucceeds(getDoc(doc(as('root'), 'memos/b1')));
  await assertFails(updateDoc(doc(as('ivy'), 'memos/b1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(as('root'), 'memos/b1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
});

test('City Hall signs a memo addressed to it, in its own name, and it is final', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    // One Firestore handle per context: a second context.firestore() call
    // would try to reconfigure an instance that has already started.
    const db = context.firestore();
    await setDoc(doc(db, 'memos/m1'), memoDoc());
    await setDoc(doc(db, 'memos/m2'), memoDoc({toChannel: 'barangay'}));
  });
  const sign = (uid, overrides = {}) => ({
    status: 'acknowledged',
    acknowledgedAt: serverTimestamp(),
    acknowledgedByUid: uid,
    acknowledgedByName: 'Carl',
    acknowledgementSignature: 'data:image/png;base64,iVBORw0KGgo=',
    ...overrides,
  });

  // The author cannot sign their own memo.
  await assertFails(updateDoc(doc(as('ivy'), 'memos/m1'), sign('ivy')));
  // City Hall cannot sign under someone else's identity.
  await assertFails(updateDoc(doc(as('carl'), 'memos/m1'), sign('root')));
  // A memo addressed to the barangay is not City Hall's to sign.
  await assertFails(updateDoc(doc(as('carl'), 'memos/m2'), sign('carl')));

  await assertSucceeds(updateDoc(doc(as('carl'), 'memos/m1'), sign('carl')));
  // Signed is final: no re-sign, no edit, no delete.
  await assertFails(updateDoc(doc(as('carl'), 'memos/m1'), sign('carl', {acknowledgedByName: 'Other'})));
  await assertFails(updateDoc(doc(as('ivy'), 'memos/m1'), {subject: 'Changed'}));
  await assertFails(deleteDoc(doc(as('carl'), 'memos/m1')));
});

test('the author corrects a memo only before it is received', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'memos/m1'), memoDoc());
  });
  await assertFails(updateDoc(doc(as('carl'), 'memos/m1'), {subject: 'City Hall rewrites'}));
  await assertSucceeds(updateDoc(doc(as('ivy'), 'memos/m1'), {
    subject: 'Corrected schedule',
    body: 'Friday moved to Saturday.',
    editedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(as('carl'), 'memos/m1'), {
    status: 'received', receivedAt: serverTimestamp(),
  }));
  // Once received, the text is frozen for the author too.
  await assertFails(updateDoc(doc(as('ivy'), 'memos/m1'), {
    subject: 'Too late', body: 'Too late.', editedAt: serverTimestamp(),
  }));
  // City Hall may still remove an unsigned memo.
  await assertSucceeds(deleteDoc(doc(as('carl'), 'memos/m1')));
});

test('a truck guide runs the driver duty on the driver paperwork', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/gil'), {
      name: 'Gil', role: 'driver', crewRole: 'guide',
    });
    await setDoc(doc(db, 'users/ben'), {name: 'Ben', role: 'driver'});
    // A guide has no route of his own; the run belongs to the driver.
    await deleteDoc(doc(db, 'routes/dan'));
    await setDoc(doc(db, 'trip_tickets/sched'), {
      code: 'TT-2026-0200',
      plateNumber: 'ABC 123',
      truckId: 'truck1',
      driverId: 'dan',
      driverName: 'Dan',
      kind: 'assignment',
      status: 'valid',
      approvalPending: false,
      createdBy: 'ivy',
      createdAt: Timestamp.now(),
      signatures: {},
      history: [],
    });
  });

  const duty = (id, overrides = {}) => ({
    code: `TT-2026-0200-${id}`,
    plateNumber: 'ABC 123',
    truckId: 'truck1',
    driverId: 'dan',
    driverName: 'Dan',
    kind: 'run',
    status: 'issued',
    assignmentId: 'sched',
    actedByUid: 'gil',
    actedByName: 'Gil',
    createdBy: 'gil',
    createdAt: serverTimestamp(),
    signatures: {},
    history: [],
    ...overrides,
  });

  // The guide opens the duty ticket of the schedule's driver.
  await assertSucceeds(setDoc(doc(as('gil'), 'trip_tickets/duty1'), duty('1')));
  // He cannot open one for another driver.
  await assertFails(
    setDoc(doc(as('gil'), 'trip_tickets/duty2'), duty('2', {driverId: 'ben'})),
  );
  // He cannot claim the ticket was opened by someone else.
  await assertFails(
    setDoc(doc(as('gil'), 'trip_tickets/duty3'), duty('3', {actedByUid: 'dan'})),
  );

  // Accept, start and end all move on the guide's own action.
  await assertSucceeds(updateDoc(doc(as('gil'), 'trip_tickets/duty1'), {
    status: 'accepted', acceptedAt: Timestamp.now(), history: [],
  }));
  await assertSucceeds(updateDoc(doc(as('gil'), 'trip_tickets/duty1'), {
    status: 'running', startedAt: Timestamp.now(), history: [],
  }));

  // The live route is written under the driver, authorised by that ticket.
  await assertSucceeds(setDoc(doc(as('gil'), 'routes/dan'), {
    driverName: 'Dan',
    status: 'inTransit',
    lat: 14.6,
    lng: 121.0,
    crewRole: 'guide',
    actedByUid: 'gil',
    actedByName: 'Gil',
    ticketId: 'duty1',
    assignmentId: 'sched',
    truckPlate: 'ABC 123',
    sessionId: 's1',
    startedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  }));
  // The same write without a duty ticket of his own is refused.
  await assertFails(setDoc(doc(as('gil'), 'routes/ben'), {
    driverName: 'Ben',
    status: 'inTransit',
    crewRole: 'guide',
    actedByUid: 'gil',
    ticketId: 'duty1',
  }));
  // A plain driver cannot publish someone else's route.
  await assertFails(setDoc(doc(as('ben'), 'routes/dan'), {
    driverName: 'Dan',
    status: 'inTransit',
    crewRole: 'guide',
    actedByUid: 'ben',
    ticketId: 'duty1',
  }));

  // The heartbeat keeps running on the route he opened…
  await assertSucceeds(updateDoc(doc(as('gil'), 'routes/dan'), {
    lat: 14.61, lng: 121.01, updatedAt: Timestamp.now(), lastSeenAt: Timestamp.now(),
  }));
  // …but he cannot rewrite who the driver is.
  await assertFails(updateDoc(doc(as('gil'), 'routes/dan'), {
    driverName: 'Someone else', updatedAt: Timestamp.now(),
  }));

  // End of route: the driver's ticket goes to the barangay.
  await assertSucceeds(updateDoc(doc(as('gil'), 'trip_tickets/duty1'), {
    status: 'submitted', submittedAt: Timestamp.now(), history: [],
  }));
  // Another driver cannot move a guide's ticket.
  await assertFails(updateDoc(doc(as('ben'), 'trip_tickets/duty1'), {
    status: 'accepted', acceptedAt: Timestamp.now(), history: [],
  }));
  // The schedule itself is never the guide's to consume.
  await assertFails(updateDoc(doc(as('gil'), 'trip_tickets/sched'), {
    status: 'completed', completedAt: Timestamp.now(), history: [],
  }));
});

// Run with: npm run test:emulator (needs firebase-tools on PATH; starts the
// Firestore emulator, then npm test)
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
  setDoc,
  updateDoc,
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
    await setDoc(doc(db, 'users/dan'), {name: 'Dan', role: 'driver'});
    await setDoc(doc(db, 'users/root'), {name: 'Root', role: 'admin'});
    await setDoc(doc(db, 'users/alice/locations/l1'), {latitude: 1});
    await setDoc(doc(db, 'shared_locations/dan'), shared('driver'));
    await setDoc(doc(db, 'shared_locations/alice'), shared('user'));
  });
});

test('only verified accounts can read shared locations', async () => {
  await assertFails(getDoc(doc(as('alice', false), 'shared_locations/dan')));
  await assertSucceeds(getDoc(doc(as('alice'), 'shared_locations/dan')));
});

test('signup cannot choose the admin role', async () => {
  await assertFails(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'admin'}));
  await assertSucceeds(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'user'}));
});

test('users cannot change their own role but can edit other fields', async () => {
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), {role: 'admin'}));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), {name: 'Al'}));
});

test('users cannot read other profiles', async () => {
  await assertFails(getDoc(doc(as('dan'), 'users/alice')));
});

test('shared location writes are type-checked and keep the real role', async () => {
  const mine = doc(as('alice'), 'shared_locations/alice');
  await assertFails(setDoc(mine, shared('user', {latitude: 'abc'})));
  await assertFails(setDoc(mine, shared('driver')));
  await assertSucceeds(setDoc(mine, shared('user')));
  await assertFails(setDoc(doc(as('alice'), 'shared_locations/dan'), shared('user')));
});

test('the calls the app makes every day are allowed', async () => {
  const alice = as('alice');
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
  await assertSucceeds(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
  await assertSucceeds(setDoc(doc(alice, 'shared_locations/alice'), shared('user')));
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
  await assertFails(getDoc(doc(alice, 'shared_locations/dan')));
  await assertFails(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
  await assertFails(setDoc(doc(alice, 'shared_locations/alice'), shared('user')));
  await assertFails(setDoc(doc(alice, 'users/alice'), {name: 'Alice', role: 'user'}));
});

test('a user being deleted cannot write while the delete is still running', async () => {
  // Admin delete has written the tombstone but not yet removed the profile.
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'removed_users/alice'), {removedAt: 1});
  });
  const alice = as('alice');
  await assertFails(setDoc(doc(alice, 'users/alice/locations/x'), {latitude: 1}));
  await assertFails(setDoc(doc(alice, 'shared_locations/alice'), shared('user')));
});

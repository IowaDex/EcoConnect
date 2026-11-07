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
  await assertFails(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'admin', accountStatus: 'active'}));
  await assertSucceeds(setDoc(doc(as('eve'), 'users/eve'), {name: 'Eve', role: 'user', accountStatus: 'active'}));
});

test('signup cannot skip approval, self-credit points or upload a huge photo', async () => {
  await assertFails(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'active'}));
  await assertFails(setDoc(doc(as('u1'), 'users/u1'), {name: 'U', role: 'user', accountStatus: 'active', points: 999}));
  await assertFails(setDoc(doc(as('u2'), 'users/u2'), {name: 'U', role: 'user', accountStatus: 'active', photoUrl: 'x'.repeat(150000)}));
  await assertSucceeds(setDoc(doc(as('d1'), 'users/d1'), {name: 'D', role: 'driver', accountStatus: 'pending'}));
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

test('a pending driver cannot publish a route, plan or shared location until approved', async () => {
  await env.withSecurityRulesDisabled((c) =>
    setDoc(doc(c.firestore(), 'users/pd'), {name: 'P', role: 'driver', accountStatus: 'pending'}));
  const live = {status: 'inTransit', lat: 1, lng: 2, updatedAt: Timestamp.now()};
  const plan = {driverId: 'pd', adHoc: true, status: 'scheduled'};
  await assertFails(setDoc(doc(as('pd'), 'routes/pd'), live));
  await assertFails(setDoc(doc(as('pd'), 'routePlans/p1'), plan));
  await assertFails(setDoc(doc(as('pd'), 'shared_locations/pd'), shared('driver')));
  await env.withSecurityRulesDisabled((c) =>
    updateDoc(doc(c.firestore(), 'users/pd'), {accountStatus: 'active'}));
  await assertSucceeds(setDoc(doc(as('pd'), 'routes/pd'), live));
  await assertSucceeds(setDoc(doc(as('pd'), 'routePlans/p1'), plan));
  await assertSucceeds(setDoc(doc(as('pd'), 'shared_locations/pd'), shared('driver')));
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
  await assertFails(setDoc(doc(alice, 'shared_locations/alice'), shared('user')));
});

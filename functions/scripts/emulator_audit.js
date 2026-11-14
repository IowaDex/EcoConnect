const assert = require('node:assert/strict');
const {initializeApp} = require('firebase-admin/app');
const {FieldValue, getFirestore} = require('firebase-admin/firestore');

const app = initializeApp({
  projectId: process.env.GCLOUD_PROJECT || 'demo-ecoconnect',
});
const db = getFirestore(app);

async function findAuditEntries(documentPath) {
  const snapshot = await db.collection('admin_audit')
      .where('documentPath', '==', documentPath)
      .get();
  return snapshot.docs.map((doc) => doc.data());
}

async function waitForAudit(documentPath, action) {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const entries = await findAuditEntries(documentPath);
    const entry = entries.find((candidate) => candidate.action === action);
    if (entry) return entry;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`Timed out waiting for ${action} audit entry at ${documentPath}`);
}

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run this script under the Firebase emulator suite.');
  }

  const id = `audit-emulator-${Date.now()}`;
  const ref = db.collection('collectionRequests').doc(id);
  await ref.set({status: 'pending', details: 'must not be copied'});
  const created = await waitForAudit(ref.path, 'create');
  assert.deepEqual(created.changedFields, ['details', 'status']);
  assert.equal(Object.hasOwn(created, 'details'), false);

  await ref.update({status: 'approved'});
  const updated = await waitForAudit(ref.path, 'update');
  assert.deepEqual(updated.changedFields, ['status']);

  await ref.delete();
  const deleted = await waitForAudit(ref.path, 'delete');
  assert.deepEqual(deleted.changedFields, ['details', 'status']);

  const routeId = `${id}-route`;
  const routeRef = db.collection('routes').doc(routeId);
  await routeRef.set({
    lat: 1,
    lng: 2,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await new Promise((resolve) => setTimeout(resolve, 1000));
  assert.deepEqual(await findAuditEntries(routeRef.path), []);

  await routeRef.update({status: 'paused', lat: 3});
  const routeAudit = await waitForAudit(routeRef.path, 'update');
  assert.deepEqual(routeAudit.changedFields, ['status']);
  await routeRef.delete();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

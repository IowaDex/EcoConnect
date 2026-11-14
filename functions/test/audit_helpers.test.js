const {test} = require('node:test');
const assert = require('node:assert/strict');
const {
  auditableFields,
  changedFields,
  classifyChange,
} = require('../audit_helpers');

test('changed fields reports names only, including nested map changes', () => {
  assert.deepEqual(
      changedFields(
          {status: 'pending', profile: {name: 'A'}, unchanged: true},
          {status: 'active', profile: {name: 'B'}, unchanged: true},
      ),
      ['profile', 'status'],
  );
});

test('route location and heartbeat fields are omitted from audit metadata', () => {
  assert.deepEqual(
      auditableFields(
          'routes/driver-1',
          ['lat', 'lastSeenAt', 'status', 'updatedAt'],
      ),
      ['status'],
  );
});

test('non-route changes retain their changed field names', () => {
  assert.deepEqual(
      auditableFields('collectionRequests/request-1', ['status', 'updatedAt']),
      ['status', 'updatedAt'],
  );
});

test('classifies created, updated, and deleted documents', () => {
  assert.equal(classifyChange(false, true), 'create');
  assert.equal(classifyChange(true, true), 'update');
  assert.equal(classifyChange(true, false), 'delete');
});

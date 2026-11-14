const {isDeepStrictEqual} = require('node:util');

const routeTelemetryFields = new Set([
  'lat',
  'lng',
  'lastKnownLat',
  'lastKnownLng',
  'geofenceLat',
  'geofenceLng',
  'geofenceMeters',
  'locationUpdatedAt',
  'lastSeenAt',
  'updatedAt',
]);

function changedFields(before, after) {
  const keys = new Set([
    ...Object.keys(before ?? {}),
    ...Object.keys(after ?? {}),
  ]);
  return [...keys]
      .filter((key) => !isDeepStrictEqual(before?.[key], after?.[key]))
      .sort();
}

function auditableFields(documentPath, fields) {
  if (!documentPath.startsWith('routes/')) return fields;
  return fields.filter((field) => !routeTelemetryFields.has(field));
}

function classifyChange(beforeExists, afterExists) {
  if (!beforeExists && afterExists) return 'create';
  if (beforeExists && !afterExists) return 'delete';
  return 'update';
}

module.exports = {
  auditableFields,
  changedFields,
  classifyChange,
};

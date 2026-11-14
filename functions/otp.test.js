const {test} = require('node:test');
const assert = require('node:assert');
const otp = require('./otp');

test('codes are six digits and keep leading zeros', () => {
  for (let i = 0; i < 200; i++) assert.match(otp.generateCode(), /^\d{6}$/);
});

test('a code matches only its own account', () => {
  const hash = otp.hashCode('alice', '012345');
  assert.ok(otp.codesMatch(hash, 'alice', '012345'));
  assert.ok(!otp.codesMatch(hash, 'alice', '012346'));
  assert.ok(!otp.codesMatch(hash, 'bob', '012345'));
  assert.ok(!otp.codesMatch(hash, 'alice', '12345'));
  assert.ok(!otp.codesMatch(hash, 'alice', 'abcdef'));
  assert.ok(!otp.codesMatch(undefined, 'alice', '012345'));
});

test('one email a minute, five an hour', () => {
  const now = 10_000_000;
  assert.deepEqual(otp.checkResend(null, now), {ok: true, recentSends: []});
  const tooSoon = otp.checkResend({lastSentAt: now - 20_000}, now);
  assert.equal(tooSoon.ok, false);
  assert.equal(tooSoon.waitSeconds, 40);
  const fiveRecent = [1, 2, 3, 4, 5].map((m) => now - m * 5 * 60_000);
  assert.deepEqual(
    otp.checkResend({lastSentAt: now - 5 * 60_000, sentAt: fiveRecent}, now),
    {ok: false, reason: 'too-many'},
  );
  const oldSends = [1, 2, 3, 4, 5].map((h) => now - h * 61 * 60_000);
  assert.equal(otp.checkResend({lastSentAt: now - 61 * 60_000, sentAt: oldSends}, now).ok, true);
});

test('verifying: right, wrong, expired, locked, missing', () => {
  const now = 50_000_000;
  const state = {
    codeHash: otp.hashCode('alice', '424242'),
    expiresAt: now + 1000,
    attempts: 0,
  };
  assert.equal(otp.verifyCode(state, 'alice', '424242', now), 'ok');
  assert.equal(otp.verifyCode(state, 'alice', '000000', now), 'wrong');
  assert.equal(otp.verifyCode({...state, expiresAt: now - 1}, 'alice', '424242', now), 'expired');
  assert.equal(otp.verifyCode({...state, attempts: otp.MAX_ATTEMPTS}, 'alice', '424242', now), 'locked');
  assert.equal(otp.verifyCode(null, 'alice', '424242', now), 'missing');
});

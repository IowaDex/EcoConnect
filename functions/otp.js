// Pure helpers for the sign-up email code. No Firebase here, so they are
// unit-tested directly (otp.test.js).

const crypto = require('node:crypto');

const CODE_TTL_MS = 10 * 60 * 1000; // a code is valid for 10 minutes
const RESEND_WAIT_MS = 60 * 1000; // at most one email a minute
const MAX_SENDS_PER_HOUR = 5;
const MAX_ATTEMPTS = 5; // wrong guesses before a new code is needed

/** A uniformly random 6-digit code, leading zeros kept. */
function generateCode() {
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

/** The stored form: never the code itself, and bound to the account. */
function hashCode(uid, code) {
  return crypto.createHash('sha256').update(`${uid}:${code}`).digest('hex');
}

function codesMatch(storedHash, uid, code) {
  if (typeof storedHash !== 'string' || !/^\d{6}$/.test(String(code))) {
    return false;
  }
  const a = Buffer.from(storedHash, 'hex');
  const b = Buffer.from(hashCode(uid, String(code)), 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Whether another email may be sent now.
 * Returns {ok: true, recentSends} or {ok: false, waitSeconds | reason}.
 */
function checkResend(state, now) {
  const lastSentAt = state?.lastSentAt ?? 0;
  if (now - lastSentAt < RESEND_WAIT_MS) {
    return {
      ok: false,
      waitSeconds: Math.ceil((RESEND_WAIT_MS - (now - lastSentAt)) / 1000),
    };
  }
  const recentSends = (state?.sentAt ?? []).filter(
    (t) => now - t < 60 * 60 * 1000,
  );
  if (recentSends.length >= MAX_SENDS_PER_HOUR) {
    return {ok: false, reason: 'too-many'};
  }
  return {ok: true, recentSends};
}

/**
 * Checks a typed code against the stored state.
 * Returns 'ok' | 'expired' | 'locked' | 'wrong' | 'missing'.
 */
function verifyCode(state, uid, code, now) {
  if (!state || !state.codeHash) return 'missing';
  if ((state.attempts ?? 0) >= MAX_ATTEMPTS) return 'locked';
  if (now > (state.expiresAt ?? 0)) return 'expired';
  return codesMatch(state.codeHash, uid, code) ? 'ok' : 'wrong';
}

module.exports = {
  CODE_TTL_MS,
  RESEND_WAIT_MS,
  MAX_SENDS_PER_HOUR,
  MAX_ATTEMPTS,
  generateCode,
  hashCode,
  codesMatch,
  checkResend,
  verifyCode,
};

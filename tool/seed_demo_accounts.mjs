#!/usr/bin/env node
/**
 * Creates the EcoConnect demo accounts.
 *
 * Run from the project root:  node tool/seed_demo_accounts.mjs
 *
 * It signs each account up through the Firebase Auth REST API (same rules as
 * the app), then writes the matching `users/{uid}` profile with role `user` —
 * the only role a self-signup may create. Promote them once, in the app:
 *
 *   login as your admin -> Admin panel -> tap the account -> change role
 *
 *   cityhall@ecoconnect.test  -> City Hall (DSQC)
 *   iswim@ecoconnect.test     -> Iswim
 *   barangay@ecoconnect.test  -> Barangay admin
 *   ramon@ecoconnect.test     -> Driver   (name matches truck SK 4821)
 *   guide@ecoconnect.test     -> Driver   (then switch to Truck Guide on the
 *                                          fleet list to preview the guide view)
 *
 * Passwords are printed at the end. Nothing is deleted: re-running skips
 * accounts that already exist.
 */
import { readFileSync } from 'node:fs';

const env = Object.fromEntries(
  readFileSync(new URL('../.env', import.meta.url), 'utf8')
    .split('\n')
    .filter((line) => line.includes('=') && !line.trim().startsWith('#'))
    .map((line) => {
      const index = line.indexOf('=');
      return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
    }),
);

const API_KEY = env.FIREBASE_API_KEY;
const PROJECT = env.FIREBASE_PROJECT_ID;

if (!API_KEY || !PROJECT) {
  console.error('FIREBASE_API_KEY / FIREBASE_PROJECT_ID missing from .env');
  process.exit(1);
}

const PASSWORD = 'EcoConnect2026!';

const ACCOUNTS = [
  { email: 'cityhall@ecoconnect.test', name: 'DSQC City Hall' },
  { email: 'iswim@ecoconnect.test', name: 'Iswim Operations' },
  { email: 'barangay@ecoconnect.test', name: 'Barangay Batasan Admin' },
  // Name matches the mock fleet roster, so the driver lands on SK 4821.
  { email: 'ramon@ecoconnect.test', name: 'Ramon Dela Cruz' },
  { email: 'guide@ecoconnect.test', name: 'Joel Santiago' },
];

const AUTH = 'https://identitytoolkit.googleapis.com/v1';
const FIRESTORE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function post(url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  return { ok: response.ok, data };
}

async function signUp(email) {
  const { ok, data } = await post(`${AUTH}/accounts:signUp?key=${API_KEY}`, {
    email,
    password: PASSWORD,
    returnSecureToken: true,
  });
  if (ok) return { uid: data.localId, idToken: data.idToken, created: true };

  const message = data?.error?.message ?? 'unknown error';
  if (message === 'EMAIL_EXISTS') {
    const login = await post(`${AUTH}/accounts:signInWithPassword?key=${API_KEY}`, {
      email,
      password: PASSWORD,
      returnSecureToken: true,
    });
    if (login.ok) {
      return {
        uid: login.data.localId,
        idToken: login.data.idToken,
        created: false,
      };
    }
    throw new Error(`${email}: exists but the password does not match`);
  }
  throw new Error(`${email}: ${message}`);
}

async function writeProfile(uid, idToken, name, email) {
  const body = {
    fields: {
      name: { stringValue: name },
      email: { stringValue: email },
      role: { stringValue: 'user' },
      accountStatus: { stringValue: 'active' },
      accountType: { stringValue: 'resident' },
      verificationStatus: { stringValue: 'unverified' },
      emailVerified: { booleanValue: false },
      createdAt: { timestampValue: new Date().toISOString() },
    },
  };
  const response = await fetch(`${FIRESTORE}/users/${uid}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`profile write failed (${response.status}): ${text}`);
  }
}

for (const account of ACCOUNTS) {
  try {
    const { uid, idToken, created } = await signUp(account.email);
    await writeProfile(uid, idToken, account.name, account.email);
    console.log(
      `${created ? 'created' : 'exists '}  ${account.email.padEnd(28)} ${uid}`,
    );
  } catch (error) {
    console.error(`FAILED   ${error.message}`);
  }
}

console.log(`
Accounts ready. Password for all: ${PASSWORD}

ONE manual step, in the Firebase console (Firestore -> users -> the doc):
  cityhall@ecoconnect.test -> role: cityHall   (this is the super admin)

After that, sign in as cityhall@ and create the rest in-app:
  /accounts -> "Account" -> Iswim / Driver / Barangay admin / City Hall.
Each new login gets a plate and a one-time password, so nothing is promoted
by hand again.

Deploy the rules before signing in:  firebase deploy --only firestore:rules
`);

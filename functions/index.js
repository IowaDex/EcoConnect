// Sign-up email code (OTP) for EcoConnect residents.
//
//   requestSignupOtp  — emails a 6-digit code to the signed-in resident.
//   verifySignupOtp   — checks the typed code; on success the email counts as
//                       verified and the barangay is told a registration waits.
//
// The resident is signed in (but still `pending`) the whole time, so both are
// callable functions tied to request.auth. Codes are stored hashed in
// signupOtps/{uid}, which the Firestore rules close to every client.
//
// Mail is sent over SMTP with secrets set once by the owner:
//   firebase functions:secrets:set SMTP_USER   (e.g. the Gmail address)
//   firebase functions:secrets:set SMTP_PASS   (a Gmail App Password)

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const otp = require('./otp');

admin.initializeApp();
const db = admin.firestore();

const SMTP_USER = defineSecret('SMTP_USER');
const SMTP_PASS = defineSecret('SMTP_PASS');

/** The caller's pending resident profile, or a clear error. */
async function pendingResident(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in again to continue.');
  const snap = await db.collection('users').doc(uid).get();
  const profile = snap.data();
  if (!profile || profile.role !== 'user') {
    throw new HttpsError('failed-precondition', 'No resident sign-up was found for this account.');
  }
  if (profile.emailOtpVerified === true) {
    throw new HttpsError('already-exists', 'Your email is already verified. Wait for the barangay to approve your account.');
  }
  if (profile.accountStatus !== 'pending') {
    throw new HttpsError('failed-precondition', 'This account is not waiting for email verification.');
  }
  return {uid, profile};
}

exports.requestSignupOtp = onCall(
  {secrets: [SMTP_USER, SMTP_PASS]},
  async (request) => {
    const {uid, profile} = await pendingResident(request);
    const user = await admin.auth().getUser(uid);
    if (!user.email) throw new HttpsError('failed-precondition', 'This account has no email address.');

    const ref = db.collection('signupOtps').doc(uid);
    const now = Date.now();
    const state = (await ref.get()).data();
    const allowed = otp.checkResend(state, now);
    if (!allowed.ok) {
      throw new HttpsError(
        'resource-exhausted',
        allowed.reason === 'too-many'
          ? 'Too many codes requested. Try again in an hour.'
          : `Please wait ${allowed.waitSeconds} seconds before asking for a new code.`,
      );
    }

    const code = otp.generateCode();
    const transport = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: {user: SMTP_USER.value(), pass: SMTP_PASS.value()},
    });
    try {
      await transport.sendMail({
        from: `EcoConnect Batasan Hills <${SMTP_USER.value()}>`,
        to: user.email,
        subject: `${code} is your EcoConnect verification code`,
        text:
          `Hi ${profile.name || 'there'},\n\n` +
          `Your EcoConnect verification code is: ${code}\n\n` +
          'Enter it in the app within 10 minutes. After that, Barangay Batasan Hills ' +
          'will check your ID and approve your account.\n\n' +
          "If you didn't sign up for EcoConnect, ignore this email.",
      });
    } catch (e) {
      console.error('OTP email failed', e);
      throw new HttpsError('unavailable', 'We could not send the email. Try again in a moment.');
    }

    // Saved only after the email went out, so a failed send never burns a slot.
    await ref.set({
      codeHash: otp.hashCode(uid, code),
      expiresAt: now + otp.CODE_TTL_MS,
      attempts: 0,
      lastSentAt: now,
      sentAt: [...allowed.recentSends, now],
    });
    return {sentTo: user.email, expiresInSeconds: otp.CODE_TTL_MS / 1000};
  },
);

exports.verifySignupOtp = onCall(async (request) => {
  const {uid, profile} = await pendingResident(request);
  const code = String(request.data?.code ?? '').trim();
  if (!/^\d{6}$/.test(code)) throw new HttpsError('invalid-argument', 'Enter the 6-digit code.');

  const ref = db.collection('signupOtps').doc(uid);
  const state = (await ref.get()).data();
  const result = otp.verifyCode(state, uid, code, Date.now());

  if (result === 'missing') throw new HttpsError('not-found', 'Ask for a new code first.');
  if (result === 'locked') throw new HttpsError('resource-exhausted', 'Too many wrong tries. Ask for a new code.');
  if (result === 'expired') throw new HttpsError('deadline-exceeded', 'That code has expired. Ask for a new one.');
  if (result === 'wrong') {
    const attempts = (state.attempts ?? 0) + 1;
    await ref.update({attempts});
    const left = otp.MAX_ATTEMPTS - attempts;
    throw new HttpsError(
      'permission-denied',
      left > 0 ? `Wrong code. ${left} ${left === 1 ? 'try' : 'tries'} left.` : 'Too many wrong tries. Ask for a new code.',
    );
  }

  // Correct: the email is verified and the request goes to the barangay.
  const batch = db.batch();
  batch.update(db.collection('users').doc(uid), {
    emailOtpVerified: true,
    emailOtpVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    emailVerified: true,
  });
  batch.delete(ref);
  batch.set(db.collection('notifications').doc(), {
    userId: 'staff',
    title: 'New resident registration',
    body: `${profile.name || 'A resident'} verified their email and is waiting for ID review.`,
    type: 'account',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    data: {uid},
  });
  await batch.commit();
  await admin.auth().updateUser(uid, {emailVerified: true});
  return {verified: true};
});

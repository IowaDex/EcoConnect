// Cloud Functions for EcoConnect Email Service
// Deploy with: firebase deploy --only functions

const functions = require('firebase-functions');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const brevoSmtpKey = defineSecret('BREVO_SMTP_KEY');
const brevoSmtpUser = defineSecret('BREVO_SMTP_USER');
const brevoSenderEmail = defineSecret('BREVO_SENDER_EMAIL');

function getBrevoConfig() {
  const senderEmail = brevoSenderEmail.value() || process.env.BREVO_SENDER_EMAIL;
  const smtpUser = brevoSmtpUser.value() || process.env.BREVO_SMTP_USER;
  const smtpKey = brevoSmtpKey.value() || process.env.BREVO_SMTP_KEY;

  if (!senderEmail || !smtpUser || !smtpKey) {
    throw new Error('Brevo email configuration is incomplete');
  }

  return {senderEmail, smtpUser, smtpKey};
}

function createTransporter() {
  const {smtpUser, smtpKey} = getBrevoConfig();
  return nodemailer.createTransport({
    host: 'smtp-relay.brevo.com',
    port: 587,
    secure: false,
    auth: {user: smtpUser, pass: smtpKey},
  });
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[character]));
}

async function sendVerificationEmail(user) {
  if (!user.email) {
    throw new Error('User does not have an email address');
  }

  const verificationLink = await admin.auth().generateEmailVerificationLink(
      user.email,
  );
  const {senderEmail} = getBrevoConfig();
  await createTransporter().sendMail({
    from: `"EcoConnect" <${senderEmail}>`,
    to: user.email,
    subject: emailTemplates.verification.subject,
    html: emailTemplates.verification.html({
      userName: user.displayName || 'User',
      verificationLink,
    }),
  });
}

// Email templates
const emailTemplates = {
  verification: {
    subject: 'Verify Your Email - EcoConnect',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>EcoConnect Email Verification</title>
      </head>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="text-align: center; margin-bottom: 40px;">
          <h1 style="color: #4CAF50;">🌿 EcoConnect</h1>
          <p style="color: #666;">Connecting communities for a greener future</p>
        </div>

        <div style="background: #f8f9fa; padding: 30px; border-radius: 10px; margin-bottom: 30px;">
          <h2 style="color: #333; margin-top: 0;">Welcome, ${escapeHtml(data.userName)}!</h2>
          <p style="color: #555; line-height: 1.6;">
            Thank you for creating an account with EcoConnect. We're excited to have you on board!
          </p>
          <p style="color: #555; line-height: 1.6;">
            Before you can access all features, please verify your email address by clicking the button below:
          </p>
        </div>

        <div style="text-align: center; margin: 40px 0;">
          <a href="${escapeHtml(data.verificationLink)}"
             style="display: inline-block; background: #4CAF50; color: white; padding: 15px 30px;
                    text-decoration: none; border-radius: 5px; font-weight: bold;
                    font-size: 16px; transition: background 0.3s;">
            Verify Email Address
          </a>
        </div>

        <p style="color: #777; font-size: 14px; text-align: center;">
          If the button doesn't work, copy and paste this link into your browser:<br>
          <a href="${escapeHtml(data.verificationLink)}">${escapeHtml(data.verificationLink)}</a>
        </p>

        <hr style="border: none; border-top: 1px solid #eee; margin: 40px 0;">

        <p style="color: #999; font-size: 12px; text-align: center;">
          If you didn't create an EcoConnect account, please ignore this email.
        </p>
      </body>
      </html>
    `,
  },

  welcome: {
    subject: 'Welcome to EcoConnect!',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Welcome to EcoConnect</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #4CAF50;">Welcome to EcoConnect, ${escapeHtml(data.userName)}! 🌱</h2>
        <p>Thank you for joining our community of eco-conscious individuals.</p>
        <p>You can now:</p>
        <ul>
          <li>Track your carbon footprint</li>
          <li>Connect with local environmental groups</li>
          <li>Discover sustainability initiatives near you</li>
          <li>Share your green initiatives</li>
        </ul>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${escapeHtml(data.loginUrl)}"
             style="background: #4CAF50; color: white; padding: 12px 24px;
                    text-decoration: none; border-radius: 5px; font-weight: bold;">
            Get Started
          </a>
        </div>
        <p>If you have any questions, just reply to this email.</p>
        <p>Happy eco-connecting!</p>
        <p><strong>The EcoConnect Team</strong></p>
      </body>
      </html>
    `,
  },

  passwordReset: {
    subject: 'Reset Your Password - EcoConnect',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Password Reset</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #4CAF50;">Reset Your Password</h2>
        <p>You have requested to reset your password for your EcoConnect account.</p>
        <p>Click the button below to create a new password:</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${escapeHtml(data.resetLink)}"
             style="background: #4CAF50; color: white; padding: 12px 24px;
                    text-decoration: none; border-radius: 5px; font-weight: bold;">
            Reset Password
          </a>
        </div>
        <p>This link will expire in 1 hour for your security.</p>
        <p>If you didn't request this, please ignore this email. Your password will remain unchanged.</p>
        <p><strong>The EcoConnect Team</strong></p>
      </body>
      </html>
    `,
  },

  notification: {
    subject: 'Notification from EcoConnect',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>EcoConnect Notification</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #4CAF50;">${escapeHtml(data.subject || 'Notification')}</h2>
        <p>Hello ${escapeHtml(data.userName)},</p>
        <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
          ${escapeHtml(data.message)}
        </div>
        <p>Stay connected with EcoConnect for more updates!</p>
        <p><strong>The EcoConnect Team</strong></p>
      </body>
      </html>
    `,
  },
};

// Send email function
exports.sendEmail = functions.https.onCall(
  {secrets: [brevoSmtpKey, brevoSmtpUser, brevoSenderEmail]},
  async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to send emails'
    );
  }

  const {to, subject, templateType, templateData} = data || {};

  if (typeof to !== 'string' || !to.trim() || typeof templateType !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: to and templateType'
    );
  }

  // Validate template type
  const validTemplates = ['verification', 'welcome', 'passwordReset', 'notification'];
  if (!validTemplates.includes(templateType)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid template type. Valid types: ${validTemplates.join(', ')}`
    );
  }

  if (subject !== undefined && typeof subject !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Subject must be a string'
    );
  }
  if (templateData !== undefined &&
      (templateData === null ||
        typeof templateData !== 'object' ||
        Array.isArray(templateData))) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Template data must be an object'
    );
  }

  try {
    const template = emailTemplates[templateType];
    const {senderEmail} = getBrevoConfig();

    const mailOptions = {
      from: `"EcoConnect" <${senderEmail}>`,
      to: to.trim(),
      subject: subject || template.subject,
      html: template.html(templateData || {}),
    };

    const info = await createTransporter().sendMail(mailOptions);

    return {
      success: true,
      messageId: info.messageId,
      sentAt: new Date().toISOString(),
    };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send email'
    );
  }
  },
);

// Email verification on user creation (trigger)
exports.sendVerificationEmail = functions.https.onCall(
  {secrets: [brevoSmtpKey, brevoSmtpUser, brevoSenderEmail]},
  async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to request email verification'
    );
  }

  try {
    await sendVerificationEmail(await admin.auth().getUser(context.auth.uid));
    return {success: true};
  } catch (error) {
    console.error('Failed to send verification email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send verification email'
    );
  }
  },
);

exports.sendVerificationOnCreate = functions.auth.user().onCreate(
  {secrets: [brevoSmtpKey, brevoSmtpUser, brevoSenderEmail]},
  async (user) => {
  if (user.email) {
    try {
      await sendVerificationEmail(user);
    } catch (error) {
      console.error('Failed to send verification email:', error);
    }
  }
  },
);

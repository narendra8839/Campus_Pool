const test = require('node:test');
const assert = require('node:assert/strict');
const { validateFirebaseIdentity } = require('../src/utils/firebaseIdentity');

test('accepts verified VIT student emails and normalizes the email', () => {
  assert.deepEqual(
    validateFirebaseIdentity({
      uid: 'firebase-user-1',
      email: 'Student@VIT.EDU ',
      email_verified: true,
    }),
    { valid: true, email: 'student@vit.edu' },
  );
});

test('rejects missing, unverified, and non-campus Firebase identities', () => {
  for (const identity of [
    null,
    { uid: 'firebase-user-1', email: 'student@vit.edu' },
    {
      uid: 'firebase-user-1',
      email: 'student@vit.edu',
      email_verified: false,
    },
    {
      uid: 'firebase-user-1',
      email: 'student@sub.vit.edu',
      email_verified: true,
    },
    {
      uid: 'firebase-user-1',
      email: 'student@not-vit.edu',
      email_verified: true,
    },
    {
      uid: ' ',
      email: 'student@vit.edu',
      email_verified: true,
    },
  ]) {
    assert.equal(validateFirebaseIdentity(identity).valid, false);
  }
});

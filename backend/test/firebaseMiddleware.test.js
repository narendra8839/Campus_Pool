const test = require('node:test');
const assert = require('node:assert/strict');
const firebaseAdminService = require('../src/services/firebaseAdminService');

const originalGetFirebaseAdminAuth = firebaseAdminService.getFirebaseAdminAuth;
let identity;
let verificationError;
firebaseAdminService.getFirebaseAdminAuth = () => ({
  verifyIdToken: async (token, checkRevoked) => {
    assert.equal(token, 'firebase-id-token');
    assert.equal(checkRevoked, true);
    if (verificationError) throw verificationError;
    return identity;
  },
});

const { verifyFirebaseToken } = require('../src/middleware/authMiddleware');

test.after(() => {
  firebaseAdminService.getFirebaseAdminAuth = originalGetFirebaseAdminAuth;
});

function responseRecorder() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('accepts valid Firebase bearer token and attaches normalized identity', async () => {
  identity = {
    uid: 'firebase-user-1',
    email: 'Student@VIT.EDU',
    email_verified: true,
  };
  verificationError = null;
  const req = { headers: { authorization: 'Bearer firebase-id-token' } };
  const res = responseRecorder();
  let calledNext = false;

  await verifyFirebaseToken(req, res, (error) => {
    if (error) throw error;
    calledNext = true;
  });

  assert.equal(calledNext, true);
  assert.equal(req.firebaseIdentity.email, 'student@vit.edu');
});

test('rejects an unverified Firebase claim before continuing', async () => {
  identity = {
    uid: 'firebase-user-1',
    email: 'student@vit.edu',
    email_verified: false,
  };
  verificationError = null;
  const res = responseRecorder();
  let calledNext = false;

  await verifyFirebaseToken(
    { headers: { authorization: 'Bearer firebase-id-token' } },
    res,
    () => {
      calledNext = true;
    },
  );

  assert.equal(res.statusCode, 403);
  assert.equal(calledNext, false);
});

test('returns unauthorized for an expired Firebase ID token', async () => {
  identity = null;
  verificationError = Object.assign(new Error('Expired token'), {
    code: 'auth/id-token-expired',
  });
  const res = responseRecorder();

  await verifyFirebaseToken(
    { headers: { authorization: 'Bearer firebase-id-token' } },
    res,
    (error) => {
      if (error) throw error;
    },
  );

  assert.equal(res.statusCode, 401);
});

test('passes Firebase Admin configuration errors to the error handler', async () => {
  identity = null;
  verificationError = Object.assign(new Error('Invalid credentials'), {
    code: 'app/invalid-credential',
  });
  const res = responseRecorder();
  let forwardedError;

  await verifyFirebaseToken(
    { headers: { authorization: 'Bearer firebase-id-token' } },
    res,
    (error) => {
      forwardedError = error;
    },
  );

  assert.equal(forwardedError, verificationError);
  assert.equal(res.statusCode, 200);
});

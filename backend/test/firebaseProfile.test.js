const test = require('node:test');
const assert = require('node:assert/strict');
const prisma = require('../src/config/prisma');
const { provisionFirebaseProfile } = require('../src/controllers/authController');

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

function verifiedIdentity(overrides = {}) {
  return {
    uid: 'firebase-user-1',
    email: 'student@vit.edu',
    email_verified: true,
    name: 'Firebase Student',
    ...overrides,
  };
}

test('creates a profile only for a verified Firebase identity', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalCreate = prisma.user.create;
  const lookupCalls = [];
  let createdData;
  prisma.user.findUnique = async (query) => {
    lookupCalls.push(query);
    return null;
  };
  prisma.user.create = async ({ data }) => {
    createdData = data;
    return {
      id: 'profile-1',
      firebaseUid: data.firebaseUid,
      email: data.email,
      name: data.name,
      phone: data.phone,
      roles: data.roles,
      isVerified: data.isVerified,
    };
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
      firebaseIdentity: verifiedIdentity(),
      body: { phone: '9876543210', gender: 'female' },
    }, res, (error) => {
      if (error) throw error;
    });

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.data.email, 'student@vit.edu');
    assert.equal(createdData.firebaseUid, 'firebase-user-1');
    assert.equal(createdData.password, null);
    assert.equal(createdData.isVerified, true);
    assert.equal(createdData.gender, 'female');
    assert.equal(lookupCalls.length, 2);
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.user.create = originalCreate;
  }
});

test('returns an existing profile by Firebase UID without creating a duplicate', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalCreate = prisma.user.create;
  const existingProfile = {
    id: 'profile-1',
    email: 'student@vit.edu',
  };
  prisma.user.findUnique = async ({ where }) =>
    where.firebaseUid ? existingProfile : null;
  prisma.user.create = async () => {
    throw new Error('Should not create an existing profile.');
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
      firebaseIdentity: verifiedIdentity(),
      body: {},
    }, res, (error) => {
      if (error) throw error;
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.data, existingProfile);
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.user.create = originalCreate;
  }
});

test('links a verified Firebase identity to an existing profile by exact email', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalUpdateMany = prisma.user.updateMany;
  const originalCreate = prisma.user.create;
  const existingProfile = {
    id: 'existing-profile',
    email: 'student@vit.edu',
    firebaseUid: null,
    isVerified: false,
  };
  const linkedProfile = {
    ...existingProfile,
    firebaseUid: 'firebase-user-1',
    isVerified: true,
  };
  let linkQuery;
  let isLinked = false;
  prisma.user.findUnique = async ({ where }) => {
    if (where.firebaseUid) {
      return isLinked && where.firebaseUid === linkedProfile.firebaseUid
        ? linkedProfile
        : null;
    }
    return where.email ? existingProfile : null;
  };
  prisma.user.updateMany = async (query) => {
    linkQuery = query;
    isLinked = true;
    return { count: 1 };
  };
  prisma.user.create = async () => {
    throw new Error('Should link, not create, an existing profile.');
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
      firebaseIdentity: verifiedIdentity(),
      body: {},
    }, res, (error) => {
      if (error) throw error;
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.data, linkedProfile);
    assert.deepEqual(linkQuery.where, {
      id: 'existing-profile',
      email: 'student@vit.edu',
      firebaseUid: null,
    });
    assert.deepEqual(linkQuery.data, {
      firebaseUid: 'firebase-user-1',
      isVerified: true,
    });
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.user.updateMany = originalUpdateMany;
    prisma.user.create = originalCreate;
  }
});

test('does not link a profile already attached to another Firebase identity', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalUpdateMany = prisma.user.updateMany;
  const existingProfile = {
    id: 'existing-profile',
    email: 'student@vit.edu',
    firebaseUid: 'different-firebase-user',
  };
  prisma.user.findUnique = async ({ where }) =>
    where.firebaseUid === 'firebase-user-1' ? null : existingProfile;
  prisma.user.updateMany = async () => {
    throw new Error('Must not replace another Firebase identity.');
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
    firebaseIdentity: verifiedIdentity(),
    body: {},
    }, res, (error) => {
    if (error) throw error;
    });
    assert.equal(res.statusCode, 409);
    assert.match(res.body.message, /linked to another Firebase account/);
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.user.updateMany = originalUpdateMany;
  }
});

test('rejects unverified identity claims before querying the database', async () => {
  const originalFindUnique = prisma.user.findUnique;
  prisma.user.findUnique = async () => {
    throw new Error('Database should not be queried.');
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
      firebaseIdentity: verifiedIdentity({ email_verified: false }),
      body: {},
    }, res, (error) => {
      if (error) throw error;
    });
    assert.equal(res.statusCode, 403);
  } finally {
    prisma.user.findUnique = originalFindUnique;
  }
});

test('turns concurrent duplicate profile creation into a conflict response', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalCreate = prisma.user.create;
  prisma.user.findUnique = async () => null;
  prisma.user.create = async () => {
    const error = new Error('Unique constraint failed');
    error.code = 'P2002';
    throw error;
  };

  try {
    const res = responseRecorder();
    await provisionFirebaseProfile({
      firebaseIdentity: verifiedIdentity(),
      body: {},
    }, res, (error) => {
      if (error) throw error;
    });
    assert.equal(res.statusCode, 409);
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.user.create = originalCreate;
  }
});

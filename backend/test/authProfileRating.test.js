const test = require('node:test');
const assert = require('node:assert/strict');
const prisma = require('../src/config/prisma');
const { getMe } = require('../src/controllers/authController');

function mockResponse() {
  return {
    body: undefined,
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('returns profile rating totals derived from actual received reviews', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalAggregate = prisma.review.aggregate;
  prisma.user.findUnique = async () => ({
    id: 'user-1',
    name: 'Campus Pool User',
    ratingAvg: 4.2,
    ratingCount: 12,
  });
  prisma.review.aggregate = async () => ({
    _avg: { rating: 4.5 },
    _count: { rating: 2 },
  });
  const response = mockResponse();
  let nextError;

  try {
    await getMe({ user: { id: 'user-1' } }, response, (error) => {
      nextError = error;
    });
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.review.aggregate = originalAggregate;
  }

  assert.equal(nextError, undefined);
  assert.equal(response.body.data.ratingAvg, 4.5);
  assert.equal(response.body.data.ratingCount, 2);
});

test('returns zero received reviews instead of stale seeded rating totals', async () => {
  const originalFindUnique = prisma.user.findUnique;
  const originalAggregate = prisma.review.aggregate;
  prisma.user.findUnique = async () => ({
    id: 'user-1',
    ratingAvg: 4.2,
    ratingCount: 12,
  });
  prisma.review.aggregate = async () => ({
    _avg: { rating: null },
    _count: { rating: 0 },
  });
  const response = mockResponse();
  let nextError;

  try {
    await getMe({ user: { id: 'user-1' } }, response, (error) => {
      nextError = error;
    });
  } finally {
    prisma.user.findUnique = originalFindUnique;
    prisma.review.aggregate = originalAggregate;
  }

  assert.equal(nextError, undefined);
  assert.equal(response.body.data.ratingAvg, 5);
  assert.equal(response.body.data.ratingCount, 0);
});

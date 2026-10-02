const test = require('node:test');
const assert = require('node:assert/strict');
const { createRandom, generateReviews } = require('../scripts/generate-synthetic-data');

test('synthetic reviews provide distinct examples for every sentiment class', () => {
  const rides = Array.from({ length: 900 }, (_, index) => ({
    id: `ride-${index}`,
    driverId: 'driver',
    departureTime: '2026-09-21T12:00:00.000Z',
  }));
  const bookings = rides.map((ride, index) => ({
    rideId: ride.id,
    passengerId: `passenger-${index}`,
    status: 'COMPLETED',
  }));

  const reviews = generateReviews(createRandom(42), rides, bookings, []);
  const uniqueCommentsByClass = new Map([
    ['negative', new Set()],
    ['neutral', new Set()],
    ['positive', new Set()],
  ]);

  for (const review of reviews) {
    const sentiment = review.rating <= 2
      ? 'negative'
      : review.rating === 3
        ? 'neutral'
        : 'positive';
    uniqueCommentsByClass.get(sentiment).add(review.comment);
  }

  assert.equal(reviews.length, 900);
  for (const [sentiment, comments] of uniqueCommentsByClass) {
    assert.ok(comments.size >= 10, `${sentiment} has only ${comments.size} unique comments`);
  }
});

test('synthetic review generation is deterministic for a fixed seed', () => {
  const rides = Array.from({ length: 20 }, (_, index) => ({
    id: `ride-${index}`,
    driverId: 'driver',
    departureTime: '2026-09-21T12:00:00.000Z',
  }));
  const bookings = rides.map((ride, index) => ({
    rideId: ride.id,
    passengerId: `passenger-${index}`,
    status: 'COMPLETED',
  }));

  assert.deepEqual(
    generateReviews(createRandom(42), rides, bookings, []),
    generateReviews(createRandom(42), rides, bookings, []),
  );
});

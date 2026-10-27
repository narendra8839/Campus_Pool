const test = require('node:test');
const assert = require('node:assert/strict');
const {
  BookingConflictError,
  cancelBooking,
  respondToBooking,
} = require('../src/services/bookingApprovalService');

function createTestStore(availableSeats, bookings) {
  const ride = {
    id: 'ride-1',
    status: 'SCHEDULED',
    totalSeats: 4,
    availableSeats,
  };
  const bookingById = new Map(
    bookings.map((booking) => [booking.id, { ...booking, rideId: ride.id }]),
  );
  let transactionQueue = Promise.resolve();

  const tx = {
    ride: {
      async updateMany({ where, data }) {
        if (
          where.id !== ride.id ||
          (where.status !== undefined && where.status !== ride.status) ||
          (where.availableSeats?.gte !== undefined &&
            ride.availableSeats < where.availableSeats.gte) ||
          (where.availableSeats?.lte !== undefined &&
            ride.availableSeats > where.availableSeats.lte)
        ) {
          return { count: 0 };
        }
        if (data.availableSeats.decrement !== undefined) {
          ride.availableSeats -= data.availableSeats.decrement;
        } else {
          ride.availableSeats += data.availableSeats.increment;
        }
        return { count: 1 };
      },
      async findUnique({ where }) {
        return where.id === ride.id ? { totalSeats: ride.totalSeats } : null;
      },
    },
    booking: {
      async updateMany({ where, data }) {
        const booking = bookingById.get(where.id);
        if (!booking || booking.status !== where.status) return { count: 0 };
        Object.assign(booking, data);
        return { count: 1 };
      },
      async findUnique({ where }) {
        return bookingById.get(where.id);
      },
    },
  };

  function runTransaction(operation) {
    const transaction = transactionQueue.then(async () => {
      const previousRide = { ...ride };
      const previousBookings = new Map(
        [...bookingById].map(([id, booking]) => [id, { ...booking }]),
      );
      try {
        return await operation(tx);
      } catch (error) {
        Object.assign(ride, previousRide);
        for (const [id, booking] of previousBookings) {
          Object.assign(bookingById.get(id), booking);
        }
        throw error;
      }
    });
    transactionQueue = transaction.catch(() => {});
    return transaction;
  }

  return { ride, bookingById, runTransaction };
}

test('concurrent approvals cannot allocate more seats than are available', async () => {
  const store = createTestStore(1, [
    { id: 'booking-1', status: 'PENDING', seatsRequested: 1 },
    { id: 'booking-2', status: 'PENDING', seatsRequested: 1 },
  ]);

  const results = await Promise.allSettled(
    [...store.bookingById.values()].map((booking) =>
      store.runTransaction((tx) =>
        respondToBooking(tx, booking, 'ACCEPTED'),
      ),
    ),
  );

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  const rejected = results.find((result) => result.status === 'rejected');
  assert.ok(rejected.reason instanceof BookingConflictError);
  assert.equal(store.ride.availableSeats, 0);
  assert.equal(
    [...store.bookingById.values()].filter(
      (booking) => booking.status === 'ACCEPTED',
    ).length,
    1,
  );
  assert.equal(
    [...store.bookingById.values()].filter(
      (booking) => booking.status === 'PENDING',
    ).length,
    1,
  );
});

test('does not allocate seats when a ride is no longer scheduled', async () => {
  const store = createTestStore(2, [
    { id: 'booking-1', status: 'PENDING', seatsRequested: 1 },
  ]);
  store.ride.status = 'CANCELLED';

  await assert.rejects(
    store.runTransaction((tx) =>
      respondToBooking(
        tx,
        store.bookingById.get('booking-1'),
        'ACCEPTED',
      ),
    ),
    BookingConflictError,
  );
  assert.equal(store.ride.availableSeats, 2);
  assert.equal(store.bookingById.get('booking-1').status, 'PENDING');
});

test('rejects duplicate resolution without changing seats', async () => {
  const store = createTestStore(2, [
    { id: 'booking-1', status: 'ACCEPTED', seatsRequested: 1 },
  ]);

  await assert.rejects(
    store.runTransaction((tx) =>
      respondToBooking(
        tx,
        store.bookingById.get('booking-1'),
        'ACCEPTED',
      ),
    ),
    BookingConflictError,
  );
  assert.equal(store.ride.availableSeats, 2);
});

test('concurrent cancellations restore accepted seats only once', async () => {
  const store = createTestStore(1, [
    { id: 'booking-1', status: 'ACCEPTED', seatsRequested: 1 },
  ]);
  const firstRequest = { ...store.bookingById.get('booking-1') };
  const secondRequest = { ...store.bookingById.get('booking-1') };

  const results = await Promise.allSettled([
    store.runTransaction((tx) =>
      cancelBooking(tx, firstRequest),
    ),
    store.runTransaction((tx) =>
      cancelBooking(tx, secondRequest),
    ),
  ]);

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(store.ride.availableSeats, 2);
  assert.equal(store.bookingById.get('booking-1').status, 'CANCELLED');
});

test('concurrent cancellation and approval preserve the ride capacity', async () => {
  const store = createTestStore(1, [
    { id: 'booking-1', status: 'ACCEPTED', seatsRequested: 1 },
    { id: 'booking-2', status: 'PENDING', seatsRequested: 1 },
  ]);
  store.ride.totalSeats = 2;

  const results = await Promise.allSettled([
    store.runTransaction((tx) =>
      cancelBooking(tx, { ...store.bookingById.get('booking-1') }),
    ),
    store.runTransaction((tx) =>
      respondToBooking(
        tx,
        { ...store.bookingById.get('booking-2') },
        'ACCEPTED',
      ),
    ),
  ]);

  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 2);
  assert.equal(store.ride.availableSeats, 1);
  assert.equal(
    [...store.bookingById.values()]
      .filter((booking) => booking.status === 'ACCEPTED')
      .reduce((seats, booking) => seats + booking.seatsRequested, 0),
    1,
  );
  assert.ok(store.ride.availableSeats >= 0);
  assert.ok(store.ride.availableSeats <= store.ride.totalSeats);
});

test('cannot approve a booking when the seat count is already negative', async () => {
  const store = createTestStore(-1, [
    { id: 'booking-1', status: 'PENDING', seatsRequested: 1 },
  ]);

  await assert.rejects(
    store.runTransaction((tx) =>
      respondToBooking(
        tx,
        { ...store.bookingById.get('booking-1') },
        'ACCEPTED',
      ),
    ),
    BookingConflictError,
  );
  assert.equal(store.ride.availableSeats, -1);
  assert.equal(store.bookingById.get('booking-1').status, 'PENDING');
});

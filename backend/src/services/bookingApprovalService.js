class BookingConflictError extends Error {
  constructor(message) {
    super(message);
    this.name = 'BookingConflictError';
    this.statusCode = 409;
  }
}

function findBookingResponse(tx, bookingId) {
  return tx.booking.findUnique({
    where: { id: bookingId },
    include: {
      passenger: {
        select: {
          id: true,
          name: true,
          phone: true,
          avatar: true,
          gender: true,
          ratingAvg: true,
          ratingCount: true,
          isVerified: true,
          college: true,
          rollNumber: true,
          emergencyPhone: true,
        },
      },
      ride: true,
    },
  });
}

async function approveBooking(tx, booking, driverResponseNote) {
  const acceptance = await tx.booking.updateMany({
    where: { id: booking.id, status: 'PENDING' },
    data: {
      status: 'ACCEPTED',
      driverResponseNote: driverResponseNote || booking.driverResponseNote,
    },
  });

  if (acceptance.count !== 1) {
    throw new BookingConflictError(
      'This booking has already been handled.',
    );
  }

  const allocation = await tx.ride.updateMany({
    where: {
      id: booking.rideId,
      status: 'SCHEDULED',
      availableSeats: { gte: booking.seatsRequested },
    },
    data: {
      availableSeats: { decrement: booking.seatsRequested },
    },
  });

  if (allocation.count !== 1) {
    throw new BookingConflictError(
      'Not enough seats remain to accept this request.',
    );
  }

  return findBookingResponse(tx, booking.id);
}

async function rejectBooking(tx, booking, driverResponseNote) {
  const rejection = await tx.booking.updateMany({
    where: { id: booking.id, status: 'PENDING' },
    data: {
      status: 'REJECTED',
      driverResponseNote: driverResponseNote || booking.driverResponseNote,
    },
  });

  if (rejection.count !== 1) {
    throw new BookingConflictError(
      'This booking has already been handled.',
    );
  }

  return findBookingResponse(tx, booking.id);
}

async function cancelBooking(tx, booking) {
  const cancellation = await tx.booking.updateMany({
    where: { id: booking.id, status: booking.status },
    data: { status: 'CANCELLED' },
  });

  if (cancellation.count !== 1) {
    throw new BookingConflictError(
      'This booking has already been handled.',
    );
  }

  if (booking.status === 'ACCEPTED') {
    const ride = await tx.ride.findUnique({
      where: { id: booking.rideId },
      select: { totalSeats: true },
    });

    const restoration = ride
      ? await tx.ride.updateMany({
          where: {
            id: booking.rideId,
            availableSeats: {
              lte: ride.totalSeats - booking.seatsRequested,
            },
          },
          data: {
            availableSeats: { increment: booking.seatsRequested },
          },
        })
      : { count: 0 };

    if (restoration.count !== 1) {
      throw new BookingConflictError(
        'Ride capacity changed; the booking could not be cancelled.',
      );
    }
  }

  return findBookingResponse(tx, booking.id);
}

async function respondToBooking(tx, booking, status, driverResponseNote) {
  if (status === 'ACCEPTED') {
    return approveBooking(tx, booking, driverResponseNote);
  }
  return rejectBooking(tx, booking, driverResponseNote);
}

module.exports = { BookingConflictError, cancelBooking, respondToBooking };

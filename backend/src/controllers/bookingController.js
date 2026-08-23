const prisma = require('../config/prisma');

// @desc    Request a lift / book a seat
// @route   POST /api/bookings
// @access  Private
const createBooking = async (req, res, next) => {
  try {
    const {
      rideId,
      pickupName,
      pickupLat,
      pickupLng,
      dropName,
      dropLat,
      dropLng,
      seatsRequested = 1,
      passengerNote,
    } = req.body;

    if (!rideId || !pickupName || !dropName) {
      return res.status(400).json({
        success: false,
        message: 'Please provide rideId, pickupName, and dropName',
      });
    }

    const ride = await prisma.ride.findUnique({
      where: { id: rideId },
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Ride not found',
      });
    }

    if (ride.status !== 'SCHEDULED') {
      return res.status(400).json({
        success: false,
        message: `Cannot book a ride that is ${ride.status.toLowerCase()}`,
      });
    }

    // Driver cannot book their own ride
    if (ride.driverId === req.user.id) {
      return res.status(400).json({
        success: false,
        message: 'You cannot request a lift on your own ride',
      });
    }

    const requestedSeats = parseInt(seatsRequested, 10) || 1;

    // Check available seats
    if (ride.availableSeats < requestedSeats) {
      return res.status(400).json({
        success: false,
        message: `Only ${ride.availableSeats} seat(s) available`,
      });
    }

    // Check existing active booking
    const existingBooking = await prisma.booking.findFirst({
      where: {
        rideId,
        passengerId: req.user.id,
        status: { in: ['PENDING', 'ACCEPTED'] },
      },
    });

    if (existingBooking) {
      return res.status(400).json({
        success: false,
        message: 'You already have an active request or booking for this ride',
      });
    }

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const fare = (ride.contribution || 0) * requestedSeats;

    const booking = await prisma.booking.create({
      data: {
        rideId,
        passengerId: req.user.id,
        pickupName,
        pickupLat: parseFloat(pickupLat) || 0.0,
        pickupLng: parseFloat(pickupLng) || 0.0,
        dropName,
        dropLat: parseFloat(dropLat) || 0.0,
        dropLng: parseFloat(dropLng) || 0.0,
        seatsRequested: requestedSeats,
        passengerNote: passengerNote || '',
        fareAmount: fare,
        verificationOtp: otp,
      },
      include: {
        passenger: {
          select: {
            id: true,
            name: true,
            phone: true,
            avatar: true,
            rollNumber: true,
            college: true,
            ratingAvg: true,
          },
        },
        ride: true,
      },
    });

    res.status(201).json({
      success: true,
      message: 'Lift request sent successfully to the driver',
      data: booking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Driver responds to a booking request (ACCEPT or REJECT)
// @route   PATCH /api/bookings/:id/respond
// @access  Private
const respondToBooking = async (req, res, next) => {
  try {
    const { status, driverResponseNote } = req.body;

    if (!['ACCEPTED', 'REJECTED'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Status must be either ACCEPTED or REJECTED',
      });
    }

    const booking = await prisma.booking.findUnique({
      where: { id: req.params.id },
      include: { ride: true },
    });

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking request not found',
      });
    }

    // Verify current user is the driver of the ride
    if (booking.ride.driverId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to respond to this booking request',
      });
    }

    if (booking.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: `This booking has already been ${booking.status.toLowerCase()}`,
      });
    }

    const updatedBooking = await prisma.$transaction(async (tx) => {
      if (status === 'ACCEPTED') {
        const currentRide = await tx.ride.findUnique({
          where: { id: booking.rideId },
        });

        if (currentRide.availableSeats < booking.seatsRequested) {
          throw new Error('Not enough seats available to accept this request');
        }

        await tx.ride.update({
          where: { id: booking.rideId },
          data: {
            availableSeats: currentRide.availableSeats - booking.seatsRequested,
          },
        });
      }

      return await tx.booking.update({
        where: { id: req.params.id },
        data: {
          status,
          driverResponseNote: driverResponseNote || booking.driverResponseNote,
        },
        include: {
          passenger: {
            select: { id: true, name: true, phone: true, avatar: true },
          },
          ride: true,
        },
      });
    });

    res.json({
      success: true,
      message: `Booking request ${status.toLowerCase()} successfully`,
      data: updatedBooking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Cancel a booking (by passenger or driver)
// @route   PATCH /api/bookings/:id/cancel
// @access  Private
const cancelBooking = async (req, res, next) => {
  try {
    const booking = await prisma.booking.findUnique({
      where: { id: req.params.id },
      include: { ride: true },
    });

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }

    const isPassenger = booking.passengerId === req.user.id;
    const isDriver = booking.ride.driverId === req.user.id;

    if (!isPassenger && !isDriver) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to cancel this booking',
      });
    }

    if (['CANCELLED', 'COMPLETED'].includes(booking.status)) {
      return res.status(400).json({
        success: false,
        message: `Booking is already ${booking.status.toLowerCase()}`,
      });
    }

    const cancelledBooking = await prisma.$transaction(async (tx) => {
      if (booking.status === 'ACCEPTED') {
        const currentRide = await tx.ride.findUnique({
          where: { id: booking.rideId },
        });
        if (currentRide) {
          const restoredSeats = Math.min(
            currentRide.totalSeats,
            currentRide.availableSeats + booking.seatsRequested
          );
          await tx.ride.update({
            where: { id: booking.rideId },
            data: { availableSeats: restoredSeats },
          });
        }
      }

      return await tx.booking.update({
        where: { id: req.params.id },
        data: { status: 'CANCELLED' },
      });
    });

    res.json({
      success: true,
      message: 'Booking cancelled successfully',
      data: cancelledBooking,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get passenger's bookings
// @route   GET /api/bookings/my-bookings
// @access  Private
const getMyBookings = async (req, res, next) => {
  try {
    const bookings = await prisma.booking.findMany({
      where: { passengerId: req.user.id },
      include: {
        ride: {
          include: {
            driver: {
              select: {
                id: true,
                name: true,
                phone: true,
                ratingAvg: true,
                avatar: true,
                college: true,
                vehicleType: true,
                vehicleModel: true,
                vehiclePlate: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      count: bookings.length,
      data: bookings,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get bookings for a specific ride (for the driver)
// @route   GET /api/bookings/ride/:rideId
// @access  Private
const getRideBookings = async (req, res, next) => {
  try {
    const ride = await prisma.ride.findUnique({
      where: { id: req.params.rideId },
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Ride not found',
      });
    }

    if (ride.driverId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view bookings for this ride',
      });
    }

    const bookings = await prisma.booking.findMany({
      where: { rideId: req.params.rideId },
      include: {
        passenger: {
          select: {
            id: true,
            name: true,
            phone: true,
            ratingAvg: true,
            avatar: true,
            college: true,
            rollNumber: true,
            emergencyPhone: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      count: bookings.length,
      data: bookings,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createBooking,
  respondToBooking,
  cancelBooking,
  getMyBookings,
  getRideBookings,
};

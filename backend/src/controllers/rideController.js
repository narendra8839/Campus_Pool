const prisma = require('../config/prisma');

// @desc    Create / Offer a new ride
// @route   POST /api/rides
// @access  Private
const createRide = async (req, res, next) => {
  try {
    const {
      originName,
      originAddress,
      originLat,
      originLng,
      destName,
      destAddress,
      destLat,
      destLng,
      waypoints,
      departureTime,
      totalSeats,
      vehicleType,
      helmetProvided,
      contribution,
      notes,
    } = req.body;

    if (!originName || !destName || !departureTime) {
      return res.status(400).json({
        success: false,
        message: 'Please provide originName, destName, and departureTime',
      });
    }

    const depDate = new Date(departureTime);
    if (isNaN(depDate.getTime()) || depDate < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Departure time must be a valid future date and time',
      });
    }

    const seats = parseInt(totalSeats, 10) || (vehicleType === 'car' ? 3 : 1);

    const ride = await prisma.ride.create({
      data: {
        driverId: req.user.id,
        originName,
        originAddress: originAddress || '',
        originLat: parseFloat(originLat) || 0.0,
        originLng: parseFloat(originLng) || 0.0,
        destName,
        destAddress: destAddress || '',
        destLat: parseFloat(destLat) || 0.0,
        destLng: parseFloat(destLng) || 0.0,
        waypoints: waypoints || [],
        departureTime: depDate,
        totalSeats: seats,
        availableSeats: seats,
        vehicleType: vehicleType || req.user.vehicleType || 'bike',
        helmetProvided: helmetProvided !== undefined ? helmetProvided : req.user.helmetProvided ?? true,
        contribution: parseFloat(contribution) || 0.0,
        notes: notes || '',
      },
      include: {
        driver: {
          select: {
            id: true,
            name: true,
            phone: true,
            ratingAvg: true,
            ratingCount: true,
            avatar: true,
            college: true,
            rollNumber: true,
            vehicleType: true,
            vehicleModel: true,
            vehiclePlate: true,
          },
        },
      },
    });

    res.status(201).json({
      success: true,
      message: 'Ride offered successfully',
      data: ride,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Search available rides
// @route   GET /api/rides
// @access  Public
const searchRides = async (req, res, next) => {
  try {
    const {
      from,
      to,
      date,
      vehicleType,
      seats = 1,
      page = 1,
      limit = 20,
    } = req.query;

    const where = {
      status: 'SCHEDULED',
      departureTime: { gte: new Date() },
      availableSeats: { gte: parseInt(seats, 10) },
    };

    if (from) {
      where.originName = { contains: from, mode: 'insensitive' };
    }

    if (to) {
      where.destName = { contains: to, mode: 'insensitive' };
    }

    if (vehicleType) {
      where.vehicleType = vehicleType;
    }

    if (date) {
      const searchDate = new Date(date);
      const startOfDay = new Date(searchDate.setHours(0, 0, 0, 0));
      const endOfDay = new Date(searchDate.setHours(23, 59, 59, 999));
      where.departureTime = { gte: startOfDay, lte: endOfDay };
    }

    const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);
    const take = parseInt(limit, 10);

    const [rides, total] = await Promise.all([
      prisma.ride.findMany({
        where,
        include: {
          driver: {
            select: {
              id: true,
              name: true,
              phone: true,
              ratingAvg: true,
              ratingCount: true,
              avatar: true,
              college: true,
              rollNumber: true,
              vehicleType: true,
              vehicleModel: true,
            },
          },
        },
        orderBy: { departureTime: 'asc' },
        skip,
        take,
      }),
      prisma.ride.count({ where }),
    ]);

    res.json({
      success: true,
      count: rides.length,
      total,
      page: parseInt(page, 10),
      pages: Math.ceil(total / take),
      data: rides,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get ride details by ID
// @route   GET /api/rides/:id
// @access  Private
const getRideById = async (req, res, next) => {
  try {
    const ride = await prisma.ride.findUnique({
      where: { id: req.params.id },
      include: {
        driver: {
          select: {
            id: true,
            name: true,
            phone: true,
            ratingAvg: true,
            ratingCount: true,
            avatar: true,
            college: true,
            rollNumber: true,
            vehicleType: true,
            vehicleModel: true,
            vehiclePlate: true,
            emergencyPhone: true,
          },
        },
        bookings: {
          where: { status: 'ACCEPTED' },
          include: {
            passenger: {
              select: {
                id: true,
                name: true,
                phone: true,
                avatar: true,
                ratingAvg: true,
                rollNumber: true,
              },
            },
          },
        },
      },
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Ride not found',
      });
    }

    res.json({
      success: true,
      data: ride,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get rides created by current logged-in driver
// @route   GET /api/rides/my-rides
// @access  Private
const getMyOfferedRides = async (req, res, next) => {
  try {
    const rides = await prisma.ride.findMany({
      where: { driverId: req.user.id },
      include: {
        bookings: {
          include: {
            passenger: {
              select: { id: true, name: true, phone: true, avatar: true },
            },
          },
        },
      },
      orderBy: { departureTime: 'desc' },
    });

    res.json({
      success: true,
      count: rides.length,
      data: rides,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update ride status (ONGOING, COMPLETED, CANCELLED)
// @route   PATCH /api/rides/:id/status
// @access  Private
const updateRideStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const allowedStatuses = ['SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED'];

    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Allowed statuses: ${allowedStatuses.join(', ')}`,
      });
    }

    const ride = await prisma.ride.findUnique({
      where: { id: req.params.id },
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
        message: 'Not authorized to update this ride',
      });
    }

    // Atomic update of ride and associated bookings
    const result = await prisma.$transaction(async (tx) => {
      const updatedRide = await tx.ride.update({
        where: { id: req.params.id },
        data: { status },
      });

      if (status === 'COMPLETED') {
        await tx.booking.updateMany({
          where: { rideId: ride.id, status: 'ACCEPTED' },
          data: { status: 'COMPLETED' },
        });
      } else if (status === 'CANCELLED') {
        await tx.booking.updateMany({
          where: { rideId: ride.id, status: { in: ['PENDING', 'ACCEPTED'] } },
          data: { status: 'CANCELLED' },
        });
      }

      return updatedRide;
    });

    res.json({
      success: true,
      message: `Ride status updated to ${status}`,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Cancel a ride
// @route   DELETE /api/rides/:id
// @access  Private
const cancelRide = async (req, res, next) => {
  try {
    const ride = await prisma.ride.findUnique({
      where: { id: req.params.id },
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
        message: 'Not authorized to cancel this ride',
      });
    }

    const updatedRide = await prisma.$transaction(async (tx) => {
      const cancelled = await tx.ride.update({
        where: { id: req.params.id },
        data: { status: 'CANCELLED' },
      });

      await tx.booking.updateMany({
        where: { rideId: ride.id, status: { in: ['PENDING', 'ACCEPTED'] } },
        data: { status: 'CANCELLED' },
      });

      return cancelled;
    });

    res.json({
      success: true,
      message: 'Ride cancelled successfully',
      data: updatedRide,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createRide,
  searchRides,
  getRideById,
  getMyOfferedRides,
  updateRideStatus,
  cancelRide,
};

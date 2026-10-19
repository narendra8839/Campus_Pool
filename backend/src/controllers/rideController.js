const prisma = require('../config/prisma');
const { priceRide } = require('../services/ridePricingService');
const { RoutingError } = require('../services/osrmService');
const { rankRides } = require('../services/ncfService');

const routeInclude = {
  corridor: {
    include: {
      hubs: { orderBy: { sequence: 'asc' }, include: { hub: true } },
    },
  },
  originHub: true,
  destinationHub: true,
};

const RIDE_GENDER_PREFERENCES = new Set(['any', 'male', 'female', 'other']);

// @desc    Create / Offer a new ride
// @route   POST /api/rides
// @access  Private
const createRide = async (req, res, next) => {
  try {
    let {
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
      passengerGenderPreference = 'any',
      notes,
      viaPoints = [],
      selectedRouteIndex = 0,
      corridorId,
      originHubId,
      destinationHubId,
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

    const normalizedVehicleType = String(vehicleType || req.user.vehicleType || 'bike').toLowerCase();
    if (!['bike', 'scooty'].includes(normalizedVehicleType)) {
      return res.status(400).json({
        success: false,
        message: 'Only bike and scooty vehicles are supported',
      });
    }

    const normalizedPassengerGenderPreference = String(
      passengerGenderPreference,
    ).toLowerCase();
    if (!RIDE_GENDER_PREFERENCES.has(normalizedPassengerGenderPreference)) {
      return res.status(400).json({
        success: false,
        message: 'passengerGenderPreference must be any, male, female, or other',
      });
    }

    const seats = parseInt(totalSeats, 10);
    if (!Number.isInteger(seats) || seats < 1) {
      return res.status(400).json({
        success: false,
        message: 'Capacity must be a whole number of at least 1 seat',
      });
    }

    let routeLinks = {};
    if (corridorId || originHubId || destinationHubId) {
      if (!corridorId || !originHubId || !destinationHubId) {
        return res.status(400).json({ success: false, message: 'corridorId, originHubId, and destinationHubId must be provided together' });
      }
      const [corridor, originLink, destinationLink] = await Promise.all([
        prisma.corridor.findUnique({
          where: { id: corridorId },
          include: {
            hubs: {
              orderBy: { sequence: 'asc' },
              include: { hub: true },
            },
          },
        }),
        prisma.corridorHub.findUnique({
          where: { corridorId_hubId: { corridorId, hubId: originHubId } },
          include: { hub: true },
        }),
        prisma.corridorHub.findUnique({
          where: { corridorId_hubId: { corridorId, hubId: destinationHubId } },
          include: { hub: true },
        }),
      ]);
      if (!corridor || !originLink || !destinationLink) {
        return res.status(400).json({ success: false, message: 'The selected corridor and hubs must exist' });
      }
      if (originLink.sequence === destinationLink.sequence) {
        return res.status(400).json({ success: false, message: 'Hubs must follow corridor order for the ride direction' });
      }
      routeLinks = { corridorId, originHubId, destinationHubId };
      originName = originLink.hub.name;
      destName = destinationLink.hub.name;
      originLat = originLink.hub.latitude;
      originLng = originLink.hub.longitude;
      destLat = destinationLink.hub.latitude;
      destLng = destinationLink.hub.longitude;
      if (!Array.isArray(waypoints) || waypoints.length < 2) {
        waypoints = corridor.hubs
          .filter(({ sequence }) => sequence >= Math.min(originLink.sequence, destinationLink.sequence)
            && sequence <= Math.max(originLink.sequence, destinationLink.sequence))
          .map(({ hub }) => ({
          latitude: hub.latitude,
          longitude: hub.longitude,
          }));
      }
    }

    const parseCoordinate = (value) => {
      if (typeof value === 'number') return value;
      if (typeof value === 'string' && value.trim() !== '') return Number(value);
      return Number.NaN;
    };
    const parsedOriginLat = parseCoordinate(originLat);
    const parsedOriginLng = parseCoordinate(originLng);
    const parsedDestinationLat = parseCoordinate(destLat);
    const parsedDestinationLng = parseCoordinate(destLng);
    const coordinatesAreValid =
      Number.isFinite(parsedOriginLat) &&
      parsedOriginLat >= -90 &&
      parsedOriginLat <= 90 &&
      Number.isFinite(parsedDestinationLat) &&
      parsedDestinationLat >= -90 &&
      parsedDestinationLat <= 90 &&
      Number.isFinite(parsedOriginLng) &&
      parsedOriginLng >= -180 &&
      parsedOriginLng <= 180 &&
      Number.isFinite(parsedDestinationLng) &&
      parsedDestinationLng >= -180 &&
      parsedDestinationLng <= 180;
    if (
      !coordinatesAreValid ||
      (parsedOriginLat === 0 &&
        parsedOriginLng === 0 &&
        parsedDestinationLat === 0 &&
        parsedDestinationLng === 0)
    ) {
      return res.status(400).json({
        success: false,
        message: 'Valid start and destination coordinates are required.',
      });
    }
    if (
      parsedOriginLat === parsedDestinationLat &&
      parsedOriginLng === parsedDestinationLng
    ) {
      return res.status(400).json({
        success: false,
        message: 'Start and destination must be different locations.',
      });
    }

    if (!Array.isArray(viaPoints) || viaPoints.length > 1) {
      return res.status(400).json({
        success: false,
        message: 'At most one valid route via point may be provided.',
      });
    }
    const parsedViaPoints = viaPoints.map((point) => ({
      latitude: parseCoordinate(point?.latitude),
      longitude: parseCoordinate(point?.longitude),
    }));
    if (
      parsedViaPoints.some(
        ({ latitude, longitude }) =>
          !Number.isFinite(latitude) ||
          latitude < -90 ||
          latitude > 90 ||
          !Number.isFinite(longitude) ||
          longitude < -180 ||
          longitude > 180,
      )
    ) {
      return res.status(400).json({
        success: false,
        message: 'The route via point must have valid coordinates.',
      });
    }

    const parsedRouteIndex = Number(selectedRouteIndex);
    if (
      !Number.isInteger(parsedRouteIndex) ||
      parsedRouteIndex < 0 ||
      parsedRouteIndex > 2
    ) {
      return res.status(400).json({
        success: false,
        message: 'selectedRouteIndex must be 0, 1, or 2.',
      });
    }

    const pricing = await priceRide({
      origin: { latitude: parsedOriginLat, longitude: parsedOriginLng },
      destination: {
        latitude: parsedDestinationLat,
        longitude: parsedDestinationLng,
      },
      viaPoints: parsedViaPoints,
      selectedRouteIndex: parsedRouteIndex,
      waypoints,
    });

    const ride = await prisma.ride.create({
      data: {
        driverId: req.user.id,
        ...routeLinks,
        originName,
        originAddress: originAddress || '',
        originLat: parsedOriginLat,
        originLng: parsedOriginLng,
        destName,
        destAddress: destAddress || '',
        destLat: parsedDestinationLat,
        destLng: parsedDestinationLng,
        waypoints: pricing.waypoints,
        departureTime: depDate,
        totalSeats: seats,
        availableSeats: seats,
        vehicleType: normalizedVehicleType,
        helmetProvided: helmetProvided !== undefined ? helmetProvided : req.user.helmetProvided ?? true,
        contribution: pricing.contribution,
        passengerGenderPreference: normalizedPassengerGenderPreference,
        notes: notes || '',
      },
      include: {
        ...routeInclude,
        driver: {
          select: {
            id: true,
            name: true,
            phone: true,
            ratingAvg: true,
            ratingCount: true,
            gender: true,
            isVerified: true,
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
    if (error instanceof RoutingError) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
    }
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
      driverGender,
      seats = 1,
      page = 1,
      limit = 20,
      corridorId,
      originHubId,
      destinationHubId,
    } = req.query;

    const where = {
      status: 'SCHEDULED',
      departureTime: { gte: new Date() },
      availableSeats: { gte: parseInt(seats, 10) },
      driverId: { not: req.user.id },
    };

    const seekerGender = req.user.gender?.toLowerCase();
    where.OR = [{ passengerGenderPreference: 'any' }];
    if (RIDE_GENDER_PREFERENCES.has(seekerGender)) {
      where.OR.push({ passengerGenderPreference: seekerGender });
    }

    const normalizedDriverGender = String(driverGender || '').toLowerCase();
    if (normalizedDriverGender && normalizedDriverGender !== 'any') {
      if (!RIDE_GENDER_PREFERENCES.has(normalizedDriverGender)) {
        return res.status(400).json({
          success: false,
          message: 'driverGender must be any, male, female, or other',
        });
      }
      where.driver = { is: { gender: normalizedDriverGender } };
    }

    if (from) {
      where.originName = { contains: from, mode: 'insensitive' };
    }

    if (to) {
      where.destName = { contains: to, mode: 'insensitive' };
    }

    if (vehicleType) {
      const normalizedVehicleType = String(vehicleType).toLowerCase();
      if (!['bike', 'scooty'].includes(normalizedVehicleType)) {
        return res.json({ success: true, count: 0, total: 0, page: parseInt(page, 10), pages: 0, data: [] });
      }
      where.vehicleType = normalizedVehicleType;
    } else {
      where.vehicleType = { in: ['bike', 'scooty'] };
    }

    if (corridorId) {
      where.corridorId = corridorId;
    }
    if (originHubId) {
      where.originHubId = originHubId;
    }
    if (destinationHubId) {
      where.destinationHubId = destinationHubId;
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
          ...routeInclude,
          driver: {
            select: {
              id: true,
              name: true,
              phone: true,
              avatar: true,
              college: true,
              rollNumber: true,
              gender: true,
              ratingAvg: true,
              ratingCount: true,
              isVerified: true,
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

    const rankedRides = rankRides(req.user?.id, rides);
    res.json({
      success: true,
      count: rankedRides.length,
      total,
      page: parseInt(page, 10),
      pages: Math.ceil(total / take),
      data: rankedRides,
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
        ...routeInclude,
        driver: {
          select: {
            id: true,
            name: true,
            phone: true,
            ratingAvg: true,
            ratingCount: true,
            gender: true,
            isVerified: true,
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
                gender: true,
                ratingCount: true,
                isVerified: true,
                college: true,
                emergencyPhone: true,
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
        ...routeInclude,
        bookings: {
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

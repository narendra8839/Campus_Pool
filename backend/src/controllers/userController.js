const prisma = require('../config/prisma');

// @desc    Get user profile by ID
// @route   GET /api/users/:id
// @access  Private
const getUserProfile = async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        college: true,
        rollNumber: true,
        gender: true,
        avatar: true,
        roles: true,
        vehicleType: true,
        vehicleModel: true,
        vehiclePlate: true,
        vehicleColor: true,
        helmetProvided: true,
        vehicleSeats: true,
        ratingAvg: true,
        ratingCount: true,
        isVerified: true,
        createdAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    const reviews = await prisma.review.findMany({
      where: { revieweeId: req.params.id },
      include: {
        reviewer: {
          select: { id: true, name: true, avatar: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    res.json({
      success: true,
      data: {
        user,
        reviews,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update personal user profile
// @route   PUT /api/users/profile
// @access  Private
const updateProfile = async (req, res, next) => {
  try {
    const {
      name,
      phone,
      college,
      rollNumber,
      gender,
      avatar,
      emergencyName,
      emergencyPhone,
      emergencyRelation,
    } = req.body;

    const dataToUpdate = {};
    if (name !== undefined) dataToUpdate.name = name;
    if (phone !== undefined) dataToUpdate.phone = phone;
    if (college !== undefined) dataToUpdate.college = college;
    if (rollNumber !== undefined) dataToUpdate.rollNumber = rollNumber;
    if (gender !== undefined) dataToUpdate.gender = gender;
    if (avatar !== undefined) dataToUpdate.avatar = avatar;
    if (emergencyName !== undefined) dataToUpdate.emergencyName = emergencyName;
    if (emergencyPhone !== undefined) dataToUpdate.emergencyPhone = emergencyPhone;
    if (emergencyRelation !== undefined) dataToUpdate.emergencyRelation = emergencyRelation;

    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: dataToUpdate,
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        college: true,
        rollNumber: true,
        gender: true,
        avatar: true,
        roles: true,
        emergencyName: true,
        emergencyPhone: true,
        emergencyRelation: true,
        ratingAvg: true,
        ratingCount: true,
      },
    });

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedUser,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update vehicle details
// @route   PUT /api/users/vehicle
// @access  Private
const updateVehicle = async (req, res, next) => {
  try {
    const { type, model, plateNumber, color, helmetProvided, totalSeats } = req.body;

    const dataToUpdate = {};
    if (type !== undefined) {
      const normalizedType = String(type).toLowerCase();
      if (!['bike', 'scooty'].includes(normalizedType)) {
        return res.status(400).json({
          success: false,
          message: 'Only bike and scooty vehicles are supported',
        });
      }
      dataToUpdate.vehicleType = normalizedType;
    }
    if (model !== undefined) dataToUpdate.vehicleModel = model;
    if (plateNumber !== undefined) dataToUpdate.vehiclePlate = plateNumber;
    if (color !== undefined) dataToUpdate.vehicleColor = color;
    if (helmetProvided !== undefined) dataToUpdate.helmetProvided = helmetProvided;
    if (totalSeats !== undefined) dataToUpdate.vehicleSeats = parseInt(totalSeats, 10);

    const updatedUser = await prisma.user.update({
      where: { id: req.user.id },
      data: dataToUpdate,
      select: {
        id: true,
        vehicleType: true,
        vehicleModel: true,
        vehiclePlate: true,
        vehicleColor: true,
        helmetProvided: true,
        vehicleSeats: true,
      },
    });

    res.json({
      success: true,
      message: 'Vehicle information updated successfully',
      data: updatedUser,
    });
  } catch (error) {
    next(error);
  }
};

const getMySchedule = async (req, res, next) => {
  try {
    const schedules = await prisma.studentSchedule.findMany({
      where: { userId: req.user.id },
      orderBy: { dayOfWeek: 'asc' },
    });
    res.json({ success: true, data: schedules });
  } catch (error) {
    next(error);
  }
};

const updateMySchedule = async (req, res, next) => {
  try {
    if (!Array.isArray(req.body.schedules)) {
      return res.status(400).json({ success: false, message: 'schedules must be an array' });
    }
    const schedules = req.body.schedules.map((item) => ({
      dayOfWeek: Number(item.dayOfWeek),
      dayName: String(item.dayName || ''),
      hasClass: Boolean(item.hasClass),
      collegeStartTime: item.hasClass ? String(item.collegeStartTime || '') : null,
      collegeEndTime: item.hasClass ? String(item.collegeEndTime || '') : null,
      campusName: String(item.campusName || 'VIT College'),
    }));
    if (schedules.length !== 6 || schedules.some((item) => item.dayOfWeek < 1 || item.dayOfWeek > 6)) {
      return res.status(400).json({ success: false, message: 'Provide exactly one valid schedule for Monday through Saturday' });
    }
    await prisma.$transaction(async (tx) => {
      await tx.studentSchedule.deleteMany({ where: { userId: req.user.id } });
      await tx.studentSchedule.createMany({ data: schedules.map((item) => ({ ...item, userId: req.user.id })) });
    });
    const saved = await prisma.studentSchedule.findMany({ where: { userId: req.user.id }, orderBy: { dayOfWeek: 'asc' } });
    res.json({ success: true, data: saved });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getUserProfile,
  updateProfile,
  updateVehicle,
  getMySchedule,
  updateMySchedule,
};

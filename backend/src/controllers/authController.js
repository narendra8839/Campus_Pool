const prisma = require('../config/prisma');
const { validateFirebaseIdentity } = require('../utils/firebaseIdentity');

const PROFILE_SELECT = {
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
  emergencyName: true,
  emergencyPhone: true,
  emergencyRelation: true,
  ratingAvg: true,
  ratingCount: true,
  isVerified: true,
  createdAt: true,
};

const VALID_GENDERS = new Set([
  'prefer_not_to_say',
  'male',
  'female',
  'other',
]);

function optionalText(value, field, maximumLength) {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string' || value.trim().length > maximumLength) {
    const error = new Error(`${field} must be a string with at most ${maximumLength} characters.`);
    error.statusCode = 400;
    throw error;
  }
  return value.trim();
}

async function provisionFirebaseProfile(req, res, next) {
  try {
    const identity = req.firebaseIdentity;
    const validation = validateFirebaseIdentity(identity);
    if (!validation.valid) {
      return res.status(403).json({ success: false, message: validation.message });
    }

    const existingByUid = await prisma.user.findUnique({
      where: { firebaseUid: identity.uid },
      select: PROFILE_SELECT,
    });
    if (existingByUid) {
      if (existingByUid.email.toLowerCase() !== validation.email) {
        return res.status(409).json({
          success: false,
          message: 'Your verified email changed. Contact support to update your account safely.',
        });
      }
      return res.json({ success: true, data: existingByUid });
    }

    const existingByEmail = await prisma.user.findUnique({
      where: { email: validation.email },
      select: { id: true },
    });
    if (existingByEmail) {
      return res.status(409).json({
        success: false,
        message: 'This email is already attached to an existing account. Contact support; accounts are not automatically linked.',
      });
    }

    const name = optionalText(
      req.body.name ?? identity.name ?? validation.email.split('@')[0],
      'name',
      100,
    );
    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'A name is required to create your student profile.',
      });
    }
    const phone = optionalText(req.body.phone, 'phone', 32);
    const college = optionalText(req.body.college ?? 'VIT Pune', 'college', 120);
    const rollNumber = optionalText(req.body.rollNumber, 'rollNumber', 64);
    const requestedGender = req.body.gender ?? 'prefer_not_to_say';
    const gender = typeof requestedGender === 'string'
      ? requestedGender.trim().toLowerCase()
      : '';
    if (!VALID_GENDERS.has(gender)) {
      return res.status(400).json({
        success: false,
        message: 'gender must be prefer_not_to_say, male, female, or other.',
      });
    }

    const user = await prisma.user.create({
      data: {
        firebaseUid: identity.uid,
        name,
        email: validation.email,
        password: null,
        phone,
        college,
        rollNumber,
        gender,
        avatar: typeof identity.picture === 'string' ? identity.picture : '',
        roles: ['rider', 'driver'],
        isVerified: true,
      },
      select: PROFILE_SELECT,
    });
    return res.status(201).json({
      success: true,
      message: 'Verified student profile created.',
      data: user,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
    }
    if (error.code === 'P2002') {
      return res.status(409).json({
        success: false,
        message: 'An account already exists for this email or Firebase identity.',
      });
    }
    return next(error);
  }
}

// @desc    Get current logged in user details
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res, next) => {
  try {
    const [user, ratingSummary] = await Promise.all([
      prisma.user.findUnique({
        where: { id: req.user.id },
        select: PROFILE_SELECT,
      }),
      prisma.review.aggregate({
        where: { revieweeId: req.user.id },
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);

    res.json({
      success: true,
      data: user
        ? {
            ...user,
            ratingAvg: ratingSummary._avg.rating ?? 5,
            ratingCount: ratingSummary._count.rating,
          }
        : null,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getMe, provisionFirebaseProfile };

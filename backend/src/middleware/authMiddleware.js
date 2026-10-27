const prisma = require('../config/prisma');
const { getFirebaseAdminAuth } = require('../services/firebaseAdminService');
const { validateFirebaseIdentity } = require('../utils/firebaseIdentity');

const INVALID_FIREBASE_TOKEN_CODES = new Set([
  'auth/argument-error',
  'auth/id-token-expired',
  'auth/id-token-revoked',
  'auth/invalid-id-token',
  'auth/user-disabled',
]);

const verifyFirebaseToken = async (req, res, next) => {
  const authorization = req.headers.authorization || '';
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized, no valid bearer token provided.',
    });
  }

  let decoded;
  try {
    decoded = await getFirebaseAdminAuth().verifyIdToken(tokenMatch[1], true);
  } catch (error) {
    if (INVALID_FIREBASE_TOKEN_CODES.has(error.code)) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized, invalid or expired Firebase token.',
      });
    }
    return next(error);
  }

  const validation = validateFirebaseIdentity(decoded);
  if (!validation.valid) {
    return res.status(403).json({ success: false, message: validation.message });
  }
  req.firebaseIdentity = { ...decoded, email: validation.email };
  return next();
};

const protect = async (req, res, next) => {
  verifyFirebaseToken(req, res, async (error) => {
    if (error) return next(error);
    if (res.headersSent) return undefined;

    try {
      const user = await prisma.user.findUnique({
        where: { firebaseUid: req.firebaseIdentity.uid },
      });
      if (!user) {
        return res.status(403).json({
          success: false,
          message: 'Complete your verified student account setup first.',
        });
      }
      const { password, firebaseUid, ...userWithoutPassword } = user;
      req.user = userWithoutPassword;
      return next();
    } catch (dbError) {
      return next(dbError);
    }
  });
};

module.exports = { protect, verifyFirebaseToken };

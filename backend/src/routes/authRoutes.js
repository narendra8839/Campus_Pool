const express = require('express');
const router = express.Router();
const { getMe, provisionFirebaseProfile } = require('../controllers/authController');
const { protect, verifyFirebaseToken } = require('../middleware/authMiddleware');

router.post('/profile', verifyFirebaseToken, provisionFirebaseProfile);
router.get('/me', protect, getMe);

module.exports = router;

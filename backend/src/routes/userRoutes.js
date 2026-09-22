const express = require('express');
const router = express.Router();
const {
  getUserProfile,
  updateProfile,
  updateVehicle,
  getMySchedule,
  updateMySchedule,
} = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');

router.get('/:id', protect, getUserProfile);
router.put('/profile', protect, updateProfile);
router.put('/vehicle', protect, updateVehicle);
router.get('/me/schedule', protect, getMySchedule);
router.put('/me/schedule', protect, updateMySchedule);

module.exports = router;

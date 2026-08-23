const express = require('express');
const router = express.Router();
const {
  getUserProfile,
  updateProfile,
  updateVehicle,
} = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');

router.get('/:id', protect, getUserProfile);
router.put('/profile', protect, updateProfile);
router.put('/vehicle', protect, updateVehicle);

module.exports = router;

const express = require('express');
const router = express.Router();
const {
  createRide,
  searchRides,
  getRideById,
  getMyOfferedRides,
  updateRideStatus,
  cancelRide,
} = require('../controllers/rideController');
const { protect } = require('../middleware/authMiddleware');

router.route('/')
  .get(searchRides)
  .post(protect, createRide);

router.get('/my-rides', protect, getMyOfferedRides);

router.route('/:id')
  .get(protect, getRideById)
  .delete(protect, cancelRide);

router.patch('/:id/status', protect, updateRideStatus);

module.exports = router;

const express = require('express');
const router = express.Router();
const {
  createBooking,
  respondToBooking,
  cancelBooking,
  getMyBookings,
  getRideBookings,
  getDriverBookings,
  verifyBookingOtp,
} = require('../controllers/bookingController');
const { protect } = require('../middleware/authMiddleware');

router.post('/', protect, createBooking);
router.get('/my-bookings', protect, getMyBookings);
router.get('/driver-requests', protect, getDriverBookings);
router.get('/ride/:rideId', protect, getRideBookings);
router.patch('/:id/respond', protect, respondToBooking);
router.patch('/:id/cancel', protect, cancelBooking);
router.post('/:id/verify-otp', protect, verifyBookingOtp);

module.exports = router;

const express = require('express');
const router = express.Router();
const {
  createBooking,
  respondToBooking,
  cancelBooking,
  getMyBookings,
  getRideBookings,
} = require('../controllers/bookingController');
const { protect } = require('../middleware/authMiddleware');

router.post('/', protect, createBooking);
router.get('/my-bookings', protect, getMyBookings);
router.get('/ride/:rideId', protect, getRideBookings);
router.patch('/:id/respond', protect, respondToBooking);
router.patch('/:id/cancel', protect, cancelBooking);

module.exports = router;

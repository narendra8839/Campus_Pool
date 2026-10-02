const express = require('express');
const router = express.Router();
const {
  analyzeReviewSentiment,
  createReview,
  getUserReviews,
} = require('../controllers/reviewController');
const { protect } = require('../middleware/authMiddleware');

router.post('/sentiment', protect, analyzeReviewSentiment);
router.post('/', protect, createReview);
router.get('/user/:userId', getUserReviews);

module.exports = router;

const prisma = require('../config/prisma');

const parseGradioPrediction = (eventStream) => {
  const events = [...eventStream.matchAll(
    /(?:^|\r?\n)event:\s*(\w+)\r?\ndata:\s*(.+)/g,
  )];
  const errorEvent = events.find(([, eventName]) => eventName === 'error');
  if (errorEvent) {
    throw new Error('Gradio inference request failed.');
  }

  const completeEvent = events.find(([, eventName]) => eventName === 'complete');
  if (!completeEvent) {
    throw new Error('Gradio inference returned no completion event.');
  }

  const outputs = JSON.parse(completeEvent[2]);
  const prediction = Array.isArray(outputs) ? outputs[0] : null;
  if (
    !prediction ||
    typeof prediction !== 'object' ||
    !['negative', 'neutral', 'positive'].includes(prediction.sentiment) ||
    typeof prediction.confidence !== 'number' ||
    !Number.isFinite(prediction.confidence) ||
    prediction.confidence < 0 ||
    prediction.confidence > 1
  ) {
    throw new Error('Gradio inference returned an invalid prediction.');
  }
  return prediction;
};

// @desc    Classify review text with the fine-tuned model on Hugging Face
// @route   POST /api/reviews/sentiment
// @access  Private
const analyzeReviewSentiment = async (req, res) => {
  const { text } = req.body;
  if (typeof text !== 'string' || !text.trim() || text.trim().length > 5000) {
    return res.status(400).json({
      success: false,
      message: 'Review text must contain 1 to 5000 characters',
    });
  }

  const apiKey = process.env.SENTIMENT_API_KEY;
  if (!apiKey) {
    console.error('[Sentiment Service] SENTIMENT_API_KEY is not configured.');
    return res.status(503).json({
      success: false,
      message: 'Sentiment model is unavailable. Ensure service authentication is configured.',
    });
  }

  try {
    const baseUrl = (process.env.SENTIMENT_SERVICE_URL || 'http://127.0.0.1:8001')
      .replace(/\/+$/, '');
    const submissionResponse = await fetch(`${baseUrl}/gradio_api/call/predict`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: [text.trim(), apiKey] }),
      signal: AbortSignal.timeout(8000),
    });
    if (!submissionResponse.ok) {
      console.error(
        `[Sentiment Service] Gradio request failed with status ${submissionResponse.status}`,
      );
      return res.status(503).json({
        success: false,
        message: 'Sentiment model is unavailable. Ensure it has been trained and started.',
      });
    }

    const submission = await submissionResponse.json();
    if (typeof submission.event_id !== 'string' || !submission.event_id) {
      throw new Error('Gradio did not return a prediction event ID.');
    }

    const resultResponse = await fetch(
      `${baseUrl}/gradio_api/call/predict/${encodeURIComponent(submission.event_id)}`,
      { signal: AbortSignal.timeout(8000) },
    );
    if (!resultResponse.ok) {
      console.error(
        `[Sentiment Service] Gradio result failed with status ${resultResponse.status}`,
      );
      return res.status(503).json({
        success: false,
        message: 'Sentiment model is unavailable. Ensure it has been trained and started.',
      });
    }

    const prediction = parseGradioPrediction(await resultResponse.text());
    res.json({ success: true, data: prediction });
  } catch (error) {
    console.error(`[Sentiment Service] ${error.message}`);
    res.status(503).json({
      success: false,
      message: 'Sentiment model is unavailable. Ensure it has been trained and started.',
    });
  }
};

// @desc    Create a review for a driver or passenger
// @route   POST /api/reviews
// @access  Private
const createReview = async (req, res, next) => {
  try {
    const { rideId, revieweeId, rating, comment } = req.body;

    if (!rideId || !revieweeId || !rating) {
      return res.status(400).json({
        success: false,
        message: 'Please provide rideId, revieweeId, and rating',
      });
    }

    const numericRating = parseInt(rating, 10);
    if (numericRating < 1 || numericRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5',
      });
    }

    if (revieweeId === req.user.id) {
      return res.status(400).json({
        success: false,
        message: 'You cannot review yourself',
      });
    }

    // Verify ride exists
    const ride = await prisma.ride.findUnique({
      where: { id: rideId },
    });

    if (!ride) {
      return res.status(404).json({
        success: false,
        message: 'Ride not found',
      });
    }

    // Check if reviewer and reviewee were part of this ride
    const isReviewerDriver = ride.driverId === req.user.id;
    const isRevieweeDriver = ride.driverId === revieweeId;

    let isAuthorized = false;
    if (isReviewerDriver) {
      // Driver reviewing passenger
      const booking = await prisma.booking.findFirst({
        where: {
          rideId,
          passengerId: revieweeId,
          status: { in: ['ACCEPTED', 'COMPLETED'] },
        },
      });
      if (booking) isAuthorized = true;
    } else if (isRevieweeDriver) {
      // Passenger reviewing driver
      const booking = await prisma.booking.findFirst({
        where: {
          rideId,
          passengerId: req.user.id,
          status: { in: ['ACCEPTED', 'COMPLETED'] },
        },
      });
      if (booking) isAuthorized = true;
    }

    if (!isAuthorized) {
      return res.status(403).json({
        success: false,
        message: 'You can only review users with whom you completed a shared ride',
      });
    }

    // Check if already reviewed
    const existingReview = await prisma.review.findFirst({
      where: {
        rideId,
        reviewerId: req.user.id,
        revieweeId,
      },
    });

    if (existingReview) {
      return res.status(400).json({
        success: false,
        message: 'You have already submitted a review for this ride',
      });
    }

    const review = await prisma.$transaction(async (tx) => {
      const newReview = await tx.review.create({
        data: {
          rideId,
          reviewerId: req.user.id,
          revieweeId,
          rating: numericRating,
          comment: comment || '',
        },
        include: {
          reviewer: { select: { id: true, name: true, avatar: true } },
          reviewee: { select: { id: true, name: true, avatar: true } },
        },
      });

      // Calculate aggregate rating
      const aggregations = await tx.review.aggregate({
        where: { revieweeId },
        _avg: { rating: true },
        _count: { rating: true },
      });

      await tx.user.update({
        where: { id: revieweeId },
        data: {
          ratingAvg: parseFloat((aggregations._avg.rating || 5.0).toFixed(1)),
          ratingCount: aggregations._count.rating || 0,
        },
      });

      return newReview;
    });

    res.status(201).json({
      success: true,
      message: 'Review submitted successfully',
      data: review,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get reviews for a user
// @route   GET /api/reviews/user/:userId
// @access  Public
const getUserReviews = async (req, res, next) => {
  try {
    const reviews = await prisma.review.findMany({
      where: { revieweeId: req.params.userId },
      include: {
        reviewer: { select: { id: true, name: true, avatar: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      success: true,
      count: reviews.length,
      data: reviews,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  analyzeReviewSentiment,
  createReview,
  getUserReviews,
};

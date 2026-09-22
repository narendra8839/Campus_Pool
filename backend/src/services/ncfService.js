const fs = require('fs');
const path = require('path');

const modelPath = process.env.NCF_MODEL_PATH
  ? path.resolve(process.env.NCF_MODEL_PATH)
  : path.resolve(__dirname, '..', '..', 'ml', 'model-output', 'ncf-model.json');

let cachedModel;

function loadModel() {
  if (cachedModel !== undefined) return cachedModel;
  try {
    cachedModel = JSON.parse(fs.readFileSync(modelPath, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    cachedModel = null;
  }
  return cachedModel;
}

function clamp(value) {
  return Math.max(0, Math.min(1, value));
}

function fallbackScore(ride) {
  const rating = Number(ride.driver?.ratingAvg);
  const acceptanceRate = Number(ride.driver?.acceptanceRate);
  const ratingScore = Number.isFinite(rating) ? clamp(rating / 5) : 0.7;
  const historyScore = Number.isFinite(acceptanceRate) ? clamp(acceptanceRate) : 0.5;
  return Number((0.65 * historyScore + 0.35 * ratingScore).toFixed(4));
}

function scoreRide(riderId, ride) {
  const model = loadModel();
  const pairKey = `${riderId}:${ride.driverId}`;
  const predicted = model?.pairScores?.[pairKey];
  if (Number.isFinite(predicted)) return { score: predicted, source: 'ncf' };
  return { score: fallbackScore(ride), source: 'fallback' };
}

function rankRides(riderId, rides) {
  if (!riderId) return rides;
  return rides
    .map((ride) => {
      const prediction = scoreRide(riderId, ride);
      return { ...ride, matchAcceptanceProbability: prediction.score, matchScoreSource: prediction.source };
    });
}

module.exports = { rankRides };

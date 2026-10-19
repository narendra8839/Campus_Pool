const { RoutingError, getRoutes } = require('../services/osrmService');

function parseCoordinate(value, minimum, maximum) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= minimum && number <= maximum
    ? number
    : null;
}

const route = async (req, res, next) => {
  const origin = {
    latitude: parseCoordinate(req.query.originLat, -90, 90),
    longitude: parseCoordinate(req.query.originLon, -180, 180),
  };
  const destination = {
    latitude: parseCoordinate(req.query.destinationLat, -90, 90),
    longitude: parseCoordinate(req.query.destinationLon, -180, 180),
  };
  const hasViaLatitude = req.query.viaLat !== undefined;
  const hasViaLongitude = req.query.viaLon !== undefined;
  if (hasViaLatitude !== hasViaLongitude) {
    return res.status(400).json({
      success: false,
      message: 'Both viaLat and viaLon must be provided together.',
    });
  }
  const viaPoints = hasViaLatitude
    ? [{
        latitude: parseCoordinate(req.query.viaLat, -90, 90),
        longitude: parseCoordinate(req.query.viaLon, -180, 180),
      }]
    : [];

  if (
    origin.latitude === null ||
    origin.longitude === null ||
    destination.latitude === null ||
    destination.longitude === null ||
    viaPoints.some(
      (point) => point.latitude === null || point.longitude === null,
    )
  ) {
    return res.status(400).json({
      success: false,
      message: 'Valid origin and destination coordinates are required.',
    });
  }

  if (
    origin.latitude === destination.latitude &&
    origin.longitude === destination.longitude
  ) {
    return res.status(400).json({
      success: false,
      message: 'Origin and destination must be different locations.',
    });
  }

  try {
    const routes = await getRoutes(origin, destination, viaPoints);
    const data = {
      ...routes[0],
      routes,
    };
    return res.json({ success: true, data });
  } catch (error) {
    if (error instanceof RoutingError) {
      return res.status(error.statusCode).json({ success: false, message: error.message });
    }
    return next(error);
  }
};

module.exports = { route };

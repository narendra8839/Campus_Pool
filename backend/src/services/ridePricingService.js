const { getRoutes, RoutingError } = require('./osrmService');
const { fareForDistance, routeDistanceKilometres } = require('../utils/fareCalculator');

function readCoordinate(point) {
  if (!point || typeof point !== 'object') return null;
  const latitude = Number(point.latitude);
  const longitude = Number(point.longitude);
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return null;
  }
  return { latitude, longitude };
}

async function priceRide(
  {
    origin,
    destination,
    waypoints = [],
    viaPoints = [],
    selectedRouteIndex = 0,
  },
  routeProvider = getRoutes,
) {
  const start = readCoordinate(origin);
  const end = readCoordinate(destination);
  const startMissing = start && start.latitude === 0 && start.longitude === 0;
  const endMissing = end && end.latitude === 0 && end.longitude === 0;
  const bothCoordinatesMissing = start && end
    && startMissing
    && endMissing;
  if (!start || !end || bothCoordinatesMissing) {
    return {
      contribution: fareForDistance(routeDistanceKilometres(start, end, waypoints)),
      waypoints: waypoints || [],
    };
  }
  if (startMissing || endMissing) {
    throw new RoutingError('Both ride endpoints must have valid coordinates.', 400);
  }

  const routesOrRoute = await routeProvider(start, end, viaPoints);
  const routes = Array.isArray(routesOrRoute) ? routesOrRoute : [routesOrRoute];
  if (
    !Number.isInteger(selectedRouteIndex) ||
    selectedRouteIndex < 0 ||
    selectedRouteIndex >= routes.length
  ) {
    throw new RoutingError('The selected route is no longer available. Please review the route options again.', 409);
  }
  const route = routes[selectedRouteIndex];
  return {
    contribution: fareForDistance(route.distanceMeters / 1000),
    waypoints: route.coordinates.map(([longitude, latitude]) => ({
      latitude,
      longitude,
    })),
  };
}

module.exports = { priceRide };

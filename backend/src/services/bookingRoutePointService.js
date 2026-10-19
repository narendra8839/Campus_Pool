const METERS_PER_DEGREE = 111320;
const { getRoutes } = require('./osrmService');

function readCoordinate(point) {
  if (!point || typeof point !== 'object') return null;
  const hasLatitude =
    typeof point.latitude === 'number' ||
    (typeof point.latitude === 'string' && point.latitude.trim() !== '');
  const hasLongitude =
    typeof point.longitude === 'number' ||
    (typeof point.longitude === 'string' && point.longitude.trim() !== '');
  if (!hasLatitude || !hasLongitude) return null;
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

function distanceMeters(first, second) {
  const latitudeDelta =
    ((second.latitude - first.latitude) * Math.PI) / 180;
  const longitudeDelta =
    ((second.longitude - first.longitude) * Math.PI) / 180;
  const firstLatitude = (first.latitude * Math.PI) / 180;
  const secondLatitude = (second.latitude * Math.PI) / 180;
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(firstLatitude) *
      Math.cos(secondLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function routeCoordinate(point) {
  if (!point || typeof point !== 'object') return null;
  if (Array.isArray(point) && point.length >= 2) {
    return readCoordinate({ longitude: point[0], latitude: point[1] });
  }
  return readCoordinate(point);
}

function locateAlongRoute(point, route) {
  const latitudeScale = METERS_PER_DEGREE;
  const longitudeScale =
    METERS_PER_DEGREE * Math.cos((point.latitude * Math.PI) / 180);
  let distanceAlongRoute = 0;
  let closest = null;

  for (let index = 0; index < route.length - 1; index += 1) {
    const start = route[index];
    const end = route[index + 1];
    const startX = (start.longitude - point.longitude) * longitudeScale;
    const startY = (start.latitude - point.latitude) * latitudeScale;
    const endX = (end.longitude - point.longitude) * longitudeScale;
    const endY = (end.latitude - point.latitude) * latitudeScale;
    const segmentX = endX - startX;
    const segmentY = endY - startY;
    const segmentLengthSquared = segmentX ** 2 + segmentY ** 2;
    const fraction =
      segmentLengthSquared === 0
        ? 0
        : Math.max(
            0,
            Math.min(
              1,
              (-startX * segmentX - startY * segmentY) /
                segmentLengthSquared,
            ),
          );
    const projected = {
      latitude: start.latitude + fraction * (end.latitude - start.latitude),
      longitude:
        start.longitude + fraction * (end.longitude - start.longitude),
    };
    const distance = distanceMeters(point, projected);
    const segmentLength = distanceMeters(start, end);
    if (!closest || distance < closest.distance) {
      closest = {
        distance,
        progress: distanceAlongRoute + fraction * segmentLength,
      };
    }
    distanceAlongRoute += segmentLength;
  }
  return closest;
}

function validateBookingRoutePoints({
  routeCoordinates,
  pickup,
  dropoff,
  maximumDistanceMeters = 75,
}) {
  if (!Array.isArray(routeCoordinates) || routeCoordinates.length < 2) {
    return 'This ride does not have a saved route map for pickup validation.';
  }
  const route = routeCoordinates.map(routeCoordinate);
  if (route.some((point) => point == null)) {
    return 'This ride has invalid route coordinates.';
  }
  const pickupCoordinate = readCoordinate(pickup);
  const dropoffCoordinate = readCoordinate(dropoff);
  if (!pickupCoordinate || !dropoffCoordinate) {
    return 'Valid pickup and drop-off coordinates are required.';
  }

  const pickupLocation = locateAlongRoute(pickupCoordinate, route);
  const dropoffLocation = locateAlongRoute(dropoffCoordinate, route);
  if (
    pickupLocation.distance > maximumDistanceMeters ||
    dropoffLocation.distance > maximumDistanceMeters
  ) {
    return `Pickup and drop-off must be within ${maximumDistanceMeters} m of the biker’s route.`;
  }
  if (pickupLocation.progress >= dropoffLocation.progress) {
    return 'The pickup point must be before the drop-off point along the biker’s route.';
  }
  return null;
}

async function getRideRouteCoordinates(ride, routeProvider = getRoutes) {
  const savedRoute = Array.isArray(ride.waypoints)
    ? ride.waypoints.map(routeCoordinate)
    : [];
  if (savedRoute.length >= 2 && savedRoute.every((point) => point != null)) {
    return savedRoute;
  }

  const origin = readCoordinate({
    latitude: ride.originLat,
    longitude: ride.originLng,
  });
  const destination = readCoordinate({
    latitude: ride.destLat,
    longitude: ride.destLng,
  });
  if (
    !origin ||
    !destination ||
    (origin.latitude === 0 && origin.longitude === 0) ||
    (destination.latitude === 0 && destination.longitude === 0) ||
    (origin.latitude === destination.latitude &&
      origin.longitude === destination.longitude)
  ) {
    return [];
  }

  const routes = await routeProvider(origin, destination);
  const route = Array.isArray(routes) ? routes[0] : routes;
  if (!route || !Array.isArray(route.coordinates)) return [];
  return route.coordinates
    .map((point) =>
      Array.isArray(point) && point.length >= 2
        ? readCoordinate({ longitude: point[0], latitude: point[1] })
        : null,
    )
    .filter((point) => point != null);
}

module.exports = { getRideRouteCoordinates, validateBookingRoutePoints };

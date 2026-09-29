const OSRM_BASE_URL = (process.env.OSRM_BASE_URL || 'https://router.project-osrm.org')
  .replace(/\/+$/, '');
const REQUEST_INTERVAL_MS = 1000;
const REQUEST_TIMEOUT_MS = 8000;
const CACHE_TTL_MS = 60 * 1000;
const MAX_CACHE_ENTRIES = 100;
const MAX_PENDING_REQUESTS = 4;
const MAX_ROUTE_POINTS = 20000;

const cache = new Map();
const pendingRequests = new Map();
let nextRequestAt = 0;
let requestQueue = Promise.resolve();
let pendingOsrmRequests = 0;

class RoutingError extends Error {
  constructor(message, statusCode = 502) {
    super(message);
    this.name = 'RoutingError';
    this.statusCode = statusCode;
  }
}

function readCache(key) {
  const entry = cache.get(key);
  if (!entry) return undefined;
  if (entry.expiresAt <= Date.now()) {
    cache.delete(key);
    return undefined;
  }
  return entry.value;
}

function cacheRoute(key, value) {
  if (cache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = cache.keys().next().value;
    if (oldestKey !== undefined) cache.delete(oldestKey);
  }
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

function toRoute(route) {
  if (!route || typeof route !== 'object') {
    throw new RoutingError('Routing service returned an invalid route.', 502);
  }

  const distanceMeters = Number(route.distance);
  const durationSeconds = Number(route.duration);
  const coordinates = route.geometry?.coordinates;
  if (
    !Number.isFinite(distanceMeters) ||
    distanceMeters < 0 ||
    !Number.isFinite(durationSeconds) ||
    durationSeconds < 0 ||
    !Array.isArray(coordinates) ||
    coordinates.length < 2 ||
    coordinates.length > MAX_ROUTE_POINTS
  ) {
    throw new RoutingError('Routing service returned incomplete route data.', 502);
  }

  const validCoordinates = coordinates.map((point) => {
    if (!Array.isArray(point) || point.length < 2) return null;
    const longitude = Number(point[0]);
    const latitude = Number(point[1]);
    if (
      !Number.isFinite(longitude) ||
      !Number.isFinite(latitude) ||
      longitude < -180 ||
      longitude > 180 ||
      latitude < -90 ||
      latitude > 90
    ) {
      return null;
    }
    return [longitude, latitude];
  });
  if (validCoordinates.some((point) => point === null)) {
    throw new RoutingError('Routing service returned invalid route geometry.', 502);
  }

  return {
    distanceMeters,
    durationSeconds,
    coordinates: validCoordinates,
  };
}

async function requestRoute(origin, destination) {
  if (pendingOsrmRequests >= MAX_PENDING_REQUESTS) {
    throw new RoutingError('Routing is busy. Try again shortly.', 503);
  }

  const coordinates = `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
  let url;
  try {
    url = new URL(`${OSRM_BASE_URL}/route/v1/driving/${coordinates}`);
  } catch (_) {
    throw new RoutingError('Routing service is misconfigured.', 500);
  }
  url.searchParams.set('overview', 'full');
  url.searchParams.set('geometries', 'geojson');
  url.searchParams.set('steps', 'false');

  const scheduledRequest = requestQueue.then(async () => {
    const delay = Math.max(0, nextRequestAt - Date.now());
    if (delay > 0) {
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
    nextRequestAt = Date.now() + REQUEST_INTERVAL_MS;
  });
  requestQueue = scheduledRequest.catch(() => {});

  pendingOsrmRequests++;
  try {
    await scheduledRequest;
    const response = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (!response.ok) {
      throw new RoutingError('Routing service returned an error.', 502);
    }

    let result;
    try {
      result = await response.json();
    } catch (_) {
      throw new RoutingError('Routing service returned invalid data.', 502);
    }

    if (!result || typeof result !== 'object') {
      throw new RoutingError('Routing service returned invalid data.', 502);
    }
    if (result.code === 'NoRoute' || result.code === 'NoMatch') {
      throw new RoutingError('No drivable route was found between these locations.', 404);
    }
    if (result.code !== 'Ok' || !Array.isArray(result.routes) || result.routes.length === 0) {
      throw new RoutingError('Routing service could not calculate a route.', 502);
    }
    return toRoute(result.routes[0]);
  } catch (error) {
    if (error instanceof RoutingError) throw error;
    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      throw new RoutingError('Routing service timed out.', 504);
    }
    throw new RoutingError('Routing service is unavailable.', 502);
  } finally {
    pendingOsrmRequests--;
  }
}

async function getRoute(origin, destination) {
  const key = [
    origin.latitude.toFixed(5),
    origin.longitude.toFixed(5),
    destination.latitude.toFixed(5),
    destination.longitude.toFixed(5),
  ].join(':');

  const cached = readCache(key);
  if (cached !== undefined) return cached;
  const pending = pendingRequests.get(key);
  if (pending) return pending;

  const request = requestRoute(origin, destination)
    .then((route) => {
      cacheRoute(key, route);
      return route;
    })
    .finally(() => pendingRequests.delete(key));
  pendingRequests.set(key, request);
  return request;
}

module.exports = { RoutingError, getRoute };

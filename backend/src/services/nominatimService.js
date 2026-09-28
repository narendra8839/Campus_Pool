const NOMINATIM_BASE_URL = 'https://nominatim.openstreetmap.org';
const REQUEST_INTERVAL_MS = 1000;
const CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_CACHE_ENTRIES = 200;
const REQUEST_TIMEOUT_MS = 4000;
const MAX_PENDING_REQUESTS = 4;

const cache = new Map();
const pendingRequests = new Map();
let nextRequestAt = 0;
let requestQueue = Promise.resolve();
let pendingNominatimRequests = 0;

class GeocodingError extends Error {
  constructor(message, statusCode = 502) {
    super(message);
    this.name = 'GeocodingError';
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

function writeCache(key, value) {
  if (cache.size >= MAX_CACHE_ENTRIES) {
    const oldestKey = cache.keys().next().value;
    if (oldestKey !== undefined) cache.delete(oldestKey);
  }
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

function cachedRequest(key, loader) {
  const cached = readCache(key);
  if (cached !== undefined) return Promise.resolve(cached);

  const pending = pendingRequests.get(key);
  if (pending) return pending;

  const request = Promise.resolve()
    .then(loader)
    .then((value) => {
      writeCache(key, value);
      return value;
    })
    .finally(() => pendingRequests.delete(key));
  pendingRequests.set(key, request);
  return request;
}

async function fetchNominatim(path, params) {
  if (pendingNominatimRequests >= MAX_PENDING_REQUESTS) {
    throw new GeocodingError('Place search is busy. Try again shortly.', 503);
  }
  pendingNominatimRequests++;

  const url = new URL(path, NOMINATIM_BASE_URL);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, String(value));
  }

  const scheduledRequest = requestQueue.then(async () => {
    const delay = Math.max(0, nextRequestAt - Date.now());
    if (delay > 0) {
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
    nextRequestAt = Date.now() + REQUEST_INTERVAL_MS;
  });
  requestQueue = scheduledRequest.catch(() => {});

  try {
    await scheduledRequest;
    const response = await fetch(url, {
      headers: {
        Accept: 'application/json',
        'Accept-Language': 'en',
        'User-Agent': process.env.NOMINATIM_USER_AGENT
          || 'CampusPool/1.0 (https://github.com/narendra8839/Campus_Pool)',
      },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    if (!response.ok) {
      if (response.status === 404 && path === '/reverse') {
        throw new GeocodingError('No address found for these coordinates.', 404);
      }
      if (response.status === 429) {
        throw new GeocodingError('Place search is busy or rate limited. Try again shortly.', 503);
      }
      throw new GeocodingError('Place search service returned an error.', 502);
    }

    try {
      return await response.json();
    } catch (_) {
      throw new GeocodingError('Place search service returned invalid data.', 502);
    }
  } catch (error) {
    if (error instanceof GeocodingError) throw error;
    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      throw new GeocodingError('Place search service timed out.', 504);
    }
    throw new GeocodingError('Place search service is unavailable.', 502);
  } finally {
    pendingNominatimRequests--;
  }
}

function toPlaceResult(result) {
  if (!result || typeof result !== 'object') return null;
  const latitude = Number(result.lat);
  const longitude = Number(result.lon);
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    result.place_id === undefined ||
    typeof result.display_name !== 'string' ||
    result.display_name.length === 0
  ) {
    return null;
  }

  return {
    placeId: String(result.place_id),
    displayName: result.display_name,
    latitude,
    longitude,
    type: result.type || result.category || '',
    address: result.address || {},
  };
}

async function searchPlaces(query, limit = 5) {
  const normalizedQuery = query.trim().replace(/\s+/g, ' ');
  const cacheKey = `search:${normalizedQuery.toLowerCase()}:${limit}`;
  return cachedRequest(cacheKey, async () => {
    const results = await fetchNominatim('/search', {
      q: normalizedQuery,
      format: 'jsonv2',
      addressdetails: 1,
      limit,
    });
    if (!Array.isArray(results)) {
      throw new GeocodingError('Place search service returned invalid data.', 502);
    }

    return results.map(toPlaceResult).filter(Boolean);
  });
}

async function reverseGeocode(latitude, longitude) {
  const cacheKey = `reverse:${latitude.toFixed(5)}:${longitude.toFixed(5)}`;
  return cachedRequest(cacheKey, async () => {
    const result = await fetchNominatim('/reverse', {
      lat: latitude,
      lon: longitude,
      format: 'jsonv2',
      addressdetails: 1,
    });
    const place = result && typeof result === 'object' ? toPlaceResult(result) : null;
    if (!place) {
      throw new GeocodingError('No address found for these coordinates.', 404);
    }
    return place;
  });
}

module.exports = { GeocodingError, searchPlaces, reverseGeocode };

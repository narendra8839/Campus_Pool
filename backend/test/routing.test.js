const assert = require('node:assert/strict');
const { test } = require('node:test');
const { getRoute, getRoutes } = require('../src/services/osrmService');
const { route } = require('../src/controllers/routingController');

test('OSRM route request converts geometry and preserves distance and duration', async () => {
  const originalFetch = global.fetch;
  let requestUrl;
  global.fetch = async (url) => {
    requestUrl = new URL(url);
    return {
      ok: true,
      json: async () => ({
        code: 'Ok',
        routes: [{
          distance: 2400.5,
          duration: 540,
          geometry: {
            type: 'LineString',
            coordinates: [[73.8, 18.5], [73.81, 18.51]],
          },
        }],
      }),
    };
  };

  try {
    const result = await getRoute(
      { latitude: 18.5, longitude: 73.8 },
      { latitude: 18.51, longitude: 73.81 },
    );

    assert.match(requestUrl.pathname, /\/route\/v1\/driving\/73\.8,18\.5;73\.81,18\.51$/);
    assert.equal(requestUrl.searchParams.get('overview'), 'full');
    assert.equal(requestUrl.searchParams.get('geometries'), 'geojson');
    assert.equal(requestUrl.searchParams.get('alternatives'), 'true');
    assert.equal(result.distanceMeters, 2400.5);
    assert.equal(result.durationSeconds, 540);
    assert.deepEqual(result.coordinates, [[73.8, 18.5], [73.81, 18.51]]);
  } finally {
    global.fetch = originalFetch;
  }
});

test('OSRM returns alternative routes and includes a requested via point', async () => {
  const originalFetch = global.fetch;
  let requestUrl;
  global.fetch = async (url) => {
    requestUrl = new URL(url);
    return {
      ok: true,
      json: async () => ({
        code: 'Ok',
        routes: [
          {
            distance: 2400,
            duration: 540,
            geometry: {
              type: 'LineString',
              coordinates: [[73.8, 18.5], [73.81, 18.51]],
            },
          },
          {
            distance: 2800,
            duration: 600,
            geometry: {
              type: 'LineString',
              coordinates: [[73.8, 18.5], [73.805, 18.505], [73.81, 18.51]],
            },
          },
        ],
      }),
    };
  };

  try {
    const routes = await getRoutes(
      { latitude: 18.5, longitude: 73.8 },
      { latitude: 18.51, longitude: 73.81 },
      [{ latitude: 18.505, longitude: 73.805 }],
    );

    assert.match(
      requestUrl.pathname,
      /\/route\/v1\/driving\/73\.8,18\.5;73\.805,18\.505;73\.81,18\.51$/,
    );
    assert.equal(requestUrl.searchParams.get('alternatives'), 'true');
    assert.equal(routes.length, 2);
    assert.equal(routes[1].distanceMeters, 2800);
  } finally {
    global.fetch = originalFetch;
  }
});

test('routing rejects identical origin and destination coordinates', async () => {
  let statusCode;
  let responseBody;
  const response = {
    status(code) {
      statusCode = code;
      return this;
    },
    json(body) {
      responseBody = body;
      return this;
    },
  };

  await route({
    query: {
      originLat: '18.5',
      originLon: '73.8',
      destinationLat: '18.5',
      destinationLon: '73.8',
    },
  }, response, (error) => {
    throw error;
  });

  assert.equal(statusCode, 400);
  assert.match(responseBody.message, /different locations/);
});

test('routing rejects invalid coordinate values', async () => {
  let statusCode;
  const response = {
    status(code) {
      statusCode = code;
      return this;
    },
    json() {
      return this;
    },
  };

  await route({
    query: {
      originLat: '91',
      originLon: '73.8',
      destinationLat: '18.5',
      destinationLon: '73.9',
    },
  }, response, (error) => {
    throw error;
  });

  assert.equal(statusCode, 400);
});

test('OSRM no-route responses become a not-found routing error', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({ code: 'NoRoute', routes: [] }),
  });

  try {
    await assert.rejects(
      getRoute(
        { latitude: 18.52, longitude: 73.82 },
        { latitude: 18.53, longitude: 73.83 },
      ),
      (error) => error.name === 'RoutingError' &&
        error.statusCode === 404 &&
        /No drivable route/.test(error.message),
    );
  } finally {
    global.fetch = originalFetch;
  }
});

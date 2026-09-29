const assert = require('node:assert/strict');
const { test } = require('node:test');
const { getRoute } = require('../src/services/osrmService');
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
    assert.equal(result.distanceMeters, 2400.5);
    assert.equal(result.durationSeconds, 540);
    assert.deepEqual(result.coordinates, [[73.8, 18.5], [73.81, 18.51]]);
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

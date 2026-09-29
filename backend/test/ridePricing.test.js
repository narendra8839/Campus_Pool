const test = require('node:test');
const assert = require('node:assert/strict');
const { priceRide } = require('../src/services/ridePricingService');
const { RoutingError } = require('../src/services/osrmService');

test('prices valid coordinates from OSRM road distance and stores its geometry', async () => {
  let requestedOrigin;
  let requestedDestination;
  const result = await priceRide(
    {
      origin: { latitude: '18.0', longitude: '73.0' },
      destination: { latitude: 18.1, longitude: 73.1 },
      waypoints: [{ latitude: 18.05, longitude: 73.05 }],
    },
    async (origin, destination) => {
      requestedOrigin = origin;
      requestedDestination = destination;
      return {
        distanceMeters: 12340,
        coordinates: [
          [73, 18],
          [73.05, 18.05],
          [73.1, 18.1],
        ],
      };
    },
  );

  assert.deepEqual(requestedOrigin, { latitude: 18, longitude: 73 });
  assert.deepEqual(requestedDestination, { latitude: 18.1, longitude: 73.1 });
  assert.equal(result.contribution, 61.7);
  assert.deepEqual(result.waypoints, [
    { latitude: 18, longitude: 73 },
    { latitude: 18.05, longitude: 73.05 },
    { latitude: 18.1, longitude: 73.1 },
  ]);
});

test('preserves legacy fare calculation when route coordinates are unavailable', async () => {
  const result = await priceRide({
    origin: { latitude: 0, longitude: 0 },
    destination: { latitude: 0, longitude: 0 },
    waypoints: [],
  }, async () => {
    throw new Error('should not request a route for identical endpoints');
  });

  assert.equal(result.contribution, 0);
  assert.deepEqual(result.waypoints, []);
});

test('does not silently fall back when OSRM cannot route valid endpoints', async () => {
  await assert.rejects(
    priceRide(
      {
        origin: { latitude: 18, longitude: 73 },
        destination: { latitude: 18.1, longitude: 73.1 },
      },
      async () => {
        throw new RoutingError('Routing service is unavailable.', 502);
      },
    ),
    (error) => error instanceof RoutingError && error.statusCode === 502,
  );
});

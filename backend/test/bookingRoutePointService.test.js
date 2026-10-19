const test = require('node:test');
const assert = require('node:assert/strict');
const {
  getRideRouteCoordinates,
  validateBookingRoutePoints,
} = require('../src/services/bookingRoutePointService');

const routeCoordinates = [
  { latitude: 18.0, longitude: 73.0 },
  { latitude: 18.0, longitude: 73.01 },
  { latitude: 18.0, longitude: 73.02 },
];

test('uses saved route geometry when it is available', async () => {
  const expected = [
    { latitude: 18, longitude: 73 },
    { latitude: 18, longitude: 73.01 },
  ];
  const resolved = await getRideRouteCoordinates(
    {
      waypoints: expected,
      originLat: 0,
      originLng: 0,
      destLat: 0,
      destLng: 0,
    },
    () => {
      throw new Error('Should not recalculate a saved route');
    },
  );
  assert.deepEqual(resolved, expected);
});

test('recalculates route geometry for older rides with valid endpoints', async () => {
  let receivedEndpoints;
  const resolved = await getRideRouteCoordinates(
    {
      waypoints: [],
      originLat: 18,
      originLng: 73,
      destLat: 18.1,
      destLng: 73.1,
    },
    async (origin, destination) => {
      receivedEndpoints = { origin, destination };
      return [
        {
          coordinates: [
            [73, 18],
            [73.1, 18.1],
          ],
        },
      ];
    },
  );
  assert.deepEqual(receivedEndpoints, {
    origin: { latitude: 18, longitude: 73 },
    destination: { latitude: 18.1, longitude: 73.1 },
  });
  assert.deepEqual(resolved, [
    { latitude: 18, longitude: 73 },
    { latitude: 18.1, longitude: 73.1 },
  ]);
});

test('returns no route when saved geometry and valid endpoints are absent', async () => {
  const resolved = await getRideRouteCoordinates(
    { waypoints: [], originLat: 0, originLng: 0, destLat: 0, destLng: 0 },
    async () => {
      throw new Error('Should not request a route for invalid endpoints');
    },
  );
  assert.deepEqual(resolved, []);
});

test('accepts pickup and drop-off coordinates along the route in order', () => {
  assert.equal(
    validateBookingRoutePoints({
      routeCoordinates,
      pickup: { latitude: 18.0001, longitude: 73.005 },
      dropoff: { latitude: 17.9999, longitude: 73.015 },
    }),
    null,
  );
});

test('accepts route geometry stored as longitude-latitude pairs', () => {
  assert.equal(
    validateBookingRoutePoints({
      routeCoordinates: [
        [73.0, 18.0],
        [73.01, 18.0],
        [73.02, 18.0],
      ],
      pickup: { latitude: 18, longitude: 73.005 },
      dropoff: { latitude: 18, longitude: 73.015 },
    }),
    null,
  );
});

test('rejects coordinates too far from the route', () => {
  assert.match(
    validateBookingRoutePoints({
      routeCoordinates,
      pickup: { latitude: 18.002, longitude: 73.005 },
      dropoff: { latitude: 18, longitude: 73.015 },
    }),
    /within 75 m/,
  );
});

test('rejects pickup points that follow the drop-off point', () => {
  assert.match(
    validateBookingRoutePoints({
      routeCoordinates,
      pickup: { latitude: 18, longitude: 73.018 },
      dropoff: { latitude: 18, longitude: 73.006 },
    }),
    /pickup point must be before/,
  );
});

test('rejects a booking when route geometry is unavailable', () => {
  assert.match(
    validateBookingRoutePoints({
      routeCoordinates: [],
      pickup: { latitude: 18, longitude: 73 },
      dropoff: { latitude: 18, longitude: 73.01 },
    }),
    /does not have a saved route map/,
  );
});

test('rejects invalid booking coordinates', () => {
  assert.match(
    validateBookingRoutePoints({
      routeCoordinates,
      pickup: { latitude: 'invalid', longitude: 73.005 },
      dropoff: { latitude: 18, longitude: 73.015 },
    }),
    /Valid pickup and drop-off coordinates are required/,
  );
});

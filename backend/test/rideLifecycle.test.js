const test = require('node:test');
const assert = require('node:assert/strict');
const { canTransitionRideStatus } = require('../src/utils/rideLifecycle');

test('allows only scheduled-to-start/cancel and ongoing-to-complete transitions', () => {
  assert.equal(canTransitionRideStatus('SCHEDULED', 'ONGOING'), true);
  assert.equal(canTransitionRideStatus('SCHEDULED', 'CANCELLED'), true);
  assert.equal(canTransitionRideStatus('ONGOING', 'COMPLETED'), true);
  assert.equal(canTransitionRideStatus('SCHEDULED', 'COMPLETED'), false);
  assert.equal(canTransitionRideStatus('CANCELLED', 'SCHEDULED'), false);
  assert.equal(canTransitionRideStatus('COMPLETED', 'ONGOING'), false);
  assert.equal(canTransitionRideStatus('UNKNOWN', 'CANCELLED'), false);
});

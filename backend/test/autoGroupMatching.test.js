const assert = require('node:assert/strict');
const { test } = require('node:test');
const { hasSharedRouteSegment } = require('../src/utils/autoGroupMatching');

const sequenceByHubId = new Map([
  ['swargate', 0],
  ['market-yard', 5],
  ['bibwewadi', 6],
  ['vit', 11],
]);

const request = (pickupHubId, destinationHubId) => ({
  pickupHubId,
  destinationHubId,
});

test('matches trips with different endpoints that share a corridor segment', () => {
  assert.equal(
    hasSharedRouteSegment(
      [request('swargate', 'vit'), request('market-yard', 'bibwewadi')],
      sequenceByHubId,
    ),
    true,
  );
});

test('matches a group only when every member shares a non-zero segment', () => {
  assert.equal(
    hasSharedRouteSegment(
      [
        request('swargate', 'vit'),
        request('market-yard', 'vit'),
        request('bibwewadi', 'vit'),
      ],
      sequenceByHubId,
    ),
    true,
  );
  assert.equal(
    hasSharedRouteSegment(
      [
        request('swargate', 'market-yard'),
        request('market-yard', 'vit'),
      ],
      sequenceByHubId,
    ),
    false,
  );
});

test('does not match trips traveling in opposite directions', () => {
  assert.equal(
    hasSharedRouteSegment(
      [request('swargate', 'vit'), request('vit', 'market-yard')],
      sequenceByHubId,
    ),
    false,
  );
});

test('does not match trips whose route segments only touch at one hub', () => {
  assert.equal(
    hasSharedRouteSegment(
      [request('swargate', 'market-yard'), request('market-yard', 'vit')],
      sequenceByHubId,
    ),
    false,
  );
});
